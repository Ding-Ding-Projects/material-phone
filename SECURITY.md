# Security policy

## Reporting

Do not place sensitive information in public issues. Use the repository owner's private security-reporting channel when one is configured. If no private channel is available, report only a minimal non-sensitive description and request a secure contact route.

## Website security boundary

The website is static and does not authenticate visitors, place calls, process account credentials, or expose the calling runtime. Visitor preferences use local browser storage. The current personal-vocabulary control deliberately does not read or store selected files because its full bounded validator is not implemented.

The site must not add analytics, trackers, remote fonts, CDN scripts, credential collection, guessed installer URLs, privileged remote markup, or private machine details.

## Downloads

No installer action may become active until an immutable release manifest proves the intended commit, version, unsigned Squirrel.Windows artifact set, SHA-256, and downloadable asset URL. Unsigned packages must be described honestly and must never claim signature authenticity.

## Supported scope

Security maintenance currently covers repository documentation and the static website behavior added under `site/`. Inherited Linphone security reports should follow upstream guidance unless the issue is introduced by this repository's own changes.
