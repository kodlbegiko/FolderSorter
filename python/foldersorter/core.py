from __future__ import annotations

import json
import os
import re
import shutil
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Literal

OperationMode = Literal["copy", "move"]
ConflictStrategy = Literal["rename", "skip", "replace"]


@dataclass
class ClassificationRule:
    extensions_text: str
    folder_name: str
    name_contains_text: str = ""
    id: str = field(default_factory=lambda: str(uuid.uuid4()))

    @property
    def normalized_extensions(self) -> list[str]:
        return [token.strip(".") for token in _tokenize(self.extensions_text) if token.strip(".")]

    @property
    def normalized_name_tokens(self) -> list[str]:
        return _tokenize(self.name_contains_text)

    @property
    def is_usable(self) -> bool:
        return bool(self.folder_name.strip()) and (
            bool(self.normalized_extensions) or bool(self.normalized_name_tokens)
        )

    def matches(self, path: Path) -> bool:
        file_extension = path.suffix.lower().removeprefix(".")
        lower_name = path.name.lower()
        extension_matches = not self.normalized_extensions or file_extension in self.normalized_extensions
        name_matches = not self.normalized_name_tokens or any(
            token in lower_name for token in self.normalized_name_tokens
        )
        return extension_matches and name_matches

    @classmethod
    def from_json(cls, value: dict[str, object]) -> "ClassificationRule":
        return cls(
            id=str(value.get("id") or uuid.uuid4()),
            extensions_text=str(value.get("extensionsText") or value.get("extensions_text") or ""),
            name_contains_text=str(value.get("nameContainsText") or value.get("name_contains_text") or ""),
            folder_name=str(value.get("folderName") or value.get("folder_name") or ""),
        )


@dataclass
class ClassificationOperation:
    source_path: str
    destination_path: str
    destination_folder_name: str
    matched_rule_id: str
    id: str = field(default_factory=lambda: str(uuid.uuid4()))


@dataclass
class ClassificationPlan:
    input_paths: list[str]
    output_root_path: str
    operation_mode: OperationMode
    includes_subfolders: bool
    conflict_strategy: ConflictStrategy
    scanned_files: int = 0
    matched_files: int = 0
    skipped_files: int = 0
    failed_files: int = 0
    operations: list[ClassificationOperation] = field(default_factory=list)
    messages: list[str] = field(default_factory=list)


@dataclass
class ClassificationReport:
    copied_files: int = 0
    moved_files: int = 0
    skipped_files: int = 0
    failed_files: int = 0
    messages: list[str] = field(default_factory=list)
    completed_operations: list[ClassificationOperation] = field(default_factory=list)


@dataclass
class UndoReport:
    restored_files: int = 0
    removed_files: int = 0
    skipped_files: int = 0
    failed_files: int = 0
    messages: list[str] = field(default_factory=list)


DEFAULT_RULES: list[ClassificationRule] = [
    ClassificationRule("png, jpg, jpeg", "Screenshots", "screenshot, 截圖"),
    ClassificationRule("mp4, mov, m4v, avi, mkv, webm", "Videos"),
    ClassificationRule("jpg, jpeg, png, gif, heic, webp, tiff, svg", "Images"),
    ClassificationRule("pdf, doc, docx, pages, txt, rtf, md, xls, xlsx, numbers, ppt, pptx, key", "Documents"),
    ClassificationRule("zip, rar, 7z, tar, gz, bz2, xz", "Archives"),
    ClassificationRule("dmg, pkg, app", "Installers"),
    ClassificationRule("mp3, wav, aiff, flac, m4a, aac", "Audio"),
    ClassificationRule("swift, py, js, ts, html, css, json, yaml, yml, sh", "Code"),
]


def load_rules(path: str | None) -> list[ClassificationRule]:
    if path is None:
        return DEFAULT_RULES

    with Path(path).expanduser().open("r", encoding="utf-8") as file:
        raw = json.load(file)

    if not isinstance(raw, list):
        raise ValueError("rules file must contain a JSON list")

    rules = [ClassificationRule.from_json(item) for item in raw if isinstance(item, dict)]
    usable = [rule for rule in rules if rule.is_usable]
    if not usable:
        raise ValueError("rules file has no usable rules")
    return usable


def make_plan(
    input_paths: Iterable[str],
    output_root: str,
    rules: list[ClassificationRule],
    operation_mode: OperationMode = "copy",
    includes_subfolders: bool = True,
    conflict_strategy: ConflictStrategy = "rename",
) -> ClassificationPlan:
    input_path_list = [str(Path(path).expanduser()) for path in input_paths]
    output_root_path = str(Path(output_root).expanduser())
    plan = ClassificationPlan(
        input_paths=input_path_list,
        output_root_path=output_root_path,
        operation_mode=operation_mode,
        includes_subfolders=includes_subfolders,
        conflict_strategy=conflict_strategy,
    )
    usable_rules = [rule for rule in rules if rule.is_usable]
    reserved_destinations: set[Path] = set()

    if not usable_rules:
        plan.failed_files += 1
        plan.messages.append("No usable sorting rules.")
        return plan

    for raw_input in input_path_list:
        input_path = Path(raw_input)
        if not input_path.exists():
            plan.failed_files += 1
            plan.messages.append(f"Input does not exist: {input_path}")
            continue

        if input_path.is_file():
            _plan_file(input_path, Path(output_root_path), usable_rules, conflict_strategy, reserved_destinations, plan)
            continue

        files = input_path.rglob("*") if includes_subfolders else input_path.iterdir()
        for file_path in files:
            if file_path.is_file():
                _plan_file(file_path, Path(output_root_path), usable_rules, conflict_strategy, reserved_destinations, plan)

    if not plan.operations and plan.failed_files == 0:
        plan.messages.append("No files matched the current rules.")

    return plan


def apply_plan(plan: ClassificationPlan) -> ClassificationReport:
    report = ClassificationReport()

    for operation in plan.operations:
        source = Path(operation.source_path)
        destination = Path(operation.destination_path)
        try:
            if not source.exists():
                report.failed_files += 1
                report.messages.append(f"Source is missing: {source}")
                continue

            destination.parent.mkdir(parents=True, exist_ok=True)
            if destination.exists() and plan.conflict_strategy == "replace":
                destination.unlink()

            if plan.operation_mode == "move":
                shutil.move(str(source), str(destination))
                report.moved_files += 1
            else:
                shutil.copy2(source, destination)
                report.copied_files += 1

            report.completed_operations.append(operation)
        except OSError as error:
            report.failed_files += 1
            report.messages.append(f"Could not process {source}: {error}")

    if report.completed_operations:
        save_transaction(plan.operation_mode, report.completed_operations)

    return report


def save_transaction(operation_mode: OperationMode, operations: list[ClassificationOperation]) -> Path:
    transaction_dir = _transaction_dir()
    transaction_dir.mkdir(parents=True, exist_ok=True)
    created_at = datetime.now(timezone.utc).isoformat()
    transaction = {
        "id": str(uuid.uuid4()),
        "createdAt": created_at,
        "operationMode": operation_mode,
        "operations": [asdict(operation) for operation in operations],
    }
    path = transaction_dir / f"{created_at.replace(':', '-')}-{transaction['id']}.json"
    path.write_text(json.dumps(transaction, indent=2, ensure_ascii=False), encoding="utf-8")
    return path


def undo_latest() -> UndoReport:
    transaction_dir = _transaction_dir()
    transactions = sorted(transaction_dir.glob("*.json")) if transaction_dir.exists() else []
    if not transactions:
        return UndoReport(messages=["No cleanup record to undo."])

    latest = transactions[-1]
    try:
        transaction = json.loads(latest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return UndoReport(failed_files=1, messages=[f"Could not read undo record: {error}"])

    report = undo_transaction(transaction)
    if report.failed_files == 0:
        try:
            latest.unlink()
        except OSError as error:
            report.messages.append(f"Could not remove undo record: {error}")
    return report


def undo_transaction(transaction: dict[str, object]) -> UndoReport:
    mode = transaction.get("operationMode")
    raw_operations = transaction.get("operations")
    report = UndoReport()

    if mode not in {"copy", "move"} or not isinstance(raw_operations, list):
        return UndoReport(failed_files=1, messages=["Undo record is invalid."])

    for item in reversed(raw_operations):
        if not isinstance(item, dict):
            report.skipped_files += 1
            continue

        source = Path(str(item.get("source_path") or item.get("sourcePath") or ""))
        destination = Path(str(item.get("destination_path") or item.get("destinationPath") or ""))

        try:
            if mode == "copy":
                if destination.exists():
                    destination.unlink()
                    report.removed_files += 1
                else:
                    report.skipped_files += 1
                continue

            if not destination.exists():
                report.skipped_files += 1
            elif source.exists():
                report.skipped_files += 1
                report.messages.append(f"Skipped restore because source already exists: {source}")
            else:
                source.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(destination), str(source))
                report.restored_files += 1
        except OSError as error:
            report.failed_files += 1
            report.messages.append(f"Could not undo {destination}: {error}")

    return report


def _plan_file(
    source: Path,
    output_root: Path,
    rules: list[ClassificationRule],
    conflict_strategy: ConflictStrategy,
    reserved_destinations: set[Path],
    plan: ClassificationPlan,
) -> None:
    plan.scanned_files += 1
    matched_rule = next((rule for rule in rules if rule.matches(source)), None)
    if matched_rule is None:
        plan.skipped_files += 1
        return

    plan.matched_files += 1
    folder_name = _safe_folder_name(matched_rule.folder_name)
    destination = output_root / folder_name / source.name
    resolved_destination = _resolve_conflict(destination, conflict_strategy, reserved_destinations)

    if resolved_destination is None:
        plan.skipped_files += 1
        return

    reserved_destinations.add(resolved_destination)
    plan.operations.append(
        ClassificationOperation(
            source_path=str(source),
            destination_path=str(resolved_destination),
            destination_folder_name=folder_name,
            matched_rule_id=matched_rule.id,
        )
    )


def _resolve_conflict(
    destination: Path,
    conflict_strategy: ConflictStrategy,
    reserved_destinations: set[Path],
) -> Path | None:
    has_conflict = destination.exists() or destination in reserved_destinations
    if not has_conflict:
        return destination

    if conflict_strategy == "skip":
        return None

    if conflict_strategy == "replace" and destination not in reserved_destinations:
        return destination

    stem = destination.stem
    suffix = destination.suffix
    parent = destination.parent
    counter = 2
    while True:
        candidate = parent / f"{stem} {counter}{suffix}"
        if not candidate.exists() and candidate not in reserved_destinations:
            return candidate
        counter += 1


def _tokenize(value: str) -> list[str]:
    return [token.strip().lower() for token in re.split(r"[,;|\s]+", value) if token.strip()]


def _safe_folder_name(value: str) -> str:
    cleaned = value.strip().replace("\\", "-").replace("/", "-")
    return cleaned or "Unsorted"


def _transaction_dir() -> Path:
    override = os.environ.get("FOLDERSORTER_TRANSACTION_DIR")
    if override:
        return Path(override).expanduser()

    if os.name == "nt":
        base = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local")
        return base / "FolderSorter" / "transactions"

    if os.uname().sysname == "Darwin":
        return Path.home() / "Library" / "Application Support" / "FolderSorter" / "transactions"

    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "foldersorter" / "transactions"
