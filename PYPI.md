# PyPI / pip Distribution

FolderSorter can be installed through `pip` as a cross-platform command line
tool. The pip package is implemented in Python and does not require Swift,
Xcode, or Xcode Command Line Tools.

## Install From GitHub

This works before the package is published to PyPI:

```bash
python3 -m pip install "git+https://github.com/kodlbegiko/FolderSorter.git"
foldersorter --help
```

## Install From PyPI

After the `foldersorter` package is published:

```bash
python3 -m pip install foldersorter
foldersorter --help
```

## Requirements

- Python 3.9 or newer
- macOS, Windows, or Linux

## Build The Python Package Locally

```bash
python3 -m pip install --upgrade build
python3 -m build
```

The generated wheel and source distribution are written to:

```text
dist/
```

## Publish To PyPI

Publishing requires a PyPI account and either a trusted publishing setup or an
API token.

The recommended path is PyPI Trusted Publishing. It lets GitHub Actions publish
without storing a long-lived PyPI API token in the repository.

Create a pending publisher on PyPI with these values:

```text
PyPI project name: foldersorter
Owner: kodlbegiko
Repository name: FolderSorter
Workflow filename: publish-pypi.yml
```

Then publish a GitHub Release or manually run the `Publish PyPI` workflow.

The workflow builds `dist/`, checks it with `twine`, and publishes through:

```text
pypa/gh-action-pypi-publish@release/v1
```

Manual token upload is still possible if you prefer it:

```bash
python3 -m pip install --upgrade twine
python3 -m twine upload dist/*
```

## Notes

- The pip package exposes the cross-platform CLI, not the SwiftUI app bundle.
- The SwiftUI app remains available from GitHub Releases for macOS users.
- Set `FOLDERSORTER_TRANSACTION_DIR=/custom/path` to choose a custom undo ledger directory.
