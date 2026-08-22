# Repository agent guidance

This file is a public-safe summary of shared working requirements. The canonical shared instructions are managed elsewhere; edit this file only for repository-specific clarification.

## Scope and safety

- Preserve inherited Linphone source, licensing, authorship, and upstream provenance.
- Keep documentation claims evidence-labelled. Do not describe planned or documented behavior as implemented.
- Keep this website visibly separate from the calling runtime.
- Never place secrets, credentials, private machine details, private vocabulary, or personal data in repository files, logs, captures, or public records.
- Do not add code signing. Windows packages are intentionally unsigned and must say so.

## Website requirements

- Use local assets only: no CDN, analytics, trackers, remote fonts, or hidden third-party requests.
- Apply Material Design 3 color roles, typography, shape, elevation, focus, reduced motion, and responsive layout.
- Preserve keyboard navigation, visible focus, semantic controls, adequate target sizes, contrast, and narrow-layout behavior.
- Keep the website as a landing, documentation, download, status, settings, and link surface; it must not become or imitate the calling runtime.
- Keep the desktop/web feature inventory explicit, hand-written, and evidence-driven.
- The current scope excludes exactly the universal local file converter and the local Ollama suite manager.

## Change discipline

- Inspect repository status and fetch before editing; preserve unrelated work.
- Use scoped, auditable changes and deterministic local checks.
- Update README, categorized documentation, roadmap, changelog, and handoff in the same change as user-visible behavior.
- Use ordinary public language in commits, documentation, issues, releases, and site copy. `Slop Machine` is the sole permitted public shared nickname.
- Do not push, merge, publish, tag, release, or delete without the current task's authority.

## Local checks

```powershell
node site/build-site.mjs
node --test site/test-site.mjs
```

The checks must validate the explicit inventory, generated-file freshness, local-only asset policy, interactive-control wiring, accessibility markers, documentation links, and public-vocabulary boundary.
