from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

from . import __version__


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)

    if args == ["--wrapper-version"]:
        print(__version__)
        return 0

    try:
        binary = _ensure_swift_cli()
    except RuntimeError as error:
        print(f"foldersorter: {error}", file=sys.stderr)
        return 2

    completed = subprocess.run([str(binary), *args])
    return completed.returncode


def _ensure_swift_cli() -> Path:
    swift = shutil.which("swift")
    if swift is None:
        raise RuntimeError(
            "Swift is required for the current pip package. Install Xcode Command Line Tools "
            "with `xcode-select --install`, then run foldersorter again."
        )

    project_dir = _cached_project_dir()
    binary = _release_binary_path(project_dir)

    if binary.exists() and os.environ.get("FOLDERSORTER_REBUILD") != "1":
        return binary

    _copy_swift_project(project_dir)

    print("foldersorter: building the Swift CLI for first use...", file=sys.stderr)
    try:
        subprocess.run(
            [swift, "build", "-c", "release", "--product", "foldersorter"],
            cwd=project_dir,
            check=True,
        )
    except subprocess.CalledProcessError as error:
        raise RuntimeError(
            "Swift failed to build the FolderSorter CLI. Make sure Xcode Command Line Tools "
            "are installed and working, then retry with `FOLDERSORTER_REBUILD=1 foldersorter --help`."
        ) from error

    if not binary.exists():
        raise RuntimeError(f"Swift build finished, but the CLI binary was not found at {binary}")

    return binary


def _cached_project_dir() -> Path:
    cache_root = os.environ.get("FOLDERSORTER_CACHE_DIR")
    if cache_root:
        root = Path(cache_root).expanduser()
    elif sys.platform == "darwin":
        root = Path.home() / "Library" / "Caches" / "FolderSorter" / "pip"
    else:
        root = Path.home() / ".cache" / "foldersorter" / "pip"

    return root / f"swift-project-{__version__}"


def _copy_swift_project(project_dir: Path) -> None:
    source = Path(__file__).resolve().parent / "swift_project"
    if not source.exists():
        raise RuntimeError(f"Bundled Swift project is missing: {source}")

    if project_dir.exists():
        shutil.rmtree(project_dir)

    project_dir.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, project_dir)


def _release_binary_path(project_dir: Path) -> Path:
    return project_dir / ".build" / "release" / "foldersorter"
