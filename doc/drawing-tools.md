# Drawing tools

![The line editor open on a selected line](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/line-editor.png)

Selecting a drawn line opens the editor over the chart: colour, thickness,
stroke style, label text and visibility, lock and delete.

![Trend and horizontal lines with labels](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/drawing.png)

Set `currentDrawingTool` to put the chart into placement mode and handle the
callbacks to persist what the user draws. The per-kind lists below are the
original API and still work; a `drawingController` — see
[Undo, redo and the drawing controller](#undo-redo-and-the-drawing-controller) —
owns the whole layout for you instead, and `drawings:` takes drawings of any
kind, which is where the later ones live:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: true,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  currentDrawingTool: DrawingTool.trend,
  trendLines: savedTrendLines,
  horizontalLines: savedHorizontalLines,
  verticalLines: savedVerticalLines,
  rectangles: savedRectangles,
  fibRetracements: savedFibRetracements,
  drawings: savedMeasuresChannelsAndNotes,
  onAddTrendLine: repository.save,
  onRemoveTrendLine: repository.delete,
  // Fires for every kind, and is the only report for the later ones.
  onAddDrawing: repository.save,
  onRemoveDrawing: repository.delete,
);
```

Placement works the way a charting desk expects. A horizontal or vertical line
lands with a single tap. A trend line takes one tap per end: tap its start, move,
and tap again to finish — the line rubber-bands along with the pointer in
between. Pressing and dragging from one end to the other still draws a line in
one gesture, on a touch screen as much as with a mouse. Escape abandons a line
that is half-placed, as does tapping outside the chart or switching tools, and
the line editor stays out of the way until the line is finished.

With `magnetMode: true`, each point snaps to the nearest open, high, low or
close within `DrawingStyle.magnetSnapDistance` pixels, and lands wherever the
pointer is when nothing is that close. This applies to an anchor **dragged**
afterwards as much as to one being placed, which is how a line already drawn
gets pinned exactly onto a wick.

Dragging a drawing by its *body* is not snapped: it moves by the distance the
pointer has travelled, and pulling one end onto a candle value would stretch or
shift the shape rather than move it.

## What can be drawn

![A ray, an arrow, a horizontal ray, a range box and a Fibonacci retracement](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/shapes.png)

| `DrawingTool` | Taps | Draws |
| --- | --- | --- |
| `horizontal` | 1 | a level across the whole chart |
| `horizontalRay` | 1 | a level that only applies from that candle rightwards |
| `vertical` | 1 | a line marking one candle |
| `text` | 1 | a note pinned to a point, ready to be typed into |
| `trend` | 2 | a segment between two anchors |
| `ray` | 2 | a segment that carries on past its second anchor |
| `extendedLine` | 2 | a segment that carries on past both anchors |
| `arrow` | 2 | a segment with an arrowhead on its far end |
| `rectangle` | 2 | a box between two opposite corners |
| `ellipse` | 2 | an ellipse inscribed in that box |
| `fibRetracement` | 2 | the levels of a swing, labelled and banded |
| `measure` | 2 | a ruler: the move in price, in percent, in candles and in time |
| `triangle` | 3 | a triangle over three corners |
| `channel` | 3 | a base line and a parallel through the third point |
| `position` | 3 | entry, target and stop, with the risk-to-reward worked out |
| `brush` | drag | a freehand stroke |
| `flag` | 1 | a pennant planted on one candle |
| `gannFan` | 2 | rays at Gann's angles, `1×1` through `1×8` and `8×1` |
| `gannBox` | 2 | a box ruled at the same fractions across and down |
| `fibFan` | 2 | rays at the Fibonacci fractions of a swing |
| `fibTimeZones` | 2 | verticals at Fibonacci multiples of a span |
| `regressionTrend` | 2 | the least-squares fit through the candles between, with bands |
| `priceRange` | 2 | a bracket over a price move, in price and percent |
| `dateRange` | 2 | a bracket under a span, in candles and in time |
| `callout` | 2 | a note in a box, with a tail pointing at a candle |
| `pitchfork` | 3 | a median line and its tines, from three swings |
| `fibExtension` | 3 | an impulse projected on from where the retracement ended |
| `xabcd` | 5 | a harmonic pattern, each leg labelled with its retracement |
| `path` | many | straight legs through as many points as are tapped |

The three trend variants are all `TrendLine`s: `extend` (`LineExtension.none`,
`.right`, `.both`) decides how far past its anchors the line runs, and `arrow`
puts a head on the far end, so a ray persisted by an older version of the app
still loads. `HorizontalLine.startTime` is what makes a level a ray. Rectangles
and retracements are their own types, `RectangleDrawing` and `FibRetracement`,
passed in `rectangles` and `fibRetracements` and reported through
`onAddRectangle` / `onRemoveRectangle` and `onAddFibRetracement` /
`onRemoveFibRetracement`.

Every two-point drawing shares one base, `TwoPointDrawing`: two (time, price)
anchors, either of which can be dragged, plus `isComplete` — false while the
second point is still following the pointer.

`xabcd` and `path` are `MultiPointDrawing`s instead: their anchors live in a
`points` list rather than in numbered fields, which is what lets a path take as
many as it is given. Each tap lands a leg. A pattern finishes when its five
points are in; a path has no count to finish on, so it ends when you tap twice
in the same place, or when the tool is disarmed — switching tools finishes an
open path rather than throwing it away.

### Fans, forks and fits

`GannFan`'s second anchor places the `1×1` — one unit of price against one unit
of time — and `ratios` multiplies that slope for the rest of the fan, so `2` is
the `1×2` and `0.5` the `2×1`. `GannBox` divides a range by its own proportions
instead: `ratios` are taken as fractions of the box both ways, so the
horizontals mark those fractions of the price range and the verticals the same
fractions of the span.

`FibFan` spreads rays between the flat `0` and the diagonal `1` of a swing —
support that slopes with time, where a retracement's is level.
`FibTimeZones` reads the other axis: the two anchors set one unit of time and
each level marks that many units on, so a swing that took ten candles projects
lines at 10, 20, 30, 50 and 80. `FibExtension` is the trend-based one: the
first two anchors are the impulse, the third is where the retracement ended,
and the levels are projected on from there rather than drawn between the
anchors.

`PitchforkDrawing` takes a pivot and the swing either side of it. The median
runs through the midpoint of the swing and each level draws a tine parallel to
it — `1` being the tines through the anchors themselves, `0` the median.
`PitchforkKind.andrews` leaves the handle on the pivot, `.schiff` lifts it
halfway to the median in price, and `.modifiedSchiff` lifts it in time as well.

`RegressionChannel` is the one drawing that reads the candles rather than only
the anchors: `fitRegression` runs a least-squares fit through the closes of
everything the two anchors span, and `deviations` places a band either side at
that many standard deviations. Move an anchor and the fit is worked out again,
so the line always describes the stretch it covers rather than the two points
it was dropped on.

```dart
KChartWidget(
  data,
  ChartColors(),
  isTrendLine: true,
  currentDrawingTool: DrawingTool.pitchfork,
  drawings: [
    RegressionChannel(
      time1: candles[20].dateTime!, price1: candles[20].close,
      time2: candles[60].dateTime!, price2: candles[60].close,
      deviations: 2,
    ),
    XabcdDrawing(points: [
      for (final i in [10, 20, 30, 40, 50])
        (time: candles[i].dateTime!, price: candles[i].close),
    ]),
  ],
);
```

```dart
RectangleDrawing(
  time1: candles[20].dateTime!, price1: candles[20].high,
  time2: candles[30].dateTime!, price2: candles[30].low,
  fillOpacity: 0.12,
);

FibRetracement(
  time1: swingLow.dateTime!, price1: swingLow.low,
  time2: swingHigh.dateTime!, price2: swingHigh.high,
  levels: [0, 0.382, 0.5, 0.618, 1],   // defaults to the usual seven
);
```

A retracement's levels run from the drawing rightwards to the edge of the chart,
since what a level is worth is what price does after the move. `DrawingStyle`
carries the rest of the geometry: `arrowHeadLength`, `rectangleFillOpacity`,
`shapeFillOpacity`, `measureFillOpacity`, `channelFillOpacity`,
`positionFillOpacity`, and `fibLevels` and `fibFillOpacity` for new retracements
and their bands.

The three-point shapes — `TriangleDrawing`, `ParallelChannel`, `PositionDrawing`
— share `ThreePointDrawing`, which adds `time3` and `price3` and is not complete
until the third point lands. A channel's parallel runs through that point; a
position takes its entry from the first, its target from the second and its stop
from the third, and works out `reward`, `risk` and `riskReward` for the label:

```dart
final plan = PositionDrawing(
  time1: entry.dateTime!, price1: entry.close,
  time2: candles.last.dateTime!, price2: entry.close * 1.06,
  time3: candles.last.dateTime!, price3: entry.close * 0.98,
);
plan.isLong;       // true — the target is above the entry
plan.riskReward;   // 3.0
```

![A planned position with its risk-to-reward, inside a parallel channel](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/planning.png)

A measurement reads itself out the same way: `priceMove`, `ratio` and `span`, plus
the candle count the chart works out for the label. A note is a `TextAnnotation`
whose `text` the editor's label field types into, and a freehand stroke is a
`FreehandDrawing` — a list of (time, price) points, so it stays on the candles it
was drawn over.

`keepToolArmed` is your own state — the chart never changes `currentDrawingTool`
— but `selectAfterDrawing: false` stops the editor opening over each drawing as
it lands, which is what makes drawing five levels in a row bearable.

Tapping an existing line selects it and opens the editing toolbar. Dragging an
anchor of a two-point drawing moves that anchor; dragging the shape by its
stroke, its outline or one of its levels moves the whole thing, both anchors
together. Every edit — a new colour, a new thickness, a drag, a renamed
label — fires the matching `onAdd*` callback with the updated line, so
persisting a change is the same code path as persisting a new one.

## Persisting a layout

Every drawing serialises, and `drawingFromJson` turns a map back into the drawing
it came from:

```dart
final drawings = ChartDrawings([
  HorizontalLine(price: 42_000, title: 'entry'),
  TrendLine(time1: a, price1: 1, time2: b, price2: 2),
]);

await prefs.setString('layout', jsonEncode(drawings.toJson()));

final saved = prefs.getString('layout');
final restored = saved == null
    ? ChartDrawings()
    : ChartDrawings.fromJson(jsonDecode(saved) as Map<String, dynamic>);
```

`ChartDrawings` is an ordered set of drawings with typed views —
`horizontalLines`, `trendLines`, `positions` and the rest — so the chart can be
handed the whole layout at once through `drawings:`. A drawing of a kind this
version does not know is skipped rather than throwing, so a layout written by a
newer release still opens. `copyDrawing` deep-copies one, by round-tripping it
through its own JSON.

## Undo, redo and the drawing controller

Hand the chart a `ChartDrawingController` and it owns the drawings: what the user
places, restyles, drags or deletes goes through the controller, which is what
makes undo possible.

```dart
final drawings = ChartDrawingController();

KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: true,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  drawingController: drawings,
);

drawings.undo();       // ⌘Z on the chart does the same
drawings.redo();       // ⇧⌘Z, or Ctrl+Y
drawings.clear();      // one undoable step
drawings.select(line); // opens the chart's editor on that drawing
jsonEncode(drawings.toJson());
```

An edit is a step, so restyling a line and undoing gets the old style back — the
controller keeps a deep copy of the last committed state, because the chart edits
a drawing in place and only reports it once the edit lands. `historyLimit`
(50 by default) is how far back it goes; `clearHistory` keeps the drawings and
drops the steps, which is what a fresh symbol wants.

Delete removes the selection, and Escape abandons a drawing being placed. All of
it can be turned off with `enableKeyboardShortcuts: false`. Without a controller
the per-kind lists and callbacks work exactly as before — there is simply no undo.

## Selecting several, and what to do with them

Shift- or ⌘-click a drawing and it joins the selection rather than replacing it;
⌘A takes everything drawn. What follows applies to the lot: dragging one moves
them all together, Delete removes them in a single undoable step, and an edit
made through the line editor — colour, thickness, stroke, fill, label
visibility — is copied onto the rest, which is what a user who selected five
lines to recolour meant. The editor stays open on the last one picked and says
how many it is editing.

```dart
drawings.selection;               // every selected drawing, primary last
drawings.selected;                // the one the editor is open on
drawings.addToSelection(line);
drawings.toggleSelection(line);
drawings.selectAll();
drawings.clearSelection();
drawings.removeAll(drawings.selection);   // one step
```

⌘C copies, ⌘V pastes and ⌘D duplicates, each nudged a few candles clear of the
original so the copy can be seen and grabbed rather than hiding underneath.
The clipboard holds copies, so editing or deleting the originals afterwards
leaves what was copied alone.

```dart
drawings.copyToClipboard(drawings.selection);
drawings.canPaste;
drawings.paste();                  // returns what it added, and selects it
drawings.duplicate(drawings.selection);
```

⌘] and ⌘[ walk the selection up and down the stack, ⇧⌘] and ⇧⌘[ take it all the
way. Later is higher: the last drawing paints over the ones before it, and is
the one a tap in an overlap picks up. Saving an edit no longer restacks the
drawing it edited, so the order the user set is the order that keeps.

```dart
drawings.bringToFront(line);
drawings.sendToBack(line);
drawings.bringForward(line);
drawings.sendBackward(line);
drawings.indexOf(line);            // -1 when it is not there
```

## Style templates

`DrawingTemplate` is one drawing's look, saved so it can be put on another:
colour, thickness, stroke style, fill opacity and label visibility — everything
a drawing shares with every other drawing, and nothing that belongs to one kind
in particular. Applying one to a rectangle and to a trend line gives them the
same look without either having to know about the other.

```dart
final house = DrawingTemplate.of(drawings.selected!);
house.applyTo(otherLine);

// Or keep them on the controller, by name:
drawings.saveTemplate('house', drawings.selected!);
drawings.applyTemplate('house', drawings.selection);   // one undoable step
drawings.templates;                                    // by name
jsonEncode(drawings.templatesToJson());
```

Templates are kept apart from the layout — `templatesToJson` and
`loadTemplates`, not `toJson` — because they outlive any one chart's drawings.

## Exact coordinates

A drawing placed by hand lands on whichever candle the pointer was over, which
is close enough to read a chart by and not close enough to hand to someone
else. The editor's ruler button opens a dialog listing every anchor — a price
and a candle apiece, named `Start`, `End`, `X` through `D`, `Point 3` — and each
one can be typed in exactly. `showDrawingCoordinates: false` leaves the button
out.

The same anchors are readable from code, whatever kind of drawing it is:

```dart
for (final anchor in drawingAnchors(line)) {
  print('${anchor.name}: ${anchor.price} at ${anchor.time}');
}
setDrawingAnchor(line, 1, price: 42_000);   // leaves the time alone
```

A freehand stroke is the one drawing whose anchors cannot be typed into — its
shape is the hundreds of points it was drawn with — so it reads out its two ends
and `drawingAnchorsAreEditable` answers false.

## The right-click menu

A right-click opens a menu, and what it offers depends on what was clicked. On a
drawing: its coordinates, duplicate, copy, restack, lock, hide, its alert where
it has one, and delete — applied to the whole selection where there is one. On
empty chart: paste, select all, fit the price scale, scroll to the newest
candle, undo, redo and clear. Right-clicking a drawing selects it first, so what
the menu is about and what the chart highlights always agree.

`showContextMenu: false` turns it off. `contextMenuBuilder` is handed what was
clicked — the drawing, the candle, the price, and the entries the chart would
have shown — so an item of your own is one line:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: true,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  contextMenuBuilder: (request) => [
    ...request.defaults,
    const ChartMenuDivider(),
    ChartMenuItem(
      label: 'Buy at ${request.price?.toStringAsFixed(2)}',
      icon: Icons.shopping_cart_outlined,
      onSelected: () => orders.buy(request.price!),
    ),
  ],
);
```

Returning a list of your own replaces the menu; returning an empty one shows
none. `ChartMenuItem` takes an `icon`, an `enabled` flag, a `checked` flag for a
toggle and `destructive` for something that throws work away, and
`ChartMenuDivider` rules between groups. `showChartMenu` opens the same menu
from your own button.

## The drawing manager

`DrawingManager` is a plain widget over the same controller: every drawing by
name, with show/hide, lock, delete, undo, redo and clear.

```dart
Row(
  children: [
    Expanded(child: KChartWidget(candles, colors, drawingController: drawings, /* … */)),
    SizedBox(width: 260, child: DrawingManager(controller: drawings)),
  ],
);
```

Tapping a row selects that drawing on the chart, and the chart's own selection
highlights the row. Hiding one leaves it in the layout but off the chart —
`ChartLine.hidden` — and every string it shows, including what each kind is
called, comes from `DrawingTranslations`.

## Level alerts

A `HorizontalLine` with `alert: true` reports through `onAlertCrossed` whenever
the newest candle closes on the other side of it:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: true,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  drawings: [HorizontalLine(price: 42_000, alert: true)],
  onAlertCrossed: (line, candle) => notifier.push('crossed ${line.price}'),
);
```

It fires once per crossing — the market has to come back through the level before
it fires again — and the editor's bell button is what arms one from the chart.

Levels are not the only thing that can be crossed. Any drawing mixing in
`AlertingDrawing` — `HorizontalLine`, `TrendLine`, `ParallelChannel` and
`FibRetracement` — reports through `onDrawingAlert`, which carries the price
that was crossed as well as the drawing and the candle, since a drawing may
have several levels at once:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: true,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  drawings: [
    TrendLine(
      time1: candles[10].dateTime!, price1: candles[10].low,
      time2: candles[40].dateTime!, price2: candles[40].low,
      extend: LineExtension.right,
      alert: true,
    ),
  ],
  onDrawingAlert: (line, candle, level) =>
      notifier.push('crossed ${level.toStringAsFixed(2)}'),
);
```

`alertLevelsAt` is what each drawing answers with, at the newest candle's
instant, so a sloping line reports where it is now rather than where it was
drawn. A segment can only be crossed between its anchors; a ray also counts
rightwards of its second one, and an extended line everywhere. A horizontal
level reports through both callbacks, so an app written against
`onAlertCrossed` carries on working unchanged.

---

[← All docs](README.md) · [Package README](../README.md)
