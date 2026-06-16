# Discoverability Plan / 專案曝光計畫

FolderSorter should speak to the biggest audience first: everyday Mac users with
messy Downloads, Desktop, screenshots, PDFs, ZIPs, DMGs, images, and videos.
The technical angle still matters, but it should support the main promise:
preview before sorting, undo after sorting, and no cloud upload.

FolderSorter 的最大客群是一般 Mac 使用者，不只是工程師。對外溝通時先講
「Downloads、桌面、截圖太亂」這個痛點，再補上安全預覽、可復原、本機優先、
開源與 CLI。

## GitHub Checklist

- Keep `README.md` bilingual, with English first and Traditional Chinese visible.
- Keep standalone docs for each audience: `README.en.md` and `README.zh-TW.md`.
- Keep the next product priorities visible in `ROADMAP.md` and `ROADMAP.zh-TW.md`.
- Show the real UI near the top of the README: `Media/foldersorter-ui.png`.
- Use `Media/foldersorter-social-preview.jpg` in GitHub Settings as the social preview image.
- Keep repository topics focused on search intent: `macos`, `swift`, `swiftui`,
  `file-organizer`, `downloads-folder`, `screenshot-organizer`,
  `file-management`, `productivity`, `local-first`, `cli`.
- Create GitHub Releases once a signed or zipped app build is ready.
- Publish the `foldersorter` package to PyPI after the GitHub pip install path is tested.

## Product Proof Points Before Wider Launch

These are the highest-impact product improvements before pushing harder on
Reddit, Hacker News, Product Hunt, and Mac communities:

- Downloadable `.zip` / `.dmg` release so non-developers can try the app.
- pip-installable CLI package for users who already use Python tooling.
- Stronger visual GUI rules for file size, created date, modified date,
  screenshot detection, duplicate detection, and broad file type groups.
- A before/after comparison view with the original folder on the left and the
  planned organized output on the right.

在更大力推 Reddit、Hacker News、Product Hunt、Mac 社群之前，最重要的產品
證明點是：

- 提供 `.zip` / `.dmg` 下載版，讓非工程師也能直接試用。
- 提供可透過 pip 安裝的 CLI package，服務已經習慣 Python 工具鏈的使用者。
- 強化 GUI 規則，加入檔案大小、建立日期、修改日期、截圖判斷、重複檔判斷、
  檔案大類型。
- 做整理前後對照：左邊原始混亂資料夾，右邊預計整理後的輸出結果。

## Launch Channels

- GitHub: pin the repository, add a short profile note, and ask early users to star it.
- Hacker News: post as `Show HN: FolderSorter - a preview-first macOS file organizer`.
- Reddit: share useful demos in macOS-focused communities where self-promotion is allowed.
- Product Hunt: launch when there is a downloadable build, demo GIF, and clear screenshots.
- Indie Hackers: write the build story and focus on the safety-first file cleanup angle.
- X, Threads, Mastodon, and LinkedIn: post a short before/after cleanup demo.
- Taiwan communities: share the Traditional Chinese README and bilingual UI angle.

## Release Assets

- `Media/foldersorter-ui.png`: README and issue discussions.
- `Media/foldersorter-social-preview.jpg`: GitHub Social preview and share cards.
- Future asset: 15-30 second demo video showing drag, preview, sort, undo.
- Future asset: animated GIF for README once the interaction flow is stable.

## Posting Copy

English:

```text
FolderSorter is an open-source macOS file organizer that previews every cleanup
before it touches your files. Drag in Downloads, Desktop, or any folder, review
where files will go, then sort or undo locally. Built with SwiftUI, with GUI,
CLI, JSON rules, and English / Traditional Chinese UI.
```

Traditional Chinese:

```text
FolderSorter 是一個開源 macOS 檔案整理器。你可以拖入 Downloads、桌面或
任何資料夾，先看整理預覽，確認後再分類；套用後也能復原。所有處理都在本機
完成，支援 GUI、CLI、JSON 規則、英文與繁體中文介面。
```

## Manual GitHub Social Preview Step

GitHub currently exposes social preview upload through the repository Settings UI.
Use this file:

```text
Media/foldersorter-social-preview.jpg
```

Suggested path in GitHub:

```text
Repository -> Settings -> Social preview -> Edit -> Upload an image
```

References:

- GitHub Docs: https://docs.github.com/articles/classifying-your-repository-with-topics
- GitHub Docs: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview
