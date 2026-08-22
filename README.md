# Material Phone

Material Phone is a Windows-focused Material Design 3 direction for the Linphone desktop calling experience. This repository currently contains an evidence-labelled documentation website alongside inherited upstream desktop source.

> **Website boundary:** the website is a landing, documentation, download-status, settings, and link surface. It is not the calling runtime and cannot place or receive calls.

- **Local website:** run `node site/build-site.mjs`, then serve the repository root with any local static server and open `site/index.html`.
- **Installer:** no verified Material Phone installer is published from this documentation lane. The website keeps its download action disabled.
- **Documentation:** start with [docs/README.md](docs/README.md).
- **Upstream provenance:** see [UPSTREAM.md](UPSTREAM.md).

<details>
<summary><strong>Website capabilities</strong></summary>

- Responsive, left-docked browser-style tabs.
- Light, dark, and high-contrast local themes.
- English, playful Hong Kong-style Cantonese, and bilingual presentation choices.
- Independent English and Cantonese funny-level sliders.
- Settings search with an adjacent JavaScript regex builder.
- `Ctrl+Shift+F` command palette with exact-tab and exact-control navigation.
- Desktop/web feature inventory with evidence-labelled states.
- Repository-derived status cards and an evidence-gated download surface.
- No CDN, remote fonts, analytics, tracking, or runtime API calls.

</details>

<details>
<summary><strong>Build and deterministic checks</strong></summary>

```powershell
node site/build-site.mjs
node --test site/test-site.mjs
```

The build has no package dependency. It validates the feature inventory, generates `site/inventory.js`, and copies browser-standard TypeScript from `site/app.ts` to `site/app.js`.

</details>

<details>
<summary><strong>Coverage and exclusions</strong></summary>

The hand-written inventory is [site/data/feature-inventory.json](site/data/feature-inventory.json). It lists every in-scope canonical desktop and web contract independently and never treats documentation as implementation.

The current user explicitly excluded exactly two contracts from this project scope:

1. Universal local file converter.
2. Local Ollama suite manager.

All other incomplete contracts remain visible as `planned` or `documented`, with a concrete evidence boundary or next action.

</details>

<details>
<summary><strong>Licensing and upstream</strong></summary>

The inherited Linphone desktop source remains subject to its existing license terms in [LICENSE.txt](LICENSE.txt). Material Phone documentation does not change upstream ownership, trademarks, or licensing. See [UPSTREAM.md](UPSTREAM.md) for links and the separation between inherited code and this authored documentation layer.

</details>

## Project records

- [Roadmap](ROADMAP.md)
- [Handoff](HANDOFF.md)
- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
