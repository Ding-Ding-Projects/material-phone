# Navigation and command palette

## Behavior

The desktop layout uses a left-docked `tablist`. Every tab has a stable checked-in ID and controls one `tabpanel` whose `aria-labelledby` points back to that exact tab. Arrow keys move vertically, and selecting a destination updates the page heading and URL fragment.

Below 900 CSS pixels, the rail becomes an explicit drawer. The opener exposes `aria-controls` and `aria-expanded`; the closed drawer is inert and `aria-hidden`; opening moves focus to its close control; closing, including with Escape, returns focus to the opener. Moving back to a wide layout removes the mobile-only hidden and inert state.

`Ctrl+Shift+F` opens the command palette. Page results activate an exact tab. Setting results activate Settings, scroll the target into view, focus it, and briefly highlight its containing card.

## Configuration

The current dock edge is intentionally fixed to the left. Persistent dock switching, pinning, grouping, overflow management, and the four independent tab searches remain visible as planned inventory rows.

## Failure modes

- An unknown URL fragment falls back to Home.
- A missing palette target closes the dialog without inventing success; structural checks guard all declared targets.
- The mobile rail closes after destination activation without returning focus away from the newly activated content.
- Repeated `Ctrl+Shift+F` presses reuse the already-open command palette instead of calling `showModal()` again.

## Security

Navigation does not fetch content or evaluate user code. Palette filtering uses normalized plain text.

## Verification

Structural checks verify exact tab/tabpanel linkage, the keyboard shortcut, palette targets, drawer state wiring, Escape handling, the responsive breakpoint, and focus markers. A deliberate accessibility negative proof removes the drawer's control relationship and must turn red before the original markup turns green. A real browser pass is still required for screen-reader announcements, touch behavior, and layout clipping.

## Suggested articles

- [Site architecture](architecture.md)
- [Accessibility](../quality/accessibility.md)
- [Regex builder](regex-builder.md)
