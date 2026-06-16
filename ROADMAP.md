# Roadmap

## Highest Impact Next Work

These items are prioritized because FolderSorter should win with everyday Mac
users first, not by becoming another expert-only automation tool.

### Downloadable Release

The biggest adoption blocker is that there is no downloadable `.dmg` or `.zip`
release yet. Most users will not run `swift build`, so the next public milestone
should provide a simple downloadable app bundle through GitHub Releases.

Deliverables:

- Build a reproducible release script for `FolderSorter.app`.
- Publish a zipped app build first, then add `.dmg` packaging.
- Document first-run macOS security expectations for unsigned builds.
- Move toward signing and notarization once the release flow is stable.

### Stronger Visual GUI Rules

The rules system should become more capable without forcing users to write YAML
or scripts. The GUI should stay visual and understandable.

Planned rule conditions:

- File size
- Created date
- Modified date
- Screenshot detection
- Duplicate detection
- Broad file type groups such as images, videos, documents, archives, installers, audio, and code

### Before / After Comparison

The preview should become more visual than a flat operation list. A before/after
view can make the cleanup plan obvious before any file is touched.

Planned experience:

- Left side: original messy folder structure.
- Right side: planned organized output structure.
- Highlight moved, copied, skipped, duplicate, and conflict items.
- Keep the final apply step explicit and undoable.

## V1

- Safe preview before moving or copying files
- One-click undo ledger
- GUI and CLI
- JSON rule import/export
- Conflict strategies: rename, skip, replace
- Default rules for common Mac clutter

## V1.1

- Signed release builds
- pip-installable CLI package
- Better duplicate detection with hashes
- More rule packs for students, creators, office workers, and developers
- Optional scheduled scans with preview-first confirmation

## V2

- Metadata rules for media duration, image size, and EXIF dates
- Optional OCR and local text extraction
- Rule suggestions from recent manual cleanups
- Plugin API for advanced local processors
