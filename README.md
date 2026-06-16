# FolderSorter

FolderSorter is a safe, open-source macOS file organizer.

It is built for the common Mac problem: a messy Downloads folder, Desktop,
Screenshots pile, and random PDFs, ZIPs, DMGs, videos, and images. Unlike tools
that immediately move files, FolderSorter previews every operation first and can
undo the last cleanup.

![FolderSorter app icon](Assets/AppAvatar.png)

## Highlights

- **Preview-first cleanup**: drag files or folders in, inspect the plan, then apply.
- **One-click undo**: every applied cleanup writes a local transaction record.
- **Common Mac defaults**: Images, Videos, Documents, Archives, Installers, Audio, Code, and Screenshots.
- **Conflict control**: automatically rename, skip, or replace same-name files.
- **Rules you can read**: rules can be imported and exported as JSON.
- **GUI + CLI**: a simple Mac app for everyday use and a `foldersorter` CLI for automation.
- **Local-first privacy**: no uploads, no analytics, no network feature.

## Requirements

- macOS 14 or newer
- Xcode command line tools or Xcode with SwiftPM

## Run The App

```bash
./script/build_and_run.sh
```

The generated app bundle is written to:

```text
dist/FolderSorter.app
```

## Use The App

1. Open the app.
2. Choose an output folder, or use the default Desktop `C` folder.
3. Drag in a folder, click `Downloads`, click `Desktop`, or choose files manually.
4. Review the preview.
5. Click `Start Sorting` / `開始整理` only when the plan looks right.
6. Use `Undo` / `復原` to revert the latest cleanup.

The default mode is copy, so original files stay in place. Move mode is available
when you want a real cleanup.

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

FolderSorter is not trying to clone Hazel. The goal is a safer, simpler,
transparent organizer for the broadest Mac audience:

- easier than complex automation tools,
- safer than one-shot cleaners,
- more transparent than closed-source apps,
- more approachable than CLI-only organizers.

## License

MIT
