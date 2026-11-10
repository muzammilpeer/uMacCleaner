# uMacCleaner

A native macOS cleanup app and command line tool. Sprint 1 scans the current user's caches, logs, and Xcode DerivedData, then moves selected top-level items to Trash.

The GUI also supports name/path filtering, size/name/category sorting, select/deselect visible items, and scanning a chosen folder or external volume. Chosen folders are treated as user data, not automatically classified as junk. The System Data trace lists likely contributors, with Finder links and a review path for caches, logs, and Derived Data. Its totals are estimates and can overlap; it cannot exactly reproduce macOS Storage's System Data number.

## Run

- GUI: `swift run MacCleaner`
- App bundle: `zsh scripts/build-app.sh`, then open `dist/uMacCleaner.app`
- CLI preview: `swift run mclean scan`
- CLI JSON: `swift run mclean scan --json`
- CLI System Data trace: `swift run mclean trace`
- Docker disk usage: `swift run mclean docker`
- Docker build cache cleanup: `swift run mclean docker-prune-build --yes`
- CLI cleanup: `swift run mclean clean --yes --category logs`
- Tests: `swift test`

The app requires macOS 14 or later. macOS may ask for file access. Close active apps before removing their caches; some files will be recreated. Trash can be emptied later in Finder.

## CI and releases

GitHub Actions runs tests and builds both binaries on pushes to `main`, pull requests, and manual runs. Each successful run offers a downloadable macOS arm64 artifact. Pushing a version tag such as `v0.1.0` also creates a GitHub Release with the app ZIP, CLI ZIP, and SHA-256 checksums attached.

The app is ad hoc signed for packaging but is **not notarized**. macOS Gatekeeper may require users to approve opening a downloaded build. A public release should later use an Apple Developer ID certificate and notarization.

Docker diagnostics use Docker's CLI to report images, containers, local volumes, and build cache. The only Docker cleanup action prunes build cache after confirmation; it does not delete volumes or Docker's disk image. The Apple Intelligence page points to supported macOS settings. It does not delete protected model assets or use private system changes.

## Sprints

1. **Foundation — implemented:** shared scanner, reviewable SwiftUI list, explicit Trash action, CLI scan/clean, path safety tests.
2. **Better discovery:** browser and app-specific rules, stale-file detection, exclusions, and category descriptions.
3. **Pro workflow:** saved presets, scheduled scans, CLI filters, per-item details, and exportable reports.
4. **Broader utilities:** large/duplicate file discovery, uninstall review, and maintenance actions with per-action confirmation.
5. **Release:** accessibility and permission handling, signed/notarized builds, onboarding, and performance work.

The scope of each later feature needs its own safety rules. System-protected areas and automatic permanent deletion are outside the current implementation.
