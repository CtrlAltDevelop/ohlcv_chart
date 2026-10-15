import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

final _start = DateTime.utc(2026, 9, 1, 8);

List<TrainingJob> _jobs() => [
  TrainingJob(
    name: 'sft-8b',
    node: 'pod-a',
    start: _start,
    end: _start.add(const Duration(hours: 6)),
    status: JobStatus.completed,
    gpus: 64,
  ),
  TrainingJob(
    name: 'sft-70b',
    node: 'pod-b',
    start: _start.add(const Duration(hours: 1)),
    end: _start.add(const Duration(hours: 3)),
    status: JobStatus.failed,
  ),
  TrainingJob(
    name: 'rl',
    node: 'pod-a',
    start: _start.add(const Duration(hours: 7)),
    status: JobStatus.running,
  ),
];

void main() {
  Widget host(Widget chart) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 500, height: 300, child: chart)),
  );

  test('each status has a colour of its own', () {
    const chart = TrainingTimelineChart(jobs: []);
    final colors = {for (final s in JobStatus.values) chart.colorOf(s)};

    expect(colors, hasLength(JobStatus.values.length));
  });

  testWidgets('draws the jobs as a trade timeline coloured by status', (
    tester,
  ) async {
    await tester.pumpWidget(host(TrainingTimelineChart(jobs: _jobs())));

    final timeline = tester.widget<TradeTimelineChart>(
      find.byType(TradeTimelineChart),
    );
    expect(timeline.trades, hasLength(3));
    expect(timeline.trades[0].color, const Color(0xFF2F9E44));
    expect(timeline.trades[1].color, const Color(0xFFE03131));
    expect(timeline.trades[2].exitTime, isNull);
    expect(timeline.trades[0].lane, 'pod-a');
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists the statuses in use, and only those', (tester) async {
    await tester.pumpWidget(host(TrainingTimelineChart(jobs: _jobs())));

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Preempted'), findsNothing);
  });

  testWidgets('the legend can go, and the statuses can be renamed', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(TrainingTimelineChart(jobs: _jobs(), showLegend: false)),
    );
    expect(find.text('Completed'), findsNothing);

    await tester.pumpWidget(
      host(
        TrainingTimelineChart(
          jobs: _jobs(),
          statusLabels: const {JobStatus.failed: 'Crashed'},
        ),
      ),
    );
    expect(find.text('Crashed'), findsOneWidget);
  });

  testWidgets('a box too small for a legend draws the chart alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1,
              height: 1,
              child: TrainingTimelineChart(jobs: _jobs()),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Completed'), findsNothing);
  });

  testWidgets('a running job is open whatever end it was given', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TrainingTimelineChart(
          jobs: [
            TrainingJob(
              name: 'x',
              start: _start,
              end: _start.add(const Duration(hours: 1)),
              status: JobStatus.running,
            ),
          ],
        ),
      ),
    );

    final timeline = tester.widget<TradeTimelineChart>(
      find.byType(TradeTimelineChart),
    );
    expect(timeline.trades.single.exitTime, isNull);
  });

  test('a job\'s duration runs to now while it is going', () {
    final job = _jobs().last;
    final details = TrainingJobTouchDetails(job: job, time: _start);

    expect(
      details.duration(_start.add(const Duration(hours: 10))),
      const Duration(hours: 3),
    );
  });

  testWidgets('survives no jobs, and a job that ends before it starts', (
    tester,
  ) async {
    await tester.pumpWidget(host(const TrainingTimelineChart(jobs: [])));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      host(
        TrainingTimelineChart(
          jobs: [
            TrainingJob(
              name: 'odd',
              start: _start,
              end: _start.subtract(const Duration(hours: 1)),
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
