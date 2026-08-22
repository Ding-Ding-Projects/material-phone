# Material Phone

Material Phone is a Windows-focused Material Design 3 direction for the Linphone desktop calling experience. This independent source snapshot now includes the first adaptive phone shell, a transport-neutral PBX provider contract, an evidence-labelled documentation website, and an unsigned Squirrel.Windows delivery foundation.

> **Website boundary:** the website is a landing, documentation, download-status, settings, and link surface. It is not the calling runtime and cannot place or receive calls.

- **Local website:** run `node site/build-site.mjs`, then serve the repository root with any local static server and open `site/index.html`.
- **Installer:** no verified Material Phone installer has been published yet. The website keeps its download action disabled until a release manifest proves an immutable asset.
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
<summary><strong>Desktop and PBX foundation</strong></summary>

- Adaptive Qt Quick phone shell with Material Design 3 tokens and reusable controls.
- Transport-neutral C++17 PBX provider interface with bounded requests, pagination, revisions, idempotency, deadlines, cancellation, and event-gap reporting.
- Deterministic simulator states for healthy, offline, unauthorized, partially authorized, rate-limited, conflicted, and mixed-version behavior.
- No Asterisk-specific transport is claimed yet; the provider boundary is ready for a separately versioned adapter.

</details>

<details>
<summary><strong>Build and deterministic checks</strong></summary>

```powershell
node site/build-site.mjs
node --test site/test-site.mjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-delivery-contract.ps1
```

The build has no package dependency. It validates the feature inventory, generates `site/inventory.js`, and copies browser-standard TypeScript from `site/app.ts` to `site/app.js`.

</details>

<details>
<summary><strong>One-click Windows build and installer</strong></summary>

- `download-dependencies.bat /s` validates the pinned dependency manifest and prepares the declared user-scoped toolchain.
- `build.bat /s` runs the supported application build path without prompts.
- `build-installer.bat /s` builds and validates the unsigned Squirrel.Windows artifact set without publishing it.

Code signing is intentionally disabled. A built installer is expected to trigger the operating system's unknown-publisher warning.

</details>

<details>
<summary><strong>Project scale estimate</strong></summary>

The committed counter currently reports **277,044 total lines** and **266,688 non-blank lines**, excluding submodules, third-party trees, dependency caches, and generated build output. Reproduce the table with `powershell.exe -NoProfile -File scripts/count-lines.ps1 -WithAttribution`.

A human-only implementation estimate is approximately **13–27 engineer-years**: 266,688 non-blank lines divided by an assumed 40–80 finished, reviewed lines per engineer-day gives roughly 3,334–6,667 engineer-days, divided by 250 working days per year. This is an estimate, not a measured schedule; it includes inherited application source and excludes the same material as the counter.

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
