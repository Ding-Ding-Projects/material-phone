# Settings and localization

## Behavior

Settings include light, dark, and high-contrast themes; English, playful Hong Kong-style Cantonese, and bilingual presentation; independent English and Cantonese funny-level sliders from 1 to 5; a visible personal-vocabulary file control; and reset.

Theme, language, and funny levels persist in one versioned local-storage record. Both funny levels default to 5 and style voice only. The runtime-boundary fact remains exact in every language mode.

The personal-vocabulary file control is deliberately honest: the full bounded validator is not implemented, so selection is cleared immediately and no bytes or filename are stored.

## Configuration

The storage key is `material-phone-site-preferences-v1`. Reset removes only that record. Browser site-data controls remain the complete manual reset route.

## Failure modes

- Invalid stored JSON falls back to compiled defaults.
- Clipboard refusal produces a recovery message instead of a false success.
- Personal-vocabulary selection reports that processing is unavailable.
- Unsupported preference values are overwritten by valid controls on the next deliberate change.

## Security and privacy

No setting makes a network request. The file control never reads, logs, uploads, caches, or exports selected content in this build.

## Verification

Structural checks pin all settings controls, local storage, three themes, three languages, independent sliders, reset, and the non-processing vocabulary boundary. Browser interaction proof remains open.

## Suggested articles

- [Regex builder](regex-builder.md)
- [Privacy and security](../quality/privacy-security.md)
- [Accessibility](../quality/accessibility.md)
