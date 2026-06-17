# FolderSorter - Safe macOS File Organizer

[Bilingual README](README.md) | [English](README.en.md) | [繁體中文](README.zh-TW.md)

**Open-source, local-first macOS file organizer and Downloads cleaner with safe
preview, undo, visual rules, a SwiftUI GUI, and a cross-platform Python CLI.**

[![Latest GitHub Release](https://img.shields.io/github/v/release/kodlbegiko/FolderSorter?label=macOS%20download)](https://github.com/kodlbegiko/FolderSorter/releases/latest)
[![PyPI Version](https://img.shields.io/pypi/v/foldersorter?label=pip%20install)](https://pypi.org/project/foldersorter/)
[![CI](https://github.com/kodlbegiko/FolderSorter/actions/workflows/ci.yml/badge.svg)](https://github.com/kodlbegiko/FolderSorter/actions/workflows/ci.yml)
[![MIT License](https://img.shields.io/github/license/kodlbegiko/FolderSorter)](LICENSE)

It is built for the common Mac problem: a messy Downloads folder, Desktop,
Screenshots pile, and random PDFs, ZIPs, DMGs, videos, and images. Unlike tools
that immediately move files, FolderSorter previews every operation first and can
undo the last cleanup.

The goal is not to be the most powerful automation tool; it is to be the file
organizer users feel safe pressing Apply on.

<p align="center">
  <img src="Assets/AppAvatar.png" alt="FolderSorter macOS file organizer app icon" width="96">
</p>

<p align="center">
  <img src="Media/foldersorter-ui.png" alt="FolderSorter macOS Downloads folder organizer preview and rules interface" width="900">
</p>

[Launch and discoverability plan](DISCOVERABILITY.md) |
[Product strategy](PRODUCT_STRATEGY.md) |
[Roadmap](ROADMAP.md) |
[pip distribution](PYPI.md) |
[Changelog](CHANGELOG.md) |
[GitHub social preview asset](Media/foldersorter-social-preview.jpg)

## macOS File Organizer Features

- **Downloads and Desktop cleanup**: organize screenshots, PDFs, archives, installers, photos, videos, and code.
- **Preview-first cleanup**: drag files or folders in, inspect the plan, then apply.
- **One-click undo**: every applied cleanup writes a local transaction record.
- **Common Mac defaults**: Images, Videos, Documents, Archives, Installers, Audio, Code, and Screenshots.
- **Conflict control**: automatically rename, skip, or replace same-name files.
- **Rules you can read**: rules can be imported and exported as JSON.
- **GUI + CLI**: a simple Mac app for everyday use and a pure Python `foldersorter` CLI for automation.
- **Bilingual interface**: follow system language, English, or Traditional Chinese.
- **Local-first privacy**: no uploads, no analytics, no network feature.

## Common macOS File Organization Use Cases

- **Downloads folder organizer**: sort JPG, PNG, PDF, ZIP, RAR, 7z, DMG, PKG, MP4, and MOV files into clear folders.
- **Desktop and screenshot organizer**: separate screenshots from other images without deleting originals.
- **Photo, video, and document sorter**: route common media and office files with readable visual rules.
- **Safe folder cleanup**: preview every copy or move, handle filename conflicts, and undo the latest cleanup.

## Requirements

- Downloaded Mac app: macOS 14 or newer
- Building from source: Xcode Command Line Tools or Xcode with SwiftPM

## Download The Mac App

Download `FolderSorter-0.2.0.dmg` from the
[latest GitHub release](https://github.com/kodlbegiko/FolderSorter/releases/latest).

The current macOS app build is unsigned. On first launch, macOS may require
right-clicking the app and choosing `Open`.

## Run The App

```bash
./script/build_and_run.sh
```

The generated app bundle is written to:

```text
dist/FolderSorter.app
```

## Install The Cross-Platform CLI With pip

```bash
python3 -m pip install foldersorter
foldersorter --help
```

The pip package is implemented in Python and works on macOS, Windows, and Linux.
It does not require Swift, Xcode, or Xcode Command Line Tools.

## Use The App

1. Open the app.
2. Choose an output folder, or use the default Desktop `C` folder.
3. Drag in a folder, click `Downloads`, click `Desktop`, or choose files manually.
4. Review the preview.
5. Click `Start Sorting` / `開始整理` only when the plan looks right.
6. Use `Undo` / `復原` to revert the latest cleanup.

The default mode is copy, so original files stay in place. Move mode is available
when you want a real cleanup.

The app includes a language picker with `System`, `English`, and `繁體中文`.

## CLI

Preview only:

```bash
swift run foldersorter --input ~/Downloads --output ~/Desktop/C
```

Apply the preview:

```bash
swift run foldersorter --input ~/Downloads --output ~/Desktop/C --apply
```

Move instead of copy:

```bash
swift run foldersorter --input ~/Downloads --output ~/Desktop/C --move --apply
```

Use exported or example rules:

```bash
swift run foldersorter \
  --input ~/Downloads \
  --output ~/Desktop/C \
  --rules Examples/general-mac-cleanup.rules.json
```

Undo the latest applied cleanup:

```bash
swift run foldersorter --undo
```

## Rule Format

Rules are evaluated in order. A rule matches when all filled conditions match.
For example, the screenshot rule checks both file extension and filename tokens:

```json
{
  "extensionsText": "png, jpg, jpeg",
  "nameContainsText": "screenshot, 截圖",
  "folderName": "Screenshots"
}
```

## Development

Run tests:

```bash
swift test
```

Build all products:

```bash
swift build
```

Generate app icons:

```bash
swift script/generate_icon.swift
```

## Project Positioning

FolderSorter is not trying to clone Hazel or `organize`. The goal is a safer,
simpler, transparent organizer for the broadest Mac audience:

- easier than complex automation tools,
- safer than one-shot cleaners,
- more transparent than closed-source apps,
- more approachable than CLI-only organizers.

The product strategy is documented in [PRODUCT_STRATEGY.md](PRODUCT_STRATEGY.md).

## Next Priorities

- **Trust-first preview**: show category summary, before / after paths, matching reasons, and risk notes before Apply.
- **Undo and cleanup reports**: make the latest transaction inspectable, previewable, and easy to restore.
- **Signed release**: the GitHub release now includes `.zip` and `.dmg`; the next packaging step is signing and notarization.
- **Stronger GUI rules**: add visual conditions for file size, dates, screenshots, duplicates, and broad file types.

## Help This Project Grow

FolderSorter is positioned as a macOS Downloads cleaner, screenshot organizer,
and local-first file management utility for non-technical Mac users first, while
still keeping CLI and JSON rules for power users.

- Star or share the repository if the preview-first workflow solves a real cleanup problem.
- Use the included UI screenshot when writing posts or issue discussions.
- Use `Media/foldersorter-social-preview.jpg` as the GitHub social preview image.
- See `DISCOVERABILITY.md` for the launch checklist and posting copy.

## License

MIT
