# Navigation and command palette

## Behavior

The desktop layout uses a left-docked `tablist`. Each tab controls one `tabpanel`, arrow keys move vertically, and selecting a destination updates the page heading and URL fragment. Below 900 CSS pixels, the rail becomes an explicit open/close drawer so content retains horizontal space.

`Ctrl+Shift+F` opens the command palette. Page results activate an exact tab. Setting results activate Settings, scroll the target into view, focus it, and briefly highlight its containing card.

## Configuration

The current dock edge is intentionally fixed to the left. Persistent dock switching, pinning, grouping, overflow management, and the four independent tab searches remain visible as planned inventory rows.

## Failure modes

- An unknown URL fragment falls back to Home.
- A missing palette target closes the dialog without inventing success; structural checks guard all declared targets.
- The mobile rail closes after destination activation.

## Security

Navigation does not fetch content or evaluate user code. Palette filtering uses normalized plain text.

## Verification

Structural checks verify tab/tabpanel linkage, the keyboard shortcut, palette targets, the responsive breakpoint, and focus markers. A real browser pass is still required for screen-reader announcements, touch behavior, and layout clipping.

## Suggested articles

- [Site architecture](architecture.md)
- [Accessibility](../quality/accessibility.md)
- [Regex builder](regex-builder.md)
