# Provenance

## Behavior

Material Phone documentation sits beside inherited Linphone desktop source. The repository keeps three evidence layers separate: upstream behavior, Material Phone design/documentation intent, and verified Material Phone implementation.

## Configuration

Upstream links and license references live in `UPSTREAM.md`. Website inventory rows never infer desktop implementation from upstream source presence.

## Failure modes

- Rebranding inherited behavior as newly implemented would erase provenance.
- Treating documentation as runtime evidence would overstate delivery.
- Linking to an upstream installer as a Material Phone release would misidentify the artifact.

## Security and legal considerations

Preserve upstream copyright, licensing, protocol claims, and trademarks. Do not publish credentials, private infrastructure, or proprietary upstream material.

## Verification

Review `git diff` for authored paths, confirm upstream links and license references, and keep download disabled until a Material Phone artifact is independently verified.

## Suggested articles

- [Feature inventory](../features/inventory.md)
- [Status and downloads](../delivery/status-downloads.md)
- [Site architecture](../site/architecture.md)
