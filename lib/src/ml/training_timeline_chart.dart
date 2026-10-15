import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../timeline/trade_timeline_chart.dart';

/// Where a training job is in its life.
enum JobStatus {
  /// Still running.
  running,

  /// Finished normally.
  completed,

  /// Stopped by an error: an out-of-memory, a NaN loss, a crash.
  failed,

  /// Taken off its machine for something else, to be resumed.
  preempted,

  /// Stopped by hand.
  cancelled,
}

/// One training job: what ran, where, and when.
@immutable
class TrainingJob {
  /// Creates a job called [name] that ran on [node] from [start] to [end].
  const TrainingJob({
    required this.name,
    required this.start,
    this.end,
    this.node,
    this.status = JobStatus.completed,
    this.gpus,
    this.data,
  });

  /// What the job is called.
  final String name;

  /// When it started.
  final DateTime start;

  /// When it ended; null while it is still running.
  final DateTime? end;

  /// The machine or pool it ran on — one lane each; null puts it in an unnamed
  /// lane.
  final String? node;

  /// How it ended.
  final JobStatus status;

  /// How many accelerators it held.
  final int? gpus;

  /// Anything the app wants back when this job is touched.
  final Object? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingJob &&
          other.name == name &&
          other.start == start &&
          other.end == end &&
          other.node == node &&
          other.status == status &&
          other.gpus == gpus &&
          other.data == data;

  @override
  int get hashCode => Object.hash(name, start, end, node, status, gpus, data);
}

/// What a touch on a [TrainingTimelineChart] landed on.
@immutable
class TrainingJobTouchDetails {
  /// Creates the details of a touch on [job] at [time].
  const TrainingJobTouchDetails({required this.job, required this.time});

  /// The job touched.
  final TrainingJob job;

  /// The time under the pointer.
  final DateTime time;

  /// How long the job has run, to [now] while it is still going.
  Duration duration(DateTime now) => (job.end ?? now).difference(job.start);
}

/// Training jobs on a timeline: a lane per machine, a bar from start to end
/// coloured by how it finished, and how many were running underneath.
///
/// ```dart
/// TrainingTimelineChart(
///   jobs: [
///     TrainingJob(
///       name: 'llama-8b-sft',
///       node: 'pod-a',
///       start: DateTime(2026, 9, 1, 8),
///       end: DateTime(2026, 9, 1, 19),
///       status: JobStatus.completed,
///     ),
///   ],
/// );
/// ```
///
/// It is a [TradeTimelineChart] underneath, so lanes, the time axis and the
/// pointer behave the same. The chart fills the box it is given, and is
/// [defaultHeight] high in a box with no height of its own.
class TrainingTimelineChart extends StatelessWidget {
  /// Creates a timeline of [jobs].
  const TrainingTimelineChart({
    super.key,
    required this.jobs,
    this.now,
    this.runningColor = const Color(0xFF4C86CD),
    this.completedColor = const Color(0xFF2F9E44),
    this.failedColor = const Color(0xFFE03131),
    this.preemptedColor = const Color(0xFFF2B01E),
    this.cancelledColor = const Color(0xFF868E96),
    this.showNames = true,
    this.nameStyle,
    this.showRunningCount = true,
    this.countColor = const Color(0xFF4C86CD),
    this.maxRowHeight = 44,
    this.showLegend = true,
    this.legendStyle,
    this.statusLabels = const {},
    this.laneLabelWidth = 72,
    this.laneLabelStyle,
    this.axisLabelStyle,
    this.timeFormatter,
    this.gridColor = const Color(0x22FFFFFF),
    this.onTouch,
    this.tooltipBuilder,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 240,
    this.semanticLabel,
  });

  /// The jobs, in any order.
  final List<TrainingJob> jobs;

  /// The time running jobs are drawn to; null uses the latest time among the
  /// jobs.
  final DateTime? now;

  /// The colour of a job still running.
  final Color runningColor;

  /// The colour of a job that finished.
  final Color completedColor;

  /// The colour of a job that failed.
  final Color failedColor;

  /// The colour of a job that was preempted.
  final Color preemptedColor;

  /// The colour of a job that was cancelled.
  final Color cancelledColor;

  /// Whether each job's name is written in its bar.
  final bool showNames;

  /// Style of the names.
  final TextStyle? nameStyle;

  /// Whether a strip underneath counts the jobs running at each moment.
  final bool showRunningCount;

  /// The colour of that strip.
  final Color countColor;

  /// How tall a job's bar may be, so a few lanes fill the box rather than
  /// hugging the top of it.
  final double maxRowHeight;

  /// Whether the statuses in use are listed under the chart.
  final bool showLegend;

  /// Style of the legend.
  final TextStyle? legendStyle;

  /// What each status is called in the legend; those left out use English.
  final Map<JobStatus, String> statusLabels;

  /// Room held for the lane names.
  final double laneLabelWidth;

  /// Style of the lane names.
  final TextStyle? laneLabelStyle;

  /// Style of the time axis labels.
  final TextStyle? axisLabelStyle;

  /// Writes a time on the axis; null picks a form by the span.
  final String Function(DateTime time)? timeFormatter;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color gridColor;

  /// Called as a touch moves over the jobs, and with null when it leaves.
  final ValueChanged<TrainingJobTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched job; null shows none.
  final Widget? Function(BuildContext context, TrainingJobTouchDetails details)?
  tooltipBuilder;

  /// How long the bars take to grow in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build animates.
  final bool animateOnMount;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// The height taken in a box that sets none.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  /// The colour a job of [status] is drawn in.
  Color colorOf(JobStatus status) => switch (status) {
    JobStatus.running => runningColor,
    JobStatus.completed => completedColor,
    JobStatus.failed => failedColor,
    JobStatus.preempted => preemptedColor,
    JobStatus.cancelled => cancelledColor,
  };

  @override
  Widget build(BuildContext context) {
    final trades = [
      for (final job in jobs)
        TimelineTrade(
          entryTime: job.start,
          // A job still marked running has no end, whatever it was given.
          exitTime: job.status == JobStatus.running ? null : job.end,
          lane: job.node,
          color: colorOf(job.status),
          quantity: job.gpus?.toDouble(),
          data: job,
        ),
    ];

    final touch = onTouch;
    final builder = tooltipBuilder;
    TrainingJobTouchDetails details(TradeTimelineTouchDetails t) =>
        TrainingJobTouchDetails(
          job: t.trade.data! as TrainingJob,
          time: t.time,
        );

    final chart = TradeTimelineChart(
      trades: trades,
      maxRowHeight: maxRowHeight,
      now: now,
      showPnl: false,
      showSideMarkers: false,
      shadeByPnl: false,
      showExposure: showRunningCount,
      exposureColor: countColor,
      laneLabelWidth: laneLabelWidth,
      laneLabelStyle: laneLabelStyle,
      axisLabelStyle: axisLabelStyle,
      timeFormatter: timeFormatter,
      gridColor: gridColor,
      onTouch: touch == null
          ? null
          : (t) => touch(t == null ? null : details(t)),
      tooltipBuilder: builder == null
          ? null
          : (context, t) => builder(context, details(t)),
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      animateOnMount: animateOnMount,
      padding: padding,
      backgroundColor: backgroundColor,
      defaultHeight: defaultHeight,
      semanticLabel: semanticLabel,
    );
    if (!showLegend || jobs.isEmpty) return chart;

    const names = {
      JobStatus.running: 'Running',
      JobStatus.completed: 'Completed',
      JobStatus.failed: 'Failed',
      JobStatus.preempted: 'Preempted',
      JobStatus.cancelled: 'Cancelled',
    };
    final used = [
      for (final s in JobStatus.values)
        if (jobs.any((j) => j.status == s)) s,
    ];
    final style = const TextStyle(
      fontSize: 11,
      color: Color(0xFF8B95A1),
    ).merge(legendStyle);
    final legend = Padding(
      padding: EdgeInsets.only(
        top: 8,
        left: padding.left + laneLabelWidth,
        right: padding.right,
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final s in used)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorOf(s),
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                  child: const SizedBox(width: 10, height: 10),
                ),
                const SizedBox(width: 5),
                Text(statusLabels[s] ?? names[s]!, style: style),
              ],
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) =>
          (constraints.hasBoundedHeight && constraints.maxHeight < 100) ||
              (constraints.hasBoundedWidth &&
                  constraints.maxWidth <
                      padding.horizontal + laneLabelWidth + 80)
          // No room for a legend as well: the chart alone, rather than
          // overflowing.
          ? chart
          : constraints.hasBoundedHeight
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: chart),
                legend,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: defaultHeight, child: chart),
                legend,
              ],
            ),
    );
  }

  /// Whether [a] and [b] are the same jobs.
  static bool sameJobs(List<TrainingJob> a, List<TrainingJob> b) =>
      listEquals(a, b);
}
