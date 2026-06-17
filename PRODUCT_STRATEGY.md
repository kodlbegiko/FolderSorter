# Product Strategy

FolderSorter should not try to win by having more automation features than
developer-first tools. It should win by making everyday Mac users comfortable
sorting real folders.

## Product Promise

FolderSorter is a native Mac, preview-first, undoable, local-first file organizer.
It helps users understand where every file will go, why it will go there, and how
to recover if the cleanup was not what they expected.

```text
FolderSorter should be the file organizer users feel safe pressing Apply on.
```

## Target User

The first audience is everyday Mac users with messy Downloads folders, crowded
Desktops, screenshot piles, PDFs, ZIPs, DMGs, videos, and images.

| Question | Product answer |
| --- | --- |
| What is this? | A tool for organizing Downloads, Desktop, screenshots, documents, media, and installers. |
| Will it change my files immediately? | No. It previews the cleanup first. |
| What if the cleanup is wrong? | The latest cleanup can be undone. |
| Will my files be uploaded? | No. Sorting is local-first. |
| Do I need to write rules? | No. Rules should be visual first, with import/export for advanced users. |

## Early Non-Goals

FolderSorter should not position the early product as:

- a Hazel replacement,
- an `organize` replacement,
- a full automation platform,
- a developer-only CLI tool,
- an AI file assistant.

The first wedge is people who want to clean up a messy Mac folder without fear.

## Trust Principles

### Preview Must Be Understandable

Before applying a cleanup, users should see:

| Item | Requirement |
| --- | --- |
| Source path | Where the file is now. |
| Destination path | Where the file will go. |
| Action | Copy, move, skip, or rename. |
| Matching reason | Why this file matched this category. |
| Conflict handling | What happens if a same-name file already exists. |
| Risk notes | Large operations, move mode, conflicts, unknown types, or permission issues. |

The product should not stop at a generic count such as `35 files will be sorted`.
It should explain the plan in human terms, including category counts,
unclassified files, and whether anything will be moved or deleted.

### Apply Needs Final Confirmation

The final Apply step should change its tone based on risk:

| Situation | Expected prompt |
| --- | --- |
| Copy mode | Low-risk confirmation. |
| Move mode | Clear warning that files will leave the source folder. |
| More than 100 files | Large operation warning. |
| Name conflicts | Show the selected conflict strategy. |
| Unclassified files | State that they will not be randomly moved. |

### Undo Is A Core Selling Point

Undo should be reliable enough to market directly:

| Standard | Target |
| --- | --- |
| Recovery scope | At least the latest Apply operation. |
| History visibility | Users can inspect what the latest cleanup changed. |
| Undo preview | Users can see what will be restored before undoing. |
| Failure handling | Failed restores show specific reasons. |
| Transaction record | Every Apply operation has a durable local record. |

### Do Not Lead With Delete

The early product should support copy, move, skip, and rename-on-conflict. It
should not make delete, trash, auto-clean, or purge flows a main feature.

## Core Experience

The preview screen is the product. It should feel like a cleanup proposal, not a
technical operation list.

| Layer | Purpose |
| --- | --- |
| Summary | Counts by category: images, documents, archives, installers, videos, unclassified. |
| Before / after | Side-by-side source and planned destination paths. |
| Reason | Explain the matching rule for each file. |
| Exceptions and risks | Surface unclassified files, conflicts, permission failures, locked files, and missing folders. |

After reading the preview, the user should know what FolderSorter will do and why
it will not act recklessly.

## Rules Strategy

Rules should be simple without being shallow.

| Level | Capability | Product expectation |
| --- | --- | --- |
| Level 1 | Extension, filename contains, broad file type, destination folder | Stable default sorting for common Mac clutter. |
| Level 2 | Created date, modified date, file size, source folder, screenshot detection, installer detection | Visual GUI rules without requiring JSON or YAML. |
| Level 3 | EXIF dates, PDF text, duplicate detection, smart suggestions, rule packs | Future capabilities after the trust-first experience is mature. |

Advanced users can still import and export JSON rules, but the default product
experience should not require users to write JSON or YAML.

## First-Run Experience

The first session should get the user from clutter to preview within one minute.

| Mode | Purpose |
| --- | --- |
| Organize Downloads | Most common cleanup case. |
| Organize Desktop | Common visual clutter case. |
| Custom folder | Advanced or specific folder cleanup. |

| Safety level | Meaning |
| --- | --- |
| Safest | Copy files only, leave originals untouched. |
| Standard | Move files, but keep undo available. |
| Advanced | Let users customize rules and conflict handling. |

## Quality Bar

FolderSorter touches local files, so the quality bar is higher than ordinary
utilities.

- Never overwrite files unexpectedly.
- Never move files without a transaction record.
- Never leave interrupted Apply operations ambiguous.
- Never lose the latest undo record.
- Always preserve same-name files through skip, rename, or explicit replace.
- Explain permission and file-access failures in human language.
- Show a completion report with successful, skipped, failed, created-folder, and undoable counts.

## Maturity Model

| Level | Meaning |
| --- | --- |
| Level 1: Usable tool | Users can safely organize Downloads with folder selection, preview, copy, move, undo, default categories, local processing, and non-destructive conflict handling. |
| Level 2: Trusted tool | Users trust it on real folders because preview, Apply, Undo, errors, transactions, installation, signing, and GUI rule editing are clear. |
| Level 3: Useful product | Users return regularly because it has rule templates, date and size conditions, screenshot detection, large-file cleanup, saved settings, bilingual UI, and polished native design. |
| Level 4: Growing platform | Future smart suggestions, duplicate detection, local PDF analysis, EXIF sorting, shareable rule packs, plugins, and controlled scheduled runs. |

Level 4 is not the current focus.

## Differentiation From `organize`

`organize` is for people who are willing to write rules. FolderSorter is for
people who want to clean up a folder and understand the result before anything
happens.

| Dimension | FolderSorter target |
| --- | --- |
| Learning curve | No docs required for first cleanup. |
| Safety | More reassuring than CLI automation. |
| Visual preview | More intuitive than text simulation. |
| Undo | A core selling point. |
| General-user friendliness | Better than YAML-first tools. |
| macOS feel | Feels like a real Mac app. |
| Privacy | Clearly local-first, with no uploads or tracking. |

## Success Metrics

The product should be judged by trust, not feature count:

| Area | Metric |
| --- | --- |
| First-run success | User can reach a preview in under one minute. |
| Apply confidence | User understands the plan before applying it. |
| Undo clarity | User knows how to recover the latest cleanup. |
| Error calmness | Error messages do not make users think their files are damaged. |
| Repeat usage | User is willing to clean up weekly or monthly. |
| Conflict safety | Files are never overwritten unexpectedly. |
| Local trust | Users understand files are not uploaded. |
