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
- Narrow website layouts now use shrinkable grid and flex tracks plus track-relative hero decoration, navigation, actions, chips, and phone-preview sizing to prevent document-level horizontal panning from 320 CSS pixels upward; wide tables retain their intentional internal scrolling container.
- The mobile navigation drawer now keeps closed content inert and hidden from accessibility APIs, makes the background inert while open, supports close-button, outside-scrim, and Escape dismissal with focus return, and uses iPhone safe-area insets across navigation, top chrome, main content, overlays, and notifications.
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
- MSYS2 bootstrap now requires and imports its bundled official keyring material before signed database synchronization, maps Graphviz to `mingw-w64-x86_64-graphviz`, and starts a fresh non-interactive `pacman -Su` continuation after the initial database/runtime upgrade before installing the complete declared package set.
- A permitted silent bootstrap initialized the keyring, completed signed database synchronization and both runtime-upgrade phases, resolved `mingw-w64-x86_64-graphviz-15.1.0-1` in the declared package transaction, downloaded it, and reached package installation. The command was intentionally stopped there rather than completing the remaining 1.6 GiB toolchain installation.
- Keyring setup passes `/usr/bin/pacman-key` directly to the validated absolute bundled `bash.exe` for initialization and population, bypassing the script's `#!/usr/bin/env bash` lookup so the Windows WSL launcher cannot intercept the operation. Database, upgrade, and package transactions continue to invoke the validated absolute bundled `pacman.exe`.
- A permitted silent bootstrap confirmed no WSL launch: the bundled Bash completed keyring population and trust-database update, then the bundled pacman reached signed database synchronization. This warm local cache stopped on a package-database lock left by the previously interrupted installation; that local-state boundary is separate from command resolution.
- The pinned 53,555,380-byte MSYS2 fallback now has a 60,000,000-byte ceiling, a 30-minute total download timeout with 15-second byte heartbeats, a 5-minute extraction timeout with elapsed-time heartbeats through absolute Windows `tar.exe`, and a 60-second staging timeout with its own heartbeat. Each phase reports its exact start, completion, and timeout boundary.
- Build-only evidence exercised the cold fallback download through 9,273,204 bytes at 152 seconds with factual 15-second heartbeats, then used the preserved fully verified pinned archive to isolate later phases: SHA verification passed, extraction completed in 13 seconds, staging completed in 1 second, bundled `pacman.exe` resolved, and signed keyring/database/runtime-upgrade work advanced. The command was intentionally stopped during the remaining toolchain upgrade rather than treated as a complete bootstrap verdict.
- MinGit's exact 41,268,410-byte fallback now declares a 45,000,000-byte ceiling and a 900-second deadline. The bound is derived from a conservative 48 KiB/s floor plus 60 seconds of connection/setup margin; run `32600797746` sustained about 61.3 KiB/s and reached 37,682,590 bytes at the former 600-second deadline.
- CMake's exact 46,473,549-byte fallback now declares a 50,000,000-byte ceiling and a 1,020-second deadline. The bound rounds up `ceil(46,473,549 / 49,152) + 60 = 1,006` seconds to the next full minute; run `32601481987` reached 37,696,026 bytes at the former 600-second deadline after MinGit completed and verified at 633 seconds.
- MSYS2 extraction uses `RUNNER_TEMP` only when it exists on the same volume as the final tool root, keeping the final stage a directory move while avoiding thousands of transient writes under the checked-out workspace. Its exact manifest deadline is now a finite 1,200 seconds with the existing 15-second extraction heartbeats; run `32602638537` proved the pinned archive and SHA before the former 300-second extraction timeout, while the identical archive extracted locally in 13 seconds.
- A cached-archive build proof selected a same-volume temporary directory, reverified all 53,555,380 pinned bytes, extracted there in 15 seconds, staged the single root in 1 second, and resolved the bundled `pacman.exe`. The command was intentionally stopped during subsequent keyring/database work rather than treated as a complete bootstrap verdict.
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
