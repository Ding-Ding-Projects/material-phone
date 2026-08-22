# Site architecture

## Behavior

`site/index.html` supplies semantic content and interaction targets. `site/styles.css` defines local Material Design 3 roles and responsive behavior. `site/app.ts` is browser-standard TypeScript source. `site/build-site.mjs` copies it deterministically to `site/app.js` and generates `site/inventory.js` from the hand-written JSON inventory.

The site renders six destinations: Home, Features, Documentation, Download, Status, and Settings. The Home page states the central boundary: the website does not place or receive calls.

## Configuration

No package installation is required:

```powershell
node site/build-site.mjs
```

Serve the repository root through a local static server. Serving the root keeps `site/` links to `docs/` valid.

## Failure modes

- If generated files are stale, deterministic checks fail.
- If JavaScript is disabled, the static boundary and content remain readable, but tabs and settings do not operate.
- Opening `site/index.html` directly supports the core interactions, though links to Markdown rely on the browser's local-file policy.
- No runtime state, account, or installer is inferred when its evidence is absent.

## Security and privacy

There are no CDN scripts, remote fonts, analytics, trackers, authentication forms, or calling APIs. Preferences use local browser storage. Network access is not required for settings, inventory, filters, or the command palette.

## Verification

Run `node --test site/test-site.mjs`. Browser interaction and visual evidence require the separately approved hidden browser route and are not claimed by structural checks.

## Suggested articles

- [Navigation and command palette](navigation.md)
- [Settings and localization](settings.md)
- [Privacy and security](../quality/privacy-security.md)
