# Contributing

Thank you for improving Material Phone documentation.

## Before a change

1. Read [AGENTS.md](AGENTS.md), [UPSTREAM.md](UPSTREAM.md), and the relevant article under `docs/`.
2. Keep inherited desktop-source changes separate from website-only work.
3. State whether a change is implemented, documented, planned, or excluded, and name the evidence.

## Website workflow

```powershell
node site/build-site.mjs
node --test site/test-site.mjs
```

When changing `site/app.ts` or `site/data/feature-inventory.json`, regenerate `site/app.js` and `site/inventory.js`. Generated files must remain byte-for-byte current.

## Quality expectations

- Use semantic HTML and keyboard-operable controls.
- Keep every target at least 44 CSS pixels where practical.
- Verify light, dark, high-contrast, reduced-motion, and narrow layouts.
- Keep all assets local and avoid network requests for visitor preferences or documentation behavior.
- Never enable a download link without an immutable verified asset record.
- Update affected documentation, roadmap items, changelog, and handoff.

## Upstream contributions

Changes intended for Linphone itself should follow the upstream project's contribution process. This repository's documentation direction does not replace upstream review, contributor agreements, or licensing requirements.
