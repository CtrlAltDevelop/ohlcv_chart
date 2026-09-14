import 'package:flutter/foundation.dart';

import '../entity/drawing_codec.dart';
import '../entity/line.dart';
import 'drawing_template.dart';

/// Owns a chart's drawings, and remembers what they looked like before the
/// last few edits.
///
/// Hand one to `KChartWidget.drawingController` and the chart draws from it and
/// writes back to it: a line the user places, restyles, drags or deletes goes
/// through the controller, which is what makes [undo] and [redo] possible. The
/// per-kind `onAdd*` and `onRemove*` callbacks still fire, so an app that
/// persists each change one at a time carries on working.
///
/// ```dart
/// final drawings = ChartDrawingController();
///
/// KChartWidget(
///   candles,
///   ChartColors(),
///   isTrendLine: true,
///   timeFrame: const Duration(minutes: 15),
///   drawingController: drawings,
/// );
///
/// // ⌘Z on the chart, or from your own button:
/// drawings.undo();
/// ```
///
/// It is a [ChangeNotifier], so wrap a toolbar in an [AnimatedBuilder] on it to
/// keep undo and redo buttons enabled at the right times.
class ChartDrawingController extends ChangeNotifier {
  /// Creates a controller holding [drawings], oldest first.
  ///
  /// [historyLimit] is how many steps back [undo] can go.
  ChartDrawingController({
    Iterable<ChartLine>? drawings,
    this.historyLimit = 50,
  }) : _drawings = ChartDrawings(drawings) {
    _baseline = _drawings.copy();
  }

  /// Creates a controller over a layout saved by [ChartDrawings.toJson].
  factory ChartDrawingController.fromJson(
    Map<String, dynamic> json, {
    int historyLimit = 50,
  }) => ChartDrawingController(
    drawings: ChartDrawings.fromJson(json).all,
    historyLimit: historyLimit,
  );

  /// How many undo steps are kept; older ones fall off the back.
  final int historyLimit;

  ChartDrawings _drawings;

  /// What the drawings looked like as of the last committed change.
  ///
  /// Kept as a deep copy, because the chart edits a drawing in place — dragging
  /// an anchor, restyling a line — and only tells the controller once the edit
  /// lands. Without a copy taken beforehand there would be nothing left to go
  /// back to.
  late ChartDrawings _baseline;

  final List<ChartDrawings> _past = [];
  final List<ChartDrawings> _future = [];

  /// The drawings, oldest first.
  ///
  /// The list itself is not to be mutated; go through [save], [remove],
  /// [clear] and [replaceAll] so the history stays honest.
  List<ChartLine> get drawings => List<ChartLine>.unmodifiable(_drawings.all);

  /// The whole set, for its typed views: `drawings.trendLines` and friends.
  ChartDrawings get snapshot => _drawings;

  /// How many drawings there are.
  int get length => _drawings.length;

  /// Whether nothing is drawn.
  bool get isEmpty => _drawings.isEmpty;

  /// Whether [line] is one of these drawings.
  bool contains(ChartLine line) =>
      _drawings.all.any((candidate) => identical(candidate, line));

  ChartLine? _selected;

  final List<ChartLine> _alsoSelected = [];

  /// The drawing the chart has its editor open on, if any.
  ///
  /// Set it — from a drawing manager, say — and the chart selects that drawing;
  /// the chart writes back to it whenever the user selects one on the chart
  /// itself. With several selected this is the one the editor is open on, which
  /// is the last one picked.
  ChartLine? get selected => _selected;

  /// Every selected drawing, in the order they were picked.
  ///
  /// One at most until something is added to the selection; the editor stays on
  /// [selected], and an edit made through it is applied to the rest by the
  /// chart.
  List<ChartLine> get selection =>
      List<ChartLine>.unmodifiable([..._alsoSelected, ?_selected]);

  /// How many drawings are selected.
  int get selectionLength => _alsoSelected.length + (_selected == null ? 0 : 1);

  /// Whether more than one drawing is selected.
  bool get hasMultipleSelected => selectionLength > 1;

  /// Whether [line] is one of the selected drawings.
  bool isSelected(ChartLine line) =>
      identical(_selected, line) ||
      _alsoSelected.any((candidate) => identical(candidate, line));

  /// Selects [line] alone, or clears the selection when it is null.
  void select(ChartLine? line) {
    if (identical(_selected, line) && _alsoSelected.isEmpty) return;
    if (line != null && !contains(line)) return;
    _alsoSelected.clear();
    _selected = line;
    notifyListeners();
  }

  /// Selects every drawing in [lines], the last of them primary.
  ///
  /// Anything not among these drawings is skipped, and an empty list clears the
  /// selection.
  void selectMany(Iterable<ChartLine> lines) {
    final held = [
      for (final line in lines)
        if (contains(line)) line,
    ];
    _alsoSelected
      ..clear()
      ..addAll(held.isEmpty ? const <ChartLine>[] : held.take(held.length - 1));
    _selected = held.isEmpty ? null : held.last;
    notifyListeners();
  }

  /// Selects every drawing on the chart.
  void selectAll() => selectMany(_drawings.all);

  /// Adds [line] to the selection and makes it the primary one.
  void addToSelection(ChartLine line) {
    if (!contains(line) || isSelected(line)) return;
    final was = _selected;
    if (was != null) _alsoSelected.add(was);
    _selected = line;
    notifyListeners();
  }

  /// Takes [line] out of the selection.
  void removeFromSelection(ChartLine line) {
    if (!isSelected(line)) return;
    if (identical(_selected, line)) {
      // The editor moves to whatever was picked before it, so a selection is
      // never left with extras and no primary.
      _selected = _alsoSelected.isEmpty ? null : _alsoSelected.removeLast();
    } else {
      _alsoSelected.removeWhere((candidate) => identical(candidate, line));
    }
    notifyListeners();
  }

  /// Adds [line] to the selection, or takes it out if it is already in.
  void toggleSelection(ChartLine line) {
    if (isSelected(line)) {
      removeFromSelection(line);
    } else {
      addToSelection(line);
    }
  }

  /// Clears the selection.
  void clearSelection() => select(null);

  /// Whether there is an edit to undo.
  bool get canUndo => _past.isNotEmpty;

  /// Whether there is an undone edit to put back.
  bool get canRedo => _future.isNotEmpty;

  /// Stores [line], whether it was just drawn or just edited.
  ///
  /// An edit is a new history step, so restyling a line and then undoing gets
  /// the old style back.
  void save(ChartLine line) {
    _commit(() => _drawings.save(line));
  }

  /// Forgets [line].
  void remove(ChartLine line) {
    if (!contains(line)) return;
    _commit(() => _drawings.remove(line));
  }

  /// Forgets every drawing in [lines], as one undoable step.
  void removeAll(Iterable<ChartLine> lines) {
    final held = [
      for (final line in lines)
        if (contains(line)) line,
    ];
    if (held.isEmpty) return;
    _commit(() {
      for (final line in held) {
        _drawings.remove(line);
      }
    });
  }

  /// Forgets every drawing.
  void clear() {
    if (_drawings.isEmpty) return;
    _commit(() => _drawings.clear());
  }

  // ── Stacking order ───────────────────────────────────────────────────────

  /// Where [line] sits in the stack, or -1 when it is not here.
  ///
  /// Later is higher: the last drawing paints over the ones before it, and is
  /// the one a tap in an overlap picks up.
  int indexOf(ChartLine line) => _drawings.indexOf(line);

  /// Moves [line] to the top of the stack; returns whether it moved.
  bool bringToFront(ChartLine line) =>
      _restack(() => _drawings.moveToFront(line));

  /// Moves [line] to the bottom of the stack; returns whether it moved.
  bool sendToBack(ChartLine line) => _restack(() => _drawings.moveToBack(line));

  /// Moves [line] one place up the stack; returns whether it moved.
  bool bringForward(ChartLine line) =>
      _restack(() => _drawings.moveForward(line));

  /// Moves [line] one place down the stack; returns whether it moved.
  bool sendBackward(ChartLine line) =>
      _restack(() => _drawings.moveBackward(line));

  /// Runs [move] as one undoable step, unless it changes nothing.
  bool _restack(bool Function() move) {
    // Filed before the move so undo has the old order to go back to, and only
    // filed at all when there is a move to undo.
    final before = _baseline;
    var moved = false;
    _commit(() => moved = move());
    if (!moved) {
      // Nothing happened, so the history step is taken back out again.
      _past.remove(before);
      _baseline = before;
    }
    return moved;
  }

  // ── Copying, pasting and duplicating ─────────────────────────────────────

  List<ChartLine> _clipboard = const [];

  /// How many drawings are on the clipboard.
  int get clipboardLength => _clipboard.length;

  /// Whether there is anything to [paste].
  bool get canPaste => _clipboard.isNotEmpty;

  /// Puts a copy of [lines] on the clipboard.
  ///
  /// Copies, so editing or deleting the originals afterwards leaves what was
  /// copied alone. Nothing is committed and nothing is notified: the drawings
  /// have not changed.
  void copyToClipboard(Iterable<ChartLine> lines) {
    _clipboard = [for (final line in lines) copyDrawing(line)];
  }

  /// Empties the clipboard.
  void clearClipboard() {
    _clipboard = const [];
  }

  /// Adds a copy of everything on the clipboard, and returns what was added.
  ///
  /// One undoable step, however many were pasted, and the pasted drawings end
  /// up selected. They land exactly where they were copied from; nudging them
  /// somewhere visible is the chart's job, since only it knows how wide a
  /// candle is.
  List<ChartLine> paste() {
    if (_clipboard.isEmpty) return const [];
    final pasted = [for (final line in _clipboard) copyDrawing(line)];
    _commit(() {
      for (final line in pasted) {
        _drawings.save(line);
      }
    });
    selectMany(pasted);
    return pasted;
  }

  /// Adds a copy of each of [lines], and returns the copies.
  ///
  /// One undoable step, and the copies end up selected — the same as copying
  /// and pasting, without disturbing the clipboard.
  List<ChartLine> duplicate(Iterable<ChartLine> lines) {
    final held = [
      for (final line in lines)
        if (contains(line)) line,
    ];
    if (held.isEmpty) return const [];

    final copies = [for (final line in held) copyDrawing(line)];
    _commit(() {
      for (final line in copies) {
        _drawings.save(line);
      }
    });
    selectMany(copies);
    return copies;
  }

  // ── Style templates ──────────────────────────────────────────────────────

  final Map<String, DrawingTemplate> _templates = {};

  /// The saved style templates, by name.
  Map<String, DrawingTemplate> get templates =>
      Map<String, DrawingTemplate>.unmodifiable(_templates);

  /// Saves [line]'s look under [name], replacing any template of that name.
  ///
  /// Templates are the controller's own, not the drawings': saving one is not
  /// an undoable edit and does not change the chart.
  void saveTemplate(String name, ChartLine line) {
    _templates[name] = DrawingTemplate.of(line);
    notifyListeners();
  }

  /// Stores [template] under [name].
  void putTemplate(String name, DrawingTemplate template) {
    _templates[name] = template;
    notifyListeners();
  }

  /// Forgets the template called [name]; returns whether there was one.
  bool removeTemplate(String name) {
    if (_templates.remove(name) == null) return false;
    notifyListeners();
    return true;
  }

  /// Puts the template called [name] on each of [lines], as one undoable step.
  ///
  /// Returns whether there is a template of that name to apply.
  bool applyTemplate(String name, Iterable<ChartLine> lines) {
    final template = _templates[name];
    if (template == null) return false;

    final held = [
      for (final line in lines)
        if (contains(line)) line,
    ];
    if (held.isEmpty) return true;

    _commit(() {
      for (final line in held) {
        template.applyTo(line);
      }
    });
    return true;
  }

  /// The saved templates as a JSON-encodable map.
  ///
  /// Kept apart from [toJson], which is the drawings themselves: templates
  /// outlive any one chart's layout, so they are usually stored on their own.
  Map<String, dynamic> templatesToJson() => <String, dynamic>{
    for (final entry in _templates.entries) entry.key: entry.value.toJson(),
  };

  /// Replaces the saved templates with those in [json].
  void loadTemplates(Map<String, dynamic> json) {
    _templates.clear();
    for (final entry in json.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        _templates[entry.key] = DrawingTemplate.fromJson(value);
      }
    }
    notifyListeners();
  }

  /// Replaces every drawing with [drawings].
  void replaceAll(Iterable<ChartLine> drawings) {
    _commit(() {
      _drawings.clear();
      for (final line in drawings) {
        _drawings.save(line);
      }
    });
  }

  /// Loads a layout saved by [toJson], as one undoable step.
  void load(Map<String, dynamic> json) =>
      replaceAll(ChartDrawings.fromJson(json).all);

  /// This layout as a JSON-encodable map; see [ChartDrawings.toJson].
  Map<String, dynamic> toJson() => _drawings.toJson();

  /// Takes back the last change, and returns whether there was one.
  ///
  /// The drawings that come back are fresh objects, so anything holding on to
  /// the old ones — a selection, an open editor — has to let go; the chart does
  /// that for itself.
  bool undo() {
    if (_past.isEmpty) return false;
    _future.add(_drawings.copy());
    _drawings = _past.removeLast();
    _baseline = _drawings.copy();
    _forgetLostSelection();
    notifyListeners();
    return true;
  }

  /// Puts back the last undone change, and returns whether there was one.
  bool redo() {
    if (_future.isEmpty) return false;
    _past.add(_drawings.copy());
    _drawings = _future.removeLast();
    _baseline = _drawings.copy();
    _forgetLostSelection();
    notifyListeners();
    return true;
  }

  /// Throws away the undo history, keeping the drawings as they are.
  ///
  /// Worth calling after loading a layout the user should not be able to undo
  /// past — a fresh symbol, say.
  void clearHistory() {
    _past.clear();
    _future.clear();
    _baseline = _drawings.copy();
    notifyListeners();
  }

  /// Applies [change], having first filed the state it is replacing.
  void _commit(VoidCallback change) {
    _past.add(_baseline);
    if (_past.length > historyLimit) _past.removeAt(0);
    _future.clear();
    change();
    _baseline = _drawings.copy();
    _forgetLostSelection();
    notifyListeners();
  }

  /// Drops from the selection anything no longer here — what a deletion, an
  /// undo or a fresh layout leaves behind.
  void _forgetLostSelection() {
    _alsoSelected.removeWhere((line) => !contains(line));
    final selected = _selected;
    if (selected != null && !contains(selected)) {
      // Something else may still be selected, so the editor moves to it rather
      // than closing.
      _selected = _alsoSelected.isEmpty ? null : _alsoSelected.removeLast();
    }
  }
}
