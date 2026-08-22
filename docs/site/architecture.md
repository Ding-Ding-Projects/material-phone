# Site architecture

## Behavior

`site/index.html` supplies semantic content and interaction targets. `site/styles.css` defines local Material Design 3 roles and responsive behavior. `site/app.ts` is browser-standard TypeScript source. `site/build-site.mjs` generates `site/app.js`, `site/inventory.js`, and `site/metadata.js` from reviewed sources.

The site renders six destinations: Home, Features, Documentation, Download, Status, and Settings. The Home page states the central boundary: the website does not place or receive calls.

## Configuration

No package installation is required:

```powershell
node site/build-site.mjs
node site/build-site.mjs --check
```

The default metadata records no commit or generation time, which is honest for a local source preview. The Pages workflow supplies the exact checked-out commit, the current UTC build-generation time, and the published `docs/` base before generation. `site/stage-pages.mjs` stages the website at the artifact root and documentation below `docs/`; `site/check-pages-artifact.mjs` proves the required files and documentation-card destinations exist before upload.

## Failure modes

- If generated files are stale, `--check` fails before writing anything and names the stale outputs.
- If the staged artifact omits a website asset or documentation article, the artifact contract fails before upload.
- If JavaScript is disabled, the static boundary and content remain readable, but tabs and settings do not operate.
- Opening `site/index.html` directly supports the core interactions, though links to Markdown rely on the browser's local-file policy.
- No runtime state, account, or installer is inferred when its evidence is absent.

## Security and privacy

There are no CDN scripts, remote fonts, analytics, trackers, authentication forms, or calling APIs. Preferences use local browser storage. Network access is not required for settings, inventory, filters, or the command palette.

## Verification

Run `node --test site/test-site.mjs`. The suite deliberately makes tracked output stale, proves `--check` turns red without rewriting it, restores the original bytes, and proves green. It also stages and validates one complete Pages artifact. Browser interaction and visual evidence require the separately approved hidden browser route and are not claimed by structural checks.

## Suggested articles

- [Navigation and command palette](navigation.md)
- [Settings and localization](settings.md)
- [Privacy and security](../quality/privacy-security.md)
