# Privacy and security

## Behavior

The site is static. It does not place calls, authenticate accounts, collect credentials, send analytics, or contact the desktop runtime. Preferences are stored under one local browser key. Filters, command palette, inventory, and regex feedback run locally.

## Configuration

There is no privacy toggle because no tracking behavior ships. Browser site-data controls remove preferences. The in-site reset removes the site's own preference record.

## Failure modes

- Corrupt, unexpected, or out-of-range local preferences fall back to compiled defaults.
- Refused storage reads, writes, and resets remain non-blocking and report the exact persistence boundary inline.
- Clipboard refusal is reported without claiming a copy.
- Personal-vocabulary file selection is cleared without reading or storing the file.
- An absent release manifest leaves download disabled.

## Security considerations

- Never add third-party script, style, font, image, analytics, or support widgets.
- Never render provider-authored markup without an isolated sanitizer.
- Never write credentials, private paths, personal vocabulary, or account data into local storage, logs, exports, captures, or public files.
- Regex evaluation has explicit input bounds; a time-isolated worker remains required before expanding the surface.

## Verification

Checks scan every executable website source for network-bearing asset references, confirm local script/style paths, and pin the local-storage validation contract. A private runtime-only publication scan checks the complete changed public source against the private vocabulary without committing vocabulary values or a digest. Deployed verification must still inspect the browser network log and served response body.

## Suggested articles

- [Site architecture](../site/architecture.md)
- [Regex builder](../site/regex-builder.md)
- [Status and downloads](../delivery/status-downloads.md)
