# Handoff

## Current integrated baseline

The local `main` branch contains the independent upstream snapshot plus the first desktop, PBX, website, and Windows delivery foundations. These foundations are implemented and locally checked, but no GitHub push, release, deployment, full desktop build, or real application capture is claimed yet.

### Implemented

- Static HTML/CSS/TypeScript website under `site/`.
- Responsive left-docked ARIA tab navigation.
- Local theme, language, and independent funny-level persistence.
- Settings search with adjacent bounded JavaScript regex builder.
- `Ctrl+Shift+F` command palette and exact-control navigation.
- Desktop/web feature inventory with 64 explicit entries, exactly two exclusions, and only the complete landing/documentation boundary marked implemented on web.
- Status cards, disabled download state, local documentation index, and visible runtime boundary copy.
- Categorized feature documentation and public project records.
- Adaptive Qt Quick phone shell, Material Design 3 tokens, and reusable controls.
- Transport-neutral C++17 PBX provider contract, deterministic simulator, and production CMake registration.
- Pinned dependency manifest, one-click build scripts, unsigned Squirrel.Windows packaging contract, and Windows build-and-release workflow.
- GitHub Pages deployment workflow.
- Complete removal of the inaccessible private feature-specification gitlink from the public source tree.
- Read-only generated-output freshness mode with a deliberate stale-output red/green proof.
- Pages staging that combines website and documentation, validates artifact contents, and uses immutable action SHAs.
- Narrow-drawer inert/hidden state, Escape handling, focus entry/return, stable tab IDs, and exact panel labels.
- Allowlisted/range-checked stored preferences with non-blocking read/write/reset refusal states.
- Cohesive warm-copper Material Design 3 visual language across the website and adaptive desktop shell, including expressive type, shaped surfaces, purposeful elevation, refined density, and complete interaction-state styling.
- Editorial website hero with an explicitly static call preview, product-principle indicators, responsive composition, and reduced-motion-safe ambient motion.
- Adaptive desktop navigation using the existing application icon sources, selected destination pills, elevated content framing, and preserved destination/model bridge wiring.

### Evidence boundary

- The website suite passes 12/12 through `node --test site/test-site.mjs`.
- The PBX provider suite passes 18/18 from a fresh native CMake/Ninja build.
- The Material Design 3 source contract passes through `cmake -P Linphone/view/Test/material-foundation-contract.cmake`.
- The delivery contract passes its positive checks and deliberate signing/private-input regressions.
- Both workflow files pass structural actionlint validation with shellcheck integration disabled on Windows.
- No browser capture or built desktop interaction is claimed.
- The visual-quality ultra-speed pass intentionally ran no tests, lint, accessibility automation, reviews, audits, or captures. Its changes require built-artifact verification before the corresponding roadmap items can be checked.
- Status Hub publishing was unavailable in this session.
- Windows dependency bootstrap now falls back to separately versioned and SHA-256-pinned canonical artifacts when `winget.exe` is absent or an install fails. Visual Studio Build Tools remains installer-managed and may instead reuse a compatible installed Visual Studio 2022 C++ toolchain; no portable distribution was falsely declared for it.
- Fallback artifact hashing uses the built-in .NET SHA-256 implementation, avoiding a bootstrap-time dependency on the unavailable `Get-FileHash` command observed after the local winget failure. A real silent bootstrap then verified and resolved the Git fallback and advanced into CMake bootstrap; it was intentionally stopped there to avoid downloading the remaining toolchain.
- The bootstrap repair was source-reasoned from GitHub Actions run `32570779505` and the local non-elevated installer failure (`-1978335226`). No tests, lint, static analysis, audits, reviews, captures, or full toolchain download were run in the ultra-speed pass.
- The feature inventory therefore keeps Status Hub `planned`; local cards are not presented as Hub implementation.
- No verified Material Phone installer or immutable release manifest exists, so the download action remains disabled.
- The canonical Open Graph URL exists, but a product-specific image and anonymous deployed-byte verification remain open.

### Next owner actions

1. Complete adversarial correctness, security, delivery, and accessibility review of the integrated baseline.
2. Push `main`, monitor both GitHub workflows, and record exact release/deployment evidence.
3. Run the approved hidden interaction route against the built website and desktop artifact at supported widths.
4. Publish and validate an immutable release manifest before enabling any installer link.
5. Implement non-excluded inventory rows in bounded batches, keeping status labels evidence-driven.
6. Confirm the Pages workflow in the hosted environment and record its artifact and deployment outcome without treating local staging as remote proof.
