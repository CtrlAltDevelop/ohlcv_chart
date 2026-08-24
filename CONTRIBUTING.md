# Contributing

Thanks for considering it. This is a solo-maintained package, so the biggest
favour a contribution can do is arrive in a shape that is fast to review —
this page is mostly about that.

## Setup

```bash
flutter pub get
cd example && flutter pub get && cd ..
```

The [example app](example/) exercises the whole package and is the fastest way
to see a change working:

```bash
cd example
flutter run
```

## Before opening a pull request

```bash
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```

All three run in CI; a PR that fails one will not be merged until it passes.

## Code style

- Match the surrounding file before reaching for a personal preference —
  this package has a consistent voice and it is worth keeping.
- Comment the *why*, not the *what*. A hidden constraint or a subtle
  invariant deserves a line; what the code already says by being
  well-named does not.
- No speculative generality. A feature is built for what it needs to do
  today, not for a hypothetical future setting or platform.
- New behaviour needs a test. A bug fix needs one that fails without the
  fix and passes with it — that is what proves the fix and keeps it fixed.

## Adding an indicator or drawing tool

Both are the extension points people usually reach for first:

- An indicator implements `Indicator` (see [`doc/indicators.md`](doc/indicators.md))
  and, to be saveable through `ChartWorkspace`, gets an entry in
  `lib/src/indicators/indicator_catalog.dart` describing its settings.
- A drawing tool implements one of the base classes in `lib/src/entity/`
  (see [`doc/drawing-tools.md`](doc/drawing-tools.md)) and a codec entry in
  `lib/src/entity/drawing_codec.dart` so it can be saved and restored.

Either way, look at a couple of existing ones in the same family first —
`RsiIndicator` or `TrendLine` are reasonable starting points — and follow
their shape rather than inventing a new one.

## Docs and the changelog

- A change to public behaviour gets an entry in [`CHANGELOG.md`](CHANGELOG.md),
  under an `## Unreleased` heading if one doesn't already exist at the top.
- If the change touches an area [`doc/`](doc/) already covers, update that
  page too. A new top-level feature gets a new page, linked from both
  [`README.md`](README.md) and [`doc/README.md`](doc/README.md).

## Reporting a bug or requesting a feature

Use the issue templates — they ask for the couple of things that are always
needed anyway (a reproduction, the version, the platform), which usually saves
a round trip.

## License

By contributing, you agree your contribution is licensed under this
project's [MIT license](LICENSE).
