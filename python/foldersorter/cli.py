from __future__ import annotations

import argparse
import sys

from . import __version__
from .core import apply_plan, load_rules, make_plan, undo_latest


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.version:
        print(__version__)
        return 0

    if args.undo:
        report = undo_latest()
        _print_undo_report(report)
        return 0 if report.failed_files == 0 else 1

    if not args.input_paths:
        parser.error("at least one --input path is required")

    if not args.output_path:
        parser.error("--output is required")

    try:
        rules = load_rules(args.rules_path)
        plan = make_plan(
            input_paths=args.input_paths,
            output_root=args.output_path,
            rules=rules,
            operation_mode="move" if args.move else "copy",
            includes_subfolders=not args.no_recursive,
            conflict_strategy=args.conflict,
        )
    except (OSError, ValueError) as error:
        print(f"foldersorter: {error}", file=sys.stderr)
        return 2

    _print_plan(plan)

    if not args.apply:
        print("\nDry run only. Add --apply to move or copy files.")
        return 0 if plan.failed_files == 0 else 1

    report = apply_plan(plan)
    _print_report(report)
    return 0 if report.failed_files == 0 else 1


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="foldersorter",
        description="Preview-first cross-platform file organizer.",
    )
    parser.add_argument("-i", "--input", dest="input_paths", action="append", default=[], help="File or folder to sort. Repeat for multiple inputs.")
    parser.add_argument("-o", "--output", dest="output_path", help="Destination root folder.")
    parser.add_argument("--rules", dest="rules_path", help="JSON rules exported from the app.")
    parser.add_argument("--apply", action="store_true", help="Apply the preview. Default is dry-run.")
    parser.add_argument("--dry-run", action="store_false", dest="apply", help="Preview only.")
    parser.add_argument("--move", action="store_true", help="Move files instead of copying.")
    parser.add_argument("--copy", action="store_false", dest="move", help="Copy files. This is the default.")
    parser.add_argument("--conflict", choices=["rename", "skip", "replace"], default="rename", help="Conflict strategy. Default is rename.")
    parser.add_argument("--no-recursive", action="store_true", help="Do not scan subfolders.")
    parser.add_argument("--undo", action="store_true", help="Undo the latest applied cleanup.")
    parser.add_argument("--version", "--wrapper-version", action="store_true", help="Show the Python package version.")
    parser.set_defaults(apply=False, move=False)
    return parser


def _print_plan(plan) -> None:
    print("Preview")
    print(f"  scanned: {plan.scanned_files}")
    print(f"  matched: {plan.matched_files}")
    print(f"  planned: {len(plan.operations)}")
    print(f"  skipped: {plan.skipped_files}")
    print(f"  issues:  {plan.failed_files}")
    print(f"  mode:    {plan.operation_mode}")
    print(f"  conflict:{plan.conflict_strategy}")

    for operation in plan.operations:
        print(f"  {operation.source_path} -> {operation.destination_path}")

    for message in plan.messages:
        print(f"  info: {message}")


def _print_report(report) -> None:
    print("\nApplied")
    print(f"  copied:  {report.copied_files}")
    print(f"  moved:   {report.moved_files}")
    print(f"  skipped: {report.skipped_files}")
    print(f"  failed:  {report.failed_files}")

    for message in report.messages:
        print(f"  error: {message}")


def _print_undo_report(report) -> None:
    print("Undo")
    print(f"  restored: {report.restored_files}")
    print(f"  removed:  {report.removed_files}")
    print(f"  skipped:  {report.skipped_files}")
    print(f"  failed:   {report.failed_files}")

    for message in report.messages:
        print(f"  info: {message}")
