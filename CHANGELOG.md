# Changelog

## v0.2.0

### Changed

- Replaced the pip package's Swift wrapper with a pure Python implementation.
- `pip install foldersorter` no longer requires Swift, Xcode, or Xcode Command Line Tools.
- The CLI is now intended to work on macOS, Windows, and Linux.

### Added

- Python core tests for preview, copy, move, undo, and conflict renaming.

## v0.1.0

Initial public release candidate for FolderSorter.

### Added

- Native macOS SwiftUI app for preview-first file sorting.
- `foldersorter` CLI with dry-run by default.
- Python wrapper package so users can install the CLI from GitHub with `pip`.
- PyPI Trusted Publishing workflow for publishing the `foldersorter` package.
- One-click undo ledger for the latest applied cleanup.
- JSON rule import and export.
- Default rules for screenshots, images, videos, documents, archives, installers, audio, and code.
- English and Traditional Chinese README files and in-app language support.
- UI screenshots and social preview assets for GitHub.

### Notes

- The macOS app zip is unsigned in this release candidate.
- The pip package currently exposes the CLI wrapper, not the SwiftUI app bundle.
- The first `foldersorter` CLI run from pip builds the Swift CLI locally and requires Xcode Command Line Tools.
