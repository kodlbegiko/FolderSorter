# Roadmap

FolderSorter's roadmap is guided by the product strategy in
[PRODUCT_STRATEGY.md](PRODUCT_STRATEGY.md): the goal is not to become the most
powerful automation tool, but to become the file organizer everyday Mac users
feel safe pressing Apply on.

## Highest Impact Next Work

These items are prioritized because FolderSorter should win with trust,
understandability, and recoverability before it expands into deeper automation.

### 1. Trust-First Preview And Apply Flow

The preview should become the core product surface. Users should understand the
cleanup before any file is touched.

Deliverables:

- Summary counts by category: images, documents, archives, installers, videos, and unclassified files.
- Before / after view showing source path and planned destination path.
- Matching reason for each file, such as extension, filename keyword, or broad file type.
- Risk notes for move mode, large batches, conflicts, unknown types, and permission problems.
- Final Apply confirmation that changes tone for copy, move, 100+ files, conflicts, and unclassified files.

### 2. Undo And Cleanup Reports

Undo should be reliable enough to be a main selling point, not just a safety
button.

Deliverables:

- Completion report with success, skipped, failed, created-folder, and undoable counts.
- Inspectable latest transaction record.
- Undo preview before restoring files.
- Human-readable failure messages when restore is not possible.
- Stronger interrupted-Apply handling so transaction state is never ambiguous.

### 3. Distribution Trust

FolderSorter already has downloadable `.zip` and `.dmg` assets. The next release
trust step is reducing macOS security friction.

Deliverables:

- Keep the reproducible `.app`, `.zip`, and `.dmg` release scripts working.
- Document first-run expectations for unsigned builds.
- Add Apple Developer signing.
- Add notarization and stapling.
- Re-test the install path on a clean Mac user profile.

### 4. Stronger Visual GUI Rules

Rules should become more capable without requiring users to write YAML, JSON, or
scripts.

Planned rule conditions:

- File size
- Created date
- Modified date
- Source folder
- Screenshot detection
- Duplicate detection
- Broad file type groups such as images, videos, documents, archives, installers, audio, and code

### 5. First-Run Onboarding

The first session should get a user from clutter to preview in under one minute.

Planned experience:

- Start with three entry points: Downloads, Desktop, and custom folder.
- Offer safety levels: safest copy-only mode, standard move-with-undo mode, and advanced custom mode.
- Keep the first cleanup path free of rule syntax and technical settings.

## Maturity Levels

### Level 1: Usable Tool

- Safe preview before moving or copying files
- One-click undo ledger
- GUI and CLI
- JSON rule import/export
- Conflict strategies: rename, skip, replace
- Default rules for common Mac clutter
- Local-first processing

### Level 2: Trusted Tool

- Clear before / after preview
- Apply report
- Undo report and undo preview
- Human-readable errors
- Stable transaction history
- Installable Mac app
- Signed and notarized builds
- GUI rule editing
- Beginner mode

### Level 3: Useful Product

- Rule templates for students, office workers, creators, and developers
- Date and size rule conditions
- Screenshot detection
- Large-file cleanup
- Multi-folder cleanup
- Matching reasons visible per file
- Saved settings
- Complete English and Traditional Chinese UI
- Polished native Mac app feel

### Level 4: Growing Platform

These are future directions, not the current focus:

- Smart rule suggestions from folder contents
- Duplicate detection with safe preview
- Local PDF text classification
- EXIF-based photo sorting
- Shareable rule packs
- Plugin API for advanced local processors
- Controlled scheduled runs with preview-first confirmation
