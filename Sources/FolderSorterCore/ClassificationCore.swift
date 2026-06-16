import Foundation

public struct ClassificationRule: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var extensionsText: String
    public var nameContainsText: String
    public var folderName: String

    public init(
        id: UUID = UUID(),
        extensionsText: String,
        nameContainsText: String = "",
        folderName: String
    ) {
        self.id = id
        self.extensionsText = extensionsText
        self.nameContainsText = nameContainsText
        self.folderName = folderName
    }

    public var normalizedExtensions: [String] {
        tokenize(extensionsText)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            .filter { !$0.isEmpty }
    }

    public var normalizedNameTokens: [String] {
        tokenize(nameContainsText)
    }

    public var isUsable: Bool {
        !folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!normalizedExtensions.isEmpty || !normalizedNameTokens.isEmpty)
    }

    public func matches(fileURL: URL) -> Bool {
        let fileExtension = fileURL.pathExtension.lowercased()
        let lowercasedName = fileURL.lastPathComponent.lowercased()

        let extensionMatches = normalizedExtensions.isEmpty || normalizedExtensions.contains(fileExtension)
        let nameMatches = normalizedNameTokens.isEmpty || normalizedNameTokens.contains { lowercasedName.contains($0) }

        return extensionMatches && nameMatches
    }

    public static let defaultRules: [ClassificationRule] = [
        ClassificationRule(extensionsText: "png, jpg, jpeg", nameContainsText: "screenshot, 截圖", folderName: "Screenshots"),
        ClassificationRule(extensionsText: "mp4, mov, m4v, avi, mkv, webm", folderName: "Videos"),
        ClassificationRule(extensionsText: "jpg, jpeg, png, gif, heic, webp, tiff, svg", folderName: "Images"),
        ClassificationRule(extensionsText: "pdf, doc, docx, pages, txt, rtf, md, xls, xlsx, numbers, ppt, pptx, key", folderName: "Documents"),
        ClassificationRule(extensionsText: "zip, rar, 7z, tar, gz, bz2, xz", folderName: "Archives"),
        ClassificationRule(extensionsText: "dmg, pkg, app", folderName: "Installers"),
        ClassificationRule(extensionsText: "mp3, wav, aiff, flac, m4a, aac", folderName: "Audio"),
        ClassificationRule(extensionsText: "swift, py, js, ts, html, css, json, yaml, yml, sh", folderName: "Code")
    ]

    private func tokenize(_ value: String) -> [String] {
        value
            .split { character in
                character == "," || character == ";" || character == "|" || character.isWhitespace
            }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
}

public enum OperationMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case copy
    case move

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .copy:
            return "複製"
        case .move:
            return "移動"
        }
    }

    public var completedTitle: String {
        switch self {
        case .copy:
            return "已複製"
        case .move:
            return "已移動"
        }
    }
}

public enum ConflictStrategy: String, CaseIterable, Codable, Identifiable, Sendable {
    case rename
    case skip
    case replace

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rename:
            return "自動改名"
        case .skip:
            return "略過同名"
        case .replace:
            return "取代同名"
        }
    }
}

public struct ClassificationJob: Sendable {
    public var inputURLs: [URL]
    public var outputRoot: URL
    public var rules: [ClassificationRule]
    public var operationMode: OperationMode
    public var includesSubfolders: Bool
    public var conflictStrategy: ConflictStrategy

    public init(
        inputURLs: [URL],
        outputRoot: URL,
        rules: [ClassificationRule],
        operationMode: OperationMode,
        includesSubfolders: Bool,
        conflictStrategy: ConflictStrategy = .rename
    ) {
        self.inputURLs = inputURLs
        self.outputRoot = outputRoot
        self.rules = rules
        self.operationMode = operationMode
        self.includesSubfolders = includesSubfolders
        self.conflictStrategy = conflictStrategy
    }
}

public struct ClassificationMessage: Identifiable, Codable, Sendable {
    public var id: UUID
    public var text: String
    public var isError: Bool

    public init(id: UUID = UUID(), text: String, isError: Bool = false) {
        self.id = id
        self.text = text
        self.isError = isError
    }
}

public struct ClassificationOperation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sourcePath: String
    public var destinationPath: String
    public var destinationFolderName: String
    public var matchedRuleID: UUID

    public init(
        id: UUID = UUID(),
        sourcePath: String,
        destinationPath: String,
        destinationFolderName: String,
        matchedRuleID: UUID
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.destinationFolderName = destinationFolderName
        self.matchedRuleID = matchedRuleID
    }

    public var sourceURL: URL {
        URL(fileURLWithPath: sourcePath)
    }

    public var destinationURL: URL {
        URL(fileURLWithPath: destinationPath)
    }
}

public struct ClassificationPlan: Identifiable, Codable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var inputPaths: [String]
    public var outputRootPath: String
    public var operationMode: OperationMode
    public var includesSubfolders: Bool
    public var conflictStrategy: ConflictStrategy
    public var scannedFiles: Int
    public var matchedFiles: Int
    public var skippedFiles: Int
    public var failedFiles: Int
    public var operations: [ClassificationOperation]
    public var messages: [ClassificationMessage]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        inputPaths: [String],
        outputRootPath: String,
        operationMode: OperationMode,
        includesSubfolders: Bool,
        conflictStrategy: ConflictStrategy,
        scannedFiles: Int = 0,
        matchedFiles: Int = 0,
        skippedFiles: Int = 0,
        failedFiles: Int = 0,
        operations: [ClassificationOperation] = [],
        messages: [ClassificationMessage] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.inputPaths = inputPaths
        self.outputRootPath = outputRootPath
        self.operationMode = operationMode
        self.includesSubfolders = includesSubfolders
        self.conflictStrategy = conflictStrategy
        self.scannedFiles = scannedFiles
        self.matchedFiles = matchedFiles
        self.skippedFiles = skippedFiles
        self.failedFiles = failedFiles
        self.operations = operations
        self.messages = messages
    }

    public var outputRoot: URL {
        URL(fileURLWithPath: outputRootPath, isDirectory: true)
    }
}

public struct SortTransaction: Identifiable, Codable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var operationMode: OperationMode
    public var operations: [ClassificationOperation]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        operationMode: OperationMode,
        operations: [ClassificationOperation]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.operationMode = operationMode
        self.operations = operations
    }
}

public struct ClassificationReport: Sendable {
    public var scannedFiles: Int
    public var matchedFiles: Int
    public var copiedFiles: Int
    public var movedFiles: Int
    public var skippedFiles: Int
    public var failedFiles: Int
    public var messages: [ClassificationMessage]
    public var completedOperations: [ClassificationOperation]
    public var transaction: SortTransaction?

    public init(
        scannedFiles: Int = 0,
        matchedFiles: Int = 0,
        copiedFiles: Int = 0,
        movedFiles: Int = 0,
        skippedFiles: Int = 0,
        failedFiles: Int = 0,
        messages: [ClassificationMessage] = [],
        completedOperations: [ClassificationOperation] = [],
        transaction: SortTransaction? = nil
    ) {
        self.scannedFiles = scannedFiles
        self.matchedFiles = matchedFiles
        self.copiedFiles = copiedFiles
        self.movedFiles = movedFiles
        self.skippedFiles = skippedFiles
        self.failedFiles = failedFiles
        self.messages = messages
        self.completedOperations = completedOperations
        self.transaction = transaction
    }
}

public struct UndoReport: Sendable {
    public var restoredFiles: Int
    public var removedFiles: Int
    public var skippedFiles: Int
    public var failedFiles: Int
    public var messages: [ClassificationMessage]

    public init(
        restoredFiles: Int = 0,
        removedFiles: Int = 0,
        skippedFiles: Int = 0,
        failedFiles: Int = 0,
        messages: [ClassificationMessage] = []
    ) {
        self.restoredFiles = restoredFiles
        self.removedFiles = removedFiles
        self.skippedFiles = skippedFiles
        self.failedFiles = failedFiles
        self.messages = messages
    }
}

public enum ClassificationEngine {
    public static func makePlan(job: ClassificationJob, fileManager: FileManager = .default) -> ClassificationPlan {
        let rules = job.rules.filter(\.isUsable)
        var plan = ClassificationPlan(
            inputPaths: job.inputURLs.map { $0.standardizedFileURL.path },
            outputRootPath: job.outputRoot.standardizedFileURL.path,
            operationMode: job.operationMode,
            includesSubfolders: job.includesSubfolders,
            conflictStrategy: job.conflictStrategy
        )
        var reservedDestinationPaths = Set<String>()

        guard !rules.isEmpty else {
            plan.failedFiles += 1
            plan.messages.append(.init(text: "沒有可用的分類規則。", isError: true))
            return plan
        }

        for inputURL in job.inputURLs {
            processInput(
                inputURL.standardizedFileURL,
                job: job,
                rules: rules,
                fileManager: fileManager,
                plan: &plan,
                reservedDestinationPaths: &reservedDestinationPaths
            )
        }

        if plan.operations.isEmpty && plan.messages.isEmpty {
            plan.messages.append(.init(text: "沒有找到符合規則的檔案。"))
        }

        return plan
    }

    public static func run(job: ClassificationJob, fileManager: FileManager = .default) -> ClassificationReport {
        let plan = makePlan(job: job, fileManager: fileManager)
        return apply(plan: plan, fileManager: fileManager)
    }

    public static func apply(plan: ClassificationPlan, fileManager: FileManager = .default) -> ClassificationReport {
        var report = ClassificationReport(
            scannedFiles: plan.scannedFiles,
            matchedFiles: plan.matchedFiles,
            skippedFiles: plan.skippedFiles,
            failedFiles: plan.failedFiles,
            messages: plan.messages
        )

        guard !plan.operations.isEmpty else {
            if report.messages.isEmpty {
                report.messages.append(.init(text: "沒有可執行的整理項目。"))
            }
            return report
        }

        do {
            try fileManager.createDirectory(at: plan.outputRoot, withIntermediateDirectories: true)
        } catch {
            report.failedFiles += plan.operations.count
            report.messages.append(.init(text: "無法建立輸出資料夾：\(error.localizedDescription)", isError: true))
            return report
        }

        for operation in plan.operations {
            do {
                let sourceURL = operation.sourceURL
                let destinationURL = operation.destinationURL
                let destinationFolder = destinationURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

                if plan.conflictStrategy == .replace, fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }

                switch plan.operationMode {
                case .copy:
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                    report.copiedFiles += 1
                case .move:
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                    report.movedFiles += 1
                }

                report.completedOperations.append(operation)
                report.messages.append(.init(text: "\(plan.operationMode.completedTitle)：\(sourceURL.lastPathComponent) → \(operation.destinationFolderName)/\(destinationURL.lastPathComponent)"))
            } catch {
                report.failedFiles += 1
                report.messages.append(.init(text: "處理失敗：\(operation.sourcePath)（\(error.localizedDescription)）", isError: true))
            }
        }

        if !report.completedOperations.isEmpty {
            report.transaction = SortTransaction(operationMode: plan.operationMode, operations: report.completedOperations)
        }

        return report
    }

    public static func sanitizedFolderName(_ value: String) -> String {
        let cleaned = value
            .components(separatedBy: CharacterSet(charactersIn: "/:"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "未命名" : cleaned
    }

    private static func processInput(
        _ inputURL: URL,
        job: ClassificationJob,
        rules: [ClassificationRule],
        fileManager: FileManager,
        plan: inout ClassificationPlan,
        reservedDestinationPaths: inout Set<String>
    ) {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: inputURL.path, isDirectory: &isDirectory) else {
            plan.failedFiles += 1
            plan.messages.append(.init(text: "找不到：\(inputURL.path)", isError: true))
            return
        }

        if isDirectory.boolValue {
            guard !isEqualOrInside(inputURL, parent: job.outputRoot) else {
                plan.skippedFiles += 1
                plan.messages.append(.init(text: "已略過輸出資料夾本身：\(inputURL.lastPathComponent)"))
                return
            }

            if job.includesSubfolders {
                processFolderRecursively(inputURL, job: job, rules: rules, fileManager: fileManager, plan: &plan, reservedDestinationPaths: &reservedDestinationPaths)
            } else {
                processFolderDirectChildren(inputURL, job: job, rules: rules, fileManager: fileManager, plan: &plan, reservedDestinationPaths: &reservedDestinationPaths)
            }
        } else {
            planFile(inputURL, job: job, rules: rules, fileManager: fileManager, plan: &plan, reservedDestinationPaths: &reservedDestinationPaths)
        }
    }

    private static func processFolderRecursively(
        _ folderURL: URL,
        job: ClassificationJob,
        rules: [ClassificationRule],
        fileManager: FileManager,
        plan: inout ClassificationPlan,
        reservedDestinationPaths: inout Set<String>
    ) {
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            plan.failedFiles += 1
            plan.messages.append(.init(text: "無法讀取資料夾：\(folderURL.path)", isError: true))
            return
        }

        for case let itemURL as URL in enumerator {
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory)

            if isEqualOrInside(itemURL, parent: job.outputRoot) {
                if isDirectory.boolValue {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard !isDirectory.boolValue else { continue }
            planFile(itemURL, job: job, rules: rules, fileManager: fileManager, plan: &plan, reservedDestinationPaths: &reservedDestinationPaths)
        }
    }

    private static func processFolderDirectChildren(
        _ folderURL: URL,
        job: ClassificationJob,
        rules: [ClassificationRule],
        fileManager: FileManager,
        plan: inout ClassificationPlan,
        reservedDestinationPaths: inout Set<String>
    ) {
        do {
            let children = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for itemURL in children where !isEqualOrInside(itemURL, parent: job.outputRoot) {
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory)
                guard !isDirectory.boolValue else { continue }
                planFile(itemURL, job: job, rules: rules, fileManager: fileManager, plan: &plan, reservedDestinationPaths: &reservedDestinationPaths)
            }
        } catch {
            plan.failedFiles += 1
            plan.messages.append(.init(text: "無法讀取資料夾：\(folderURL.path)", isError: true))
        }
    }

    private static func planFile(
        _ sourceURL: URL,
        job: ClassificationJob,
        rules: [ClassificationRule],
        fileManager: FileManager,
        plan: inout ClassificationPlan,
        reservedDestinationPaths: inout Set<String>
    ) {
        plan.scannedFiles += 1

        guard let rule = rules.first(where: { $0.matches(fileURL: sourceURL) }) else {
            plan.skippedFiles += 1
            return
        }

        plan.matchedFiles += 1
        let destinationFolderName = sanitizedFolderName(rule.folderName)
        let destinationFolder = job.outputRoot.appendingPathComponent(destinationFolderName, isDirectory: true)
        let proposedDestination = destinationFolder.appendingPathComponent(sourceURL.lastPathComponent)
        let destinationURL: URL

        switch job.conflictStrategy {
        case .rename:
            destinationURL = uniqueDestinationURL(
                for: sourceURL,
                in: destinationFolder,
                fileManager: fileManager,
                reservedDestinationPaths: reservedDestinationPaths
            )
        case .skip:
            if destinationExists(proposedDestination, fileManager: fileManager, reservedDestinationPaths: reservedDestinationPaths) {
                plan.skippedFiles += 1
                plan.messages.append(.init(text: "同名檔已存在，已略過：\(sourceURL.lastPathComponent)"))
                return
            }
            destinationURL = proposedDestination
        case .replace:
            if reservedDestinationPaths.contains(proposedDestination.standardizedFileURL.path) {
                plan.skippedFiles += 1
                plan.messages.append(.init(text: "同一批整理中已有同名目的地，已略過：\(sourceURL.lastPathComponent)"))
                return
            }
            destinationURL = proposedDestination
        }

        guard sourceURL.standardizedFileURL.path != destinationURL.standardizedFileURL.path else {
            plan.skippedFiles += 1
            plan.messages.append(.init(text: "來源與目的地相同，已略過：\(sourceURL.lastPathComponent)"))
            return
        }

        reservedDestinationPaths.insert(destinationURL.standardizedFileURL.path)
        plan.operations.append(ClassificationOperation(
            sourcePath: sourceURL.standardizedFileURL.path,
            destinationPath: destinationURL.standardizedFileURL.path,
            destinationFolderName: destinationFolderName,
            matchedRuleID: rule.id
        ))
    }

    private static func uniqueDestinationURL(
        for sourceURL: URL,
        in folderURL: URL,
        fileManager: FileManager,
        reservedDestinationPaths: Set<String>
    ) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        var candidate = folderURL.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 2

        while destinationExists(candidate, fileManager: fileManager, reservedDestinationPaths: reservedDestinationPaths) {
            let suffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"
            candidate = folderURL.appendingPathComponent("\(baseName) \(counter)\(suffix)")
            counter += 1
        }

        return candidate
    }

    private static func destinationExists(
        _ destinationURL: URL,
        fileManager: FileManager,
        reservedDestinationPaths: Set<String>
    ) -> Bool {
        fileManager.fileExists(atPath: destinationURL.path)
            || reservedDestinationPaths.contains(destinationURL.standardizedFileURL.path)
    }

    private static func isEqualOrInside(_ child: URL, parent: URL) -> Bool {
        let childPath = child.standardizedFileURL.path
        let parentPath = parent.standardizedFileURL.path
        return childPath == parentPath || childPath.hasPrefix(parentPath + "/")
    }
}

public final class TransactionStore: @unchecked Sendable {
    public let directoryURL: URL

    public init(directoryURL: URL = TransactionStore.defaultDirectoryURL()) {
        self.directoryURL = directoryURL
    }

    public static func defaultDirectoryURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return applicationSupport
            .appendingPathComponent("FolderSorter", isDirectory: true)
            .appendingPathComponent("Transactions", isDirectory: true)
    }

    public func save(_ transaction: SortTransaction, fileManager: FileManager = .default) throws -> URL {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let destination = directoryURL.appendingPathComponent("\(transaction.createdAt.timeIntervalSince1970)-\(transaction.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(transaction).write(to: destination)
        return destination
    }

    public func latestTransaction(fileManager: FileManager = .default) -> (transaction: SortTransaction, url: URL)? {
        guard
            let files = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]),
            !files.isEmpty
        else {
            return nil
        }

        let jsonFiles = files.filter { $0.pathExtension == "json" }
        let latestURL = jsonFiles.max { left, right in
            let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return leftDate < rightDate
        }

        guard
            let latestURL,
            let data = try? Data(contentsOf: latestURL)
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let transaction = try? decoder.decode(SortTransaction.self, from: data) else {
            return nil
        }

        return (transaction, latestURL)
    }

    public func undoLatest(fileManager: FileManager = .default) -> UndoReport {
        guard let latest = latestTransaction(fileManager: fileManager) else {
            return UndoReport(messages: [.init(text: "沒有可復原的整理紀錄。")])
        }

        var report = undo(latest.transaction, fileManager: fileManager)
        if report.failedFiles == 0 {
            do {
                try fileManager.removeItem(at: latest.url)
            } catch {
                report.failedFiles += 1
                report.messages.append(.init(text: "復原完成，但無法移除紀錄：\(error.localizedDescription)", isError: true))
            }
        }
        return report
    }

    public func undo(_ transaction: SortTransaction, fileManager: FileManager = .default) -> UndoReport {
        var report = UndoReport()

        for operation in transaction.operations.reversed() {
            let sourceURL = operation.sourceURL
            let destinationURL = operation.destinationURL

            switch transaction.operationMode {
            case .copy:
                guard fileManager.fileExists(atPath: destinationURL.path) else {
                    report.skippedFiles += 1
                    report.messages.append(.init(text: "目的地不存在，已略過：\(destinationURL.lastPathComponent)"))
                    continue
                }

                do {
                    try fileManager.removeItem(at: destinationURL)
                    report.removedFiles += 1
                    report.messages.append(.init(text: "已移除複製檔：\(destinationURL.lastPathComponent)"))
                } catch {
                    report.failedFiles += 1
                    report.messages.append(.init(text: "無法移除：\(destinationURL.path)（\(error.localizedDescription)）", isError: true))
                }

            case .move:
                guard fileManager.fileExists(atPath: destinationURL.path) else {
                    report.skippedFiles += 1
                    report.messages.append(.init(text: "目的地不存在，已略過：\(destinationURL.lastPathComponent)"))
                    continue
                }

                guard !fileManager.fileExists(atPath: sourceURL.path) else {
                    report.skippedFiles += 1
                    report.messages.append(.init(text: "原位置已有檔案，已略過：\(sourceURL.lastPathComponent)", isError: true))
                    continue
                }

                do {
                    try fileManager.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fileManager.moveItem(at: destinationURL, to: sourceURL)
                    report.restoredFiles += 1
                    report.messages.append(.init(text: "已移回：\(sourceURL.lastPathComponent)"))
                } catch {
                    report.failedFiles += 1
                    report.messages.append(.init(text: "無法移回：\(destinationURL.path)（\(error.localizedDescription)）", isError: true))
                }
            }
        }

        if report.messages.isEmpty {
            report.messages.append(.init(text: "沒有需要復原的項目。"))
        }

        return report
    }
}
