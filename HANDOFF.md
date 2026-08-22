# Handoff

## Current integrated baseline

The local `main` branch contains the independent upstream snapshot plus the first desktop, PBX, website, and Windows delivery foundations. These foundations are implemented and locally checked, but no GitHub push, release, deployment, full desktop build, or real application capture is claimed yet.

### Implemented

- Static HTML/CSS/TypeScript website under `site/`.
- Responsive left-docked ARIA tab navigation.
- Local theme, language, and independent funny-level persistence.
- Settings search with adjacent bounded JavaScript regex builder.
- `Ctrl+Shift+F` command palette and exact-control navigation.
- Desktop/web feature inventory with 64 explicit entries and honest status semantics.
- Status cards, disabled download state, local documentation index, and visible runtime boundary copy.
- Categorized feature documentation and public project records.
- Adaptive Qt Quick phone shell, Material Design 3 tokens, and reusable controls.
- Transport-neutral C++17 PBX provider contract, deterministic simulator, and production CMake registration.
- Pinned dependency manifest, one-click build scripts, unsigned Squirrel.Windows packaging contract, and Windows build-and-release workflow.
- GitHub Pages deployment workflow.
- Complete removal of the inaccessible private feature-specification gitlink from the public source tree.

### Evidence boundary

- The website suite passes 10/10 through `node --test site/test-site.mjs`.
- The PBX provider suite passes 18/18 from a fresh native CMake/Ninja build.
- The Material Design 3 source contract passes through `cmake -P Linphone/view/Test/material-foundation-contract.cmake`.
- The delivery contract passes its positive checks and deliberate signing/private-input regressions.
- Both workflow files pass structural actionlint validation with shellcheck integration disabled on Windows.
- No browser capture or built desktop interaction is claimed.
- Status Hub publishing was unavailable in this session.
- No verified Material Phone installer or immutable release manifest exists, so the download action remains disabled.
- The canonical Open Graph URL exists, but a product-specific image and anonymous deployed-byte verification remain open.

### Next owner actions

1. Complete adversarial correctness, security, delivery, and accessibility review of the integrated baseline.
2. Push `main`, monitor both GitHub workflows, and record exact release/deployment evidence.
3. Run the approved hidden interaction route against the built website and desktop artifact at supported widths.
4. Publish and validate an immutable release manifest before enabling any installer link.
5. Implement non-excluded inventory rows in bounded batches, keeping status labels evidence-driven.
