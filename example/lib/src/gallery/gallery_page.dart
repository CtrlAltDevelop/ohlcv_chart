// The gallery: every chart in the package, one page each.
import 'package:flutter/material.dart';

import '../demo_state.dart';
import 'gallery_entries.dart';

/// A list of every chart in the package, each opening a page of its own.
class GalleryPage extends StatefulWidget {
  /// Creates the gallery over [state].
  const GalleryPage({required this.state, super.key});

  /// The demo's settings, shared with the other pages.
  final DemoState state;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = [
      for (final entry in galleryEntries())
        if (query.isEmpty ||
            entry.title.toLowerCase().contains(query) ||
            entry.blurb.toLowerCase().contains(query) ||
            entry.id.contains(query))
          entry,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Search ${galleryEntries().length} charts',
              border: const OutlineInputBorder(),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? const Center(child: Text('Nothing by that name.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  children: [
                    for (final group in GalleryGroup.values)
                      if (matches.any((entry) => entry.group == group)) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                          child: Text(
                            group.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        for (final entry in matches)
                          if (entry.group == group)
                            _EntryCard(entry: entry, state: widget.state),
                      ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.state});

  final GalleryEntry entry;
  final DemoState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Text(entry.title),
        subtitle: Text(entry.blurb),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GalleryDetailPage(entry: entry, state: state),
          ),
        ),
      ),
    );
  }
}

/// One chart, filling a page, with everything it can show stacked down it.
class GalleryDetailPage extends StatefulWidget {
  /// Creates the page for [entry].
  const GalleryDetailPage({
    required this.entry,
    required this.state,
    super.key,
  });

  /// The chart being shown.
  final GalleryEntry entry;

  /// The demo's settings, for the palette switch.
  final DemoState state;

  @override
  State<GalleryDetailPage> createState() => _GalleryDetailPageState();
}

class _GalleryDetailPageState extends State<GalleryDetailPage> {
  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final dark = widget.state.dark;
    final paper = dark ? const Color(0xFF161B22) : Colors.white;
    final border = dark ? const Color(0xFF252C35) : const Color(0xFFE3E6EA);

    return Scaffold(
      appBar: AppBar(title: Text(entry.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              entry.blurb,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          for (final variant in entry.variants)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: paper,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          variant.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (variant.figure != null)
                        Text(
                          variant.figure!,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: variant.figureColor,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(height: variant.height, child: variant.build()),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: SelectableText(
              'Reference: doc/${entry.doc}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
