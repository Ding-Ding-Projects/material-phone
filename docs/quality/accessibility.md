# Accessibility

## Behavior

The site includes a skip link, semantic landmarks, a vertical ARIA tablist, associated tabpanels, roving tab focus, visible focus rings, labelled controls, live regions, a native dialog, minimum 44-pixel control height, high-contrast theme, and reduced-motion handling.

At narrow widths, the navigation rail becomes an explicit drawer with open and close controls. Wide inventory content scrolls inside its table container rather than forcing body overflow.

## Configuration

Visitors can select high contrast and browser reduced-motion preferences are honored automatically. Language presentation and funny levels never change control meaning or factual warnings.

## Failure modes

- JavaScript-disabled tabs do not switch, though static content and boundary copy remain present.
- A browser without native `dialog` support needs a future fallback.
- Screen-reader, touch, zoom, and actual high-scale behavior remain unverified until real browser interaction evidence exists.

## Security

Accessibility names contain only public product language. No private vocabulary or file content is injected into names.

## Verification

Structural checks assert landmarks, tab semantics, focus style, reduced motion, mobile breakpoints, live regions, and target sizing. Required follow-up covers keyboard-only traversal, screen-reader announcements, 320px layouts, 200% zoom, touch input, and light/dark/high-contrast visual inspection.

## Suggested articles

- [Navigation and command palette](../site/navigation.md)
- [Settings and localization](../site/settings.md)
- [Privacy and security](privacy-security.md)
