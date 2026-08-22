# Settings and localization

## Behavior

Settings include light, dark, and high-contrast themes; English, playful Hong Kong-style Cantonese, and bilingual presentation; independent English and Cantonese funny-level sliders from 1 to 5; a visible personal-vocabulary file control; and reset.

Theme, language, and funny levels persist in one versioned local-storage record. Stored theme and language values are allowlisted, funny levels must be integers from 1 to 5, arrays and unexpected shapes fall back to defaults, and both funny levels default to 5. The runtime-boundary fact remains exact in every language mode.

The personal-vocabulary file control is deliberately honest: the full bounded validator is not implemented, so selection is cleared immediately and no bytes or filename are stored.

## Configuration

The storage key is `material-phone-site-preferences-v1`. Reset removes only that record. Browser site-data controls remain the complete manual reset route.

## Failure modes

- Invalid JSON, unknown values, and out-of-range funny levels fall back to compiled defaults.
- Refused storage reads keep the current page usable and state plainly that changes cannot survive reload.
- Refused writes keep the visible change for the page and report that it was not persisted.
- Refused reset removes the visible customization for the page and reports that storage could not be cleared.
- Clipboard refusal produces a recovery message instead of a false success.
- Personal-vocabulary selection reports that processing is unavailable.
- Unsupported preference values are overwritten by valid controls on the next deliberate change.

## Security and privacy

No setting makes a network request. The file control never reads, logs, uploads, caches, or exports selected content in this build. Storage refusal is an ordinary non-blocking inline state rather than a fabricated success.

## Verification

Structural checks pin all settings controls, allowlists and ranges, refused-storage copy, three themes, three languages, independent sliders, reset, and the non-processing vocabulary boundary. Settings filtering updates one inline result region instead of stacking repeated no-match notifications. Browser interaction proof remains open.

## Suggested articles

- [Regex builder](regex-builder.md)
- [Privacy and security](../quality/privacy-security.md)
- [Accessibility](../quality/accessibility.md)
