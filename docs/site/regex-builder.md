# Regex builder

## Behavior

The settings search has an adjacent anchored builder. It exposes a raw pattern, `i` and `m` flags, guided insertions for anchors, groups, alternation, and quantifiers, sample text, syntax feedback, sample match count, apply, and copy.

Plain-text search remains the default. Applying a valid expression switches the settings filter to JavaScript regular-expression semantics. Typing directly in the plain search resets regex mode.

## Configuration

The builder uses the browser's JavaScript `RegExp` engine with these explicit bounds:

- Engine: browser JavaScript `RegExp`.
- Maximum pattern length: 256 characters.
- Maximum evaluated sample: 4,096 characters.
- Maximum reported sample matches: 100.
- Flags: ignore case and multiline.

These bounds reduce accidental resource use but are not a complete defense against catastrophic backtracking. Future production expansion should evaluate expressions in an isolated time-bounded worker.

## Failure modes

Invalid expressions remain visible and produce inline syntax feedback. Empty results produce a non-blocking no-match message. Clipboard refusal leaves the pattern selected and provides manual-copy guidance.

## Security and privacy

Patterns and sample text stay in memory and are not persisted or transmitted.

## Verification

Structural checks cover builder controls, bounds, JavaScript engine naming, feedback, apply, copy, and plain-text reset. Browser tests should add invalid, Unicode, multiline, zero-width, capture-group, and adversarial patterns.

## Suggested articles

- [Settings and localization](settings.md)
- [Navigation and command palette](navigation.md)
- [Privacy and security](../quality/privacy-security.md)
