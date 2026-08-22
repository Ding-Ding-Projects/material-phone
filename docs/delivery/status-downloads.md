# Status and downloads

## Behavior

Status cards are derived from the checked-in feature inventory. They report implemented web count, implemented desktop count, explicit exclusions, installer availability, network boundary, and Status Hub availability.

The Download page disables its installer action because this lane has no validated release manifest. It does not fall back to an upstream binary, mutable latest URL, candidate tag, or guessed asset.

## Configuration

The download action is configured from a future checked-in, validated release manifest. Before enabling download, that manifest must bind:

1. version and target commit;
2. immutable release URL;
3. unsigned Squirrel.Windows `Setup.exe`, `RELEASES`, full package, and applicable deltas;
4. SHA-256 for each asset;
5. package verification state and exact warning copy;
6. release notes and evidence timestamp.

## Failure modes

Missing, partial, mutable, mismatched, or unreachable manifest data leaves the action absent or disabled. Status cards must say `unverified` or `unavailable`, never infer success from intent.

## Security

The site never accepts signing material or claims a signature. Future downloads must disclose that artifacts are unsigned and may trigger an operating-system publisher warning.

## Verification

Current checks assert the button is disabled and the blocker is visible. Future publication must fetch the deployed HTML and asset anonymously, verify 2xx image/installer responses, validate digests, and then test the enabled action.

## Suggested articles

- [Feature inventory](../features/inventory.md)
- [Privacy and security](../quality/privacy-security.md)
- [Provenance](../project/provenance.md)
