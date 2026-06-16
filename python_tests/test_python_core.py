import os
import tempfile
import unittest
from pathlib import Path

from foldersorter.core import DEFAULT_RULES, apply_plan, make_plan, undo_latest


class PythonCoreTests(unittest.TestCase):
    def test_plan_preview_does_not_copy_files(self):
        with tempfile.TemporaryDirectory() as raw_root:
            root = Path(raw_root)
            source = root / "input"
            output = root / "output"
            source.mkdir()
            (source / "photo.jpg").write_text("image", encoding="utf-8")

            plan = make_plan([str(source)], str(output), DEFAULT_RULES)

            self.assertEqual(plan.scanned_files, 1)
            self.assertEqual(plan.matched_files, 1)
            self.assertEqual(len(plan.operations), 1)
            self.assertFalse((output / "Images" / "photo.jpg").exists())

    def test_default_rules_classify_common_files(self):
        with tempfile.TemporaryDirectory() as raw_root:
            root = Path(raw_root)
            source = root / "input"
            output = root / "output"
            source.mkdir()
            (source / "photo.jpg").write_text("image", encoding="utf-8")
            (source / "clip.mp4").write_text("video", encoding="utf-8")

            plan = make_plan([str(source)], str(output), DEFAULT_RULES)
            destinations = {Path(operation.destination_path).parent.name for operation in plan.operations}

            self.assertEqual(destinations, {"Images", "Videos"})

    def test_copy_apply_and_undo(self):
        with tempfile.TemporaryDirectory() as raw_root:
            root = Path(raw_root)
            transaction_dir = root / "transactions"
            os.environ["FOLDERSORTER_TRANSACTION_DIR"] = str(transaction_dir)
            self.addCleanup(os.environ.pop, "FOLDERSORTER_TRANSACTION_DIR", None)

            source = root / "input"
            output = root / "output"
            source.mkdir()
            original = source / "photo.jpg"
            original.write_text("image", encoding="utf-8")

            plan = make_plan([str(source)], str(output), DEFAULT_RULES, operation_mode="copy")
            report = apply_plan(plan)

            copied = output / "Images" / "photo.jpg"
            self.assertEqual(report.copied_files, 1)
            self.assertTrue(original.exists())
            self.assertTrue(copied.exists())

            undo = undo_latest()
            self.assertEqual(undo.removed_files, 1)
            self.assertTrue(original.exists())
            self.assertFalse(copied.exists())

    def test_move_apply_and_undo(self):
        with tempfile.TemporaryDirectory() as raw_root:
            root = Path(raw_root)
            transaction_dir = root / "transactions"
            os.environ["FOLDERSORTER_TRANSACTION_DIR"] = str(transaction_dir)
            self.addCleanup(os.environ.pop, "FOLDERSORTER_TRANSACTION_DIR", None)

            source = root / "input"
            output = root / "output"
            source.mkdir()
            original = source / "clip.mp4"
            original.write_text("video", encoding="utf-8")

            plan = make_plan([str(source)], str(output), DEFAULT_RULES, operation_mode="move")
            report = apply_plan(plan)

            moved = output / "Videos" / "clip.mp4"
            self.assertEqual(report.moved_files, 1)
            self.assertFalse(original.exists())
            self.assertTrue(moved.exists())

            undo = undo_latest()
            self.assertEqual(undo.restored_files, 1)
            self.assertTrue(original.exists())
            self.assertFalse(moved.exists())

    def test_rename_conflict_strategy_reserves_destinations(self):
        with tempfile.TemporaryDirectory() as raw_root:
            root = Path(raw_root)
            first = root / "a"
            second = root / "b"
            output = root / "output"
            first.mkdir()
            second.mkdir()
            (first / "photo.jpg").write_text("first", encoding="utf-8")
            (second / "photo.jpg").write_text("second", encoding="utf-8")

            plan = make_plan([str(first), str(second)], str(output), DEFAULT_RULES)
            names = sorted(Path(operation.destination_path).name for operation in plan.operations)

            self.assertEqual(names, ["photo 2.jpg", "photo.jpg"])


if __name__ == "__main__":
    unittest.main()
