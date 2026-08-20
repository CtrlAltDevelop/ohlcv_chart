import 'package:flutter/foundation.dart';

import '../entity/drawing_codec.dart';
import '../entity/line.dart';

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
///   watermarkAssetPath: 'assets/logo.svg',
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

  /// The drawing the chart has its editor open on, if any.
  ///
  /// Set it — from a drawing manager, say — and the chart selects that drawing;
  /// the chart writes back to it whenever the user selects one on the chart
  /// itself.
  ChartLine? get selected => _selected;

  /// Selects [line], or clears the selection when it is null.
  void select(ChartLine? line) {
    if (identical(_selected, line)) return;
    if (line != null && !contains(line)) return;
    _selected = line;
    notifyListeners();
  }

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

  /// Forgets every drawing.
  void clear() {
    if (_drawings.isEmpty) return;
    _commit(() => _drawings.clear());
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

  /// Clears a selection whose drawing is no longer here — what a deletion, an
  /// undo or a fresh layout leaves behind.
  void _forgetLostSelection() {
    final selected = _selected;
    if (selected != null && !contains(selected)) _selected = null;
  }
}
