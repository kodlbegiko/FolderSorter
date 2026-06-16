import XCTest
@testable import FolderSorterCore

final class ClassificationEngineTests: XCTestCase {
    func testDefaultRulesClassifyCommonMacClutter() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let inputA = root.appendingPathComponent("a", isDirectory: true)
        let inputB = root.appendingPathComponent("b", isDirectory: true)
        let output = root.appendingPathComponent("c", isDirectory: true)
        try FileManager.default.createDirectory(at: inputA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inputB, withIntermediateDirectories: true)
        try "video".write(to: inputA.appendingPathComponent("clip.MP4"), atomically: true, encoding: .utf8)
        try "photo".write(to: inputB.appendingPathComponent("cover.JPG"), atomically: true, encoding: .utf8)
        try "note".write(to: inputB.appendingPathComponent("note.txt"), atomically: true, encoding: .utf8)

        let report = ClassificationEngine.run(job: ClassificationJob(
            inputURLs: [inputA, inputB],
            outputRoot: output,
            rules: ClassificationRule.defaultRules,
            operationMode: .copy,
            includesSubfolders: true
        ))

        XCTAssertEqual(report.scannedFiles, 3)
        XCTAssertEqual(report.matchedFiles, 3)
        XCTAssertEqual(report.copiedFiles, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.appendingPathComponent("Videos/clip.MP4").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.appendingPathComponent("Images/cover.JPG").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.appendingPathComponent("Documents/note.txt").path))
    }

    func testPlanPreviewDoesNotMoveFiles() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let input = root.appendingPathComponent("a", isDirectory: true)
        let output = root.appendingPathComponent("c", isDirectory: true)
        let source = input.appendingPathComponent("clip.mp4")
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        try "video".write(to: source, atomically: true, encoding: .utf8)

        let plan = ClassificationEngine.makePlan(job: ClassificationJob(
            inputURLs: [input],
            outputRoot: output,
            rules: [ClassificationRule(extensionsText: "mp4", folderName: "Videos")],
            operationMode: .move,
            includesSubfolders: true
        ))

        XCTAssertEqual(plan.operations.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.appendingPathComponent("Videos/clip.mp4").path))
    }

    func testCreatesUniqueFileNamesWhenInputsCollide() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let inputA = root.appendingPathComponent("a", isDirectory: true)
        let inputB = root.appendingPathComponent("b", isDirectory: true)
        let output = root.appendingPathComponent("c", isDirectory: true)
        try FileManager.default.createDirectory(at: inputA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inputB, withIntermediateDirectories: true)
        try "first".write(to: inputA.appendingPathComponent("same.jpg"), atomically: true, encoding: .utf8)
        try "second".write(to: inputB.appendingPathComponent("same.jpg"), atomically: true, encoding: .utf8)

        let report = ClassificationEngine.run(job: ClassificationJob(
            inputURLs: [inputA, inputB],
            outputRoot: output,
            rules: [ClassificationRule(extensionsText: "jpg", folderName: "Images")],
            operationMode: .copy,
            includesSubfolders: true
        ))

        XCTAssertEqual(report.copiedFiles, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.appendingPathComponent("Images/same.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.appendingPathComponent("Images/same 2.jpg").path))
    }

    func testSkipConflictStrategyDoesNotOverwriteExistingFiles() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let input = root.appendingPathComponent("a", isDirectory: true)
        let output = root.appendingPathComponent("c", isDirectory: true)
        let existing = output.appendingPathComponent("Images/same.jpg")
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: existing.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "incoming".write(to: input.appendingPathComponent("same.jpg"), atomically: true, encoding: .utf8)
        try "existing".write(to: existing, atomically: true, encoding: .utf8)

        let plan = ClassificationEngine.makePlan(job: ClassificationJob(
            inputURLs: [input],
            outputRoot: output,
            rules: [ClassificationRule(extensionsText: "jpg", folderName: "Images")],
            operationMode: .copy,
            includesSubfolders: true,
            conflictStrategy: .skip
        ))

        XCTAssertEqual(plan.operations.count, 0)
        XCTAssertEqual(plan.skippedFiles, 1)
        XCTAssertEqual(try String(contentsOf: existing), "existing")
    }

    func testNameContainsRuleRoutesScreenshotsBeforeGenericImages() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let input = root.appendingPathComponent("a", isDirectory: true)
        let output = root.appendingPathComponent("c", isDirectory: true)
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        try "image".write(to: input.appendingPathComponent("Screenshot 2026-06-16.png"), atomically: true, encoding: .utf8)

        let report = ClassificationEngine.run(job: ClassificationJob(
            inputURLs: [input],
            outputRoot: output,
            rules: ClassificationRule.defaultRules,
            operationMode: .copy,
            includesSubfolders: true
        ))

        XCTAssertEqual(report.copiedFiles, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.appendingPathComponent("Screenshots/Screenshot 2026-06-16.png").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.appendingPathComponent("Images/Screenshot 2026-06-16.png").path))
    }

    func testUndoRestoresMovedFiles() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let input = root.appendingPathComponent("a", isDirectory: true)
        let output = root.appendingPathComponent("c", isDirectory: true)
        let source = input.appendingPathComponent("clip.mp4")
        let destination = output.appendingPathComponent("Videos/clip.mp4")
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        try "video".write(to: source, atomically: true, encoding: .utf8)

        let report = ClassificationEngine.run(job: ClassificationJob(
            inputURLs: [input],
            outputRoot: output,
            rules: [ClassificationRule(extensionsText: "mp4", folderName: "Videos")],
            operationMode: .move,
            includesSubfolders: true
        ))

        XCTAssertEqual(report.movedFiles, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))

        let transaction = try XCTUnwrap(report.transaction)
        let undoReport = TransactionStore(directoryURL: root.appendingPathComponent("transactions")).undo(transaction)

        XCTAssertEqual(undoReport.restoredFiles, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testUndoRemovesCopiedFiles() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let input = root.appendingPathComponent("a", isDirectory: true)
        let output = root.appendingPathComponent("c", isDirectory: true)
        let source = input.appendingPathComponent("cover.jpg")
        let destination = output.appendingPathComponent("Images/cover.jpg")
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        try "photo".write(to: source, atomically: true, encoding: .utf8)

        let report = ClassificationEngine.run(job: ClassificationJob(
            inputURLs: [input],
            outputRoot: output,
            rules: [ClassificationRule(extensionsText: "jpg", folderName: "Images")],
            operationMode: .copy,
            includesSubfolders: true
        ))

        XCTAssertEqual(report.copiedFiles, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))

        let transaction = try XCTUnwrap(report.transaction)
        let undoReport = TransactionStore(directoryURL: root.appendingPathComponent("transactions")).undo(transaction)

        XCTAssertEqual(undoReport.removedFiles, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FolderSorterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
