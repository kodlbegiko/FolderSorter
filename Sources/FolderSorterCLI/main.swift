import Foundation
import FolderSorterCore

struct CLIOptions {
    var inputPaths: [String] = []
    var outputPath: String?
    var rulesPath: String?
    var operationMode: OperationMode = .copy
    var conflictStrategy: ConflictStrategy = .rename
    var includesSubfolders = true
    var shouldApply = false
    var shouldUndo = false
    var shouldShowHelp = false
}

enum CLIError: Error, CustomStringConvertible {
    case missingValue(String)
    case unknownArgument(String)
    case missingInput
    case missingOutput
    case invalidConflictStrategy(String)
    case unreadableRules(String)

    var description: String {
        switch self {
        case .missingValue(let argument):
            return "Missing value for \(argument)"
        case .unknownArgument(let argument):
            return "Unknown argument: \(argument)"
        case .missingInput:
            return "At least one --input path is required"
        case .missingOutput:
            return "--output is required"
        case .invalidConflictStrategy(let value):
            return "Invalid conflict strategy: \(value). Use rename, skip, or replace."
        case .unreadableRules(let reason):
            return "Could not read rules: \(reason)"
        }
    }
}

@main
struct FolderSorterCLI {
    static func main() {
        do {
            let options = try parse(CommandLine.arguments.dropFirst())

            if options.shouldShowHelp {
                printUsage()
                return
            }

            if options.shouldUndo {
                let report = TransactionStore().undoLatest()
                printUndoReport(report)
                Foundation.exit(report.failedFiles == 0 ? 0 : 1)
            }

            guard !options.inputPaths.isEmpty else { throw CLIError.missingInput }
            guard let outputPath = options.outputPath else { throw CLIError.missingOutput }

            let rules = try loadRules(path: options.rulesPath)
            let job = ClassificationJob(
                inputURLs: options.inputPaths.map { URL(fileURLWithPath: $0).standardizedFileURL },
                outputRoot: URL(fileURLWithPath: outputPath, isDirectory: true).standardizedFileURL,
                rules: rules,
                operationMode: options.operationMode,
                includesSubfolders: options.includesSubfolders,
                conflictStrategy: options.conflictStrategy
            )

            let plan = ClassificationEngine.makePlan(job: job)
            printPlan(plan)

            guard options.shouldApply else {
                print("\nDry run only. Add --apply to move or copy files.")
                Foundation.exit(plan.failedFiles == 0 ? 0 : 1)
            }

            let report = ClassificationEngine.apply(plan: plan)
            if let transaction = report.transaction {
                _ = try TransactionStore().save(transaction)
            }
            printReport(report)
            Foundation.exit(report.failedFiles == 0 ? 0 : 1)
        } catch {
            fputs("foldersorter: \(error)\n\n", stderr)
            printUsage(to: stderr)
            Foundation.exit(2)
        }
    }

    private static func parse(_ arguments: ArraySlice<String>) throws -> CLIOptions {
        var options = CLIOptions()
        var iterator = arguments.makeIterator()

        while let argument = iterator.next() {
            switch argument {
            case "-h", "--help":
                options.shouldShowHelp = true
            case "-i", "--input":
                guard let value = iterator.next() else { throw CLIError.missingValue(argument) }
                options.inputPaths.append(value)
            case "-o", "--output":
                guard let value = iterator.next() else { throw CLIError.missingValue(argument) }
                options.outputPath = value
            case "--rules":
                guard let value = iterator.next() else { throw CLIError.missingValue(argument) }
                options.rulesPath = value
            case "--move":
                options.operationMode = .move
            case "--copy":
                options.operationMode = .copy
            case "--apply":
                options.shouldApply = true
            case "--dry-run":
                options.shouldApply = false
            case "--undo":
                options.shouldUndo = true
            case "--no-recursive":
                options.includesSubfolders = false
            case "--conflict":
                guard let value = iterator.next() else { throw CLIError.missingValue(argument) }
                guard let strategy = ConflictStrategy(rawValue: value) else {
                    throw CLIError.invalidConflictStrategy(value)
                }
                options.conflictStrategy = strategy
            default:
                throw CLIError.unknownArgument(argument)
            }
        }

        return options
    }

    private static func loadRules(path: String?) throws -> [ClassificationRule] {
        guard let path else {
            return ClassificationRule.defaultRules
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let rules = try JSONDecoder().decode([ClassificationRule].self, from: data)
            guard !rules.filter(\.isUsable).isEmpty else {
                throw CLIError.unreadableRules("rules file has no usable rules")
            }
            return rules
        } catch let error as CLIError {
            throw error
        } catch {
            throw CLIError.unreadableRules(error.localizedDescription)
        }
    }

    private static func printPlan(_ plan: ClassificationPlan) {
        print("Preview")
        print("  scanned: \(plan.scannedFiles)")
        print("  matched: \(plan.matchedFiles)")
        print("  planned: \(plan.operations.count)")
        print("  skipped: \(plan.skippedFiles)")
        print("  issues:  \(plan.failedFiles)")
        print("  mode:    \(plan.operationMode.rawValue)")
        print("  conflict:\(plan.conflictStrategy.rawValue)")

        for operation in plan.operations {
            print("  \(operation.sourcePath) -> \(operation.destinationPath)")
        }

        for message in plan.messages where message.isError {
            print("  warning: \(message.text)")
        }
    }

    private static func printReport(_ report: ClassificationReport) {
        print("\nApplied")
        print("  copied:  \(report.copiedFiles)")
        print("  moved:   \(report.movedFiles)")
        print("  skipped: \(report.skippedFiles)")
        print("  failed:  \(report.failedFiles)")

        for message in report.messages where message.isError {
            print("  error: \(message.text)")
        }
    }

    private static func printUndoReport(_ report: UndoReport) {
        print("Undo")
        print("  restored: \(report.restoredFiles)")
        print("  removed:  \(report.removedFiles)")
        print("  skipped:  \(report.skippedFiles)")
        print("  failed:   \(report.failedFiles)")

        for message in report.messages {
            print("  \(message.isError ? "error" : "info"): \(message.text)")
        }
    }

    private static func printUsage(to stream: UnsafeMutablePointer<FILE> = stdout) {
        let usage = """
        Usage:
          foldersorter --input PATH --output PATH [--apply] [--move] [--rules rules.json]
          foldersorter --undo

        Options:
          -i, --input PATH        File or folder to sort. Repeat for multiple inputs.
          -o, --output PATH       Destination root folder.
              --apply             Apply the preview. Default is dry-run.
              --dry-run           Preview only.
              --move              Move files instead of copying.
              --copy              Copy files. This is the default.
              --conflict VALUE    rename, skip, or replace. Default is rename.
              --rules PATH        JSON rules exported from the app.
              --no-recursive      Do not scan subfolders.
              --undo              Undo the latest applied cleanup.
          -h, --help              Show this help.
        """
        fputs(usage + "\n", stream)
    }
}
