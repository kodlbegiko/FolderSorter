import AppKit
import FolderSorterCore
import SwiftUI
import UniformTypeIdentifiers

@main
struct FolderSorterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = NSImage(named: "AppIcon")
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        OpenedURLRouter.shared.enqueue(urls)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        OpenedURLRouter.shared.enqueue([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        OpenedURLRouter.shared.enqueue(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
    }
}

@MainActor
final class OpenedURLRouter: ObservableObject {
    static let shared = OpenedURLRouter()

    @Published private(set) var pendingURLs: [URL] = []

    func enqueue(_ urls: [URL]) {
        pendingURLs.append(contentsOf: urls)
    }

    func clear() {
        pendingURLs.removeAll()
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var rules: [ClassificationRule] {
        didSet { persistRules() }
    }

    @Published var outputFolder: URL {
        didSet { defaults.set(outputFolder.path, forKey: Self.outputFolderKey) }
    }

    @Published var operationMode: OperationMode {
        didSet { defaults.set(operationMode.rawValue, forKey: Self.operationModeKey) }
    }

    @Published var includesSubfolders: Bool {
        didSet { defaults.set(includesSubfolders, forKey: Self.includesSubfoldersKey) }
    }

    @Published var conflictStrategy: ConflictStrategy {
        didSet { defaults.set(conflictStrategy.rawValue, forKey: Self.conflictStrategyKey) }
    }

    @Published private(set) var isProcessing = false
    @Published private(set) var lastReport: ClassificationReport?
    @Published private(set) var pendingPlan: ClassificationPlan?
    @Published private(set) var lastTransaction: SortTransaction?
    @Published private(set) var logMessages: [ClassificationMessage] = [
        .init(text: "等待資料夾。")
    ]

    private static let rulesKey = "folder-sorter.rules"
    private static let outputFolderKey = "folder-sorter.output-folder"
    private static let operationModeKey = "folder-sorter.operation-mode"
    private static let includesSubfoldersKey = "folder-sorter.includes-subfolders"
    private static let conflictStrategyKey = "folder-sorter.conflict-strategy"
    private let defaults = UserDefaults.standard
    private let transactionStore = TransactionStore()

    init() {
        self.rules = Self.loadRules(from: defaults)
        self.outputFolder = Self.loadOutputFolder(from: defaults)
        self.operationMode = Self.loadOperationMode(from: defaults)
        self.includesSubfolders = defaults.object(forKey: Self.includesSubfoldersKey) as? Bool ?? true
        self.conflictStrategy = Self.loadConflictStrategy(from: defaults)
        self.lastTransaction = transactionStore.latestTransaction()?.transaction
    }

    var outputPath: String {
        outputFolder.path
    }

    func addRule() {
        rules.append(ClassificationRule(extensionsText: "png", folderName: "圖片"))
    }

    func removeRule(id: UUID) {
        guard rules.count > 1 else { return }
        rules.removeAll { $0.id == id }
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "選擇輸出資料夾"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url
        }
    }

    func chooseInputItems() {
        let panel = NSOpenPanel()
        panel.title = "選擇要預覽整理的資料夾或檔案"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true

        if panel.runModal() == .OK {
            preview(panel.urls)
        }
    }

    func previewDownloads() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
        preview([downloads])
    }

    func previewDesktop() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
        preview([desktop])
    }

    func revealOutputFolder() {
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(outputFolder)
    }

    func clearPreview() {
        pendingPlan = nil
        logMessages = [.init(text: "已清除預覽。")]
    }

    func preview(_ urls: [URL]) {
        let uniqueURLs = urls.reduce(into: [URL]()) { partialResult, url in
            let standardized = url.standardizedFileURL
            if !partialResult.contains(where: { $0.standardizedFileURL.path == standardized.path }) {
                partialResult.append(standardized)
            }
        }

        guard !uniqueURLs.isEmpty else {
            logMessages = [.init(text: "沒有可處理的項目。", isError: true)]
            return
        }

        guard !isProcessing else {
            logMessages.insert(.init(text: "正在處理中，請等目前任務完成。", isError: true), at: 0)
            return
        }

        let job = ClassificationJob(
            inputURLs: uniqueURLs,
            outputRoot: outputFolder,
            rules: rules,
            operationMode: operationMode,
            includesSubfolders: includesSubfolders,
            conflictStrategy: conflictStrategy
        )

        isProcessing = true
        lastReport = nil
        pendingPlan = nil
        logMessages = [.init(text: "正在建立安全預覽，不會移動任何檔案。")]

        Task {
            let plan = await Task.detached(priority: .userInitiated) {
                ClassificationEngine.makePlan(job: job)
            }.value
            finishPreview(plan)
        }
    }

    func applyPendingPlan() {
        guard let plan = pendingPlan else {
            logMessages = [.init(text: "沒有可執行的預覽。", isError: true)]
            return
        }

        guard !isProcessing else {
            logMessages.insert(.init(text: "正在處理中，請等目前任務完成。", isError: true), at: 0)
            return
        }

        isProcessing = true
        logMessages = [.init(text: "開始整理 \(plan.operations.count) 個檔案。")]

        Task {
            let report = await Task.detached(priority: .userInitiated) {
                ClassificationEngine.apply(plan: plan)
            }.value
            finishApply(report)
        }
    }

    func undoLatestCleanup() {
        guard !isProcessing else {
            logMessages.insert(.init(text: "正在處理中，請等目前任務完成。", isError: true), at: 0)
            return
        }

        isProcessing = true
        logMessages = [.init(text: "正在復原上一筆整理。")]

        let store = transactionStore
        Task {
            let undoReport = await Task.detached(priority: .userInitiated) {
                store.undoLatest()
            }.value
            finishUndo(undoReport)
        }
    }

    func exportRules() {
        let panel = NSSavePanel()
        panel.title = "匯出分類規則"
        panel.nameFieldStringValue = "foldersorter-rules.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(rules).write(to: url)
            logMessages = [.init(text: "已匯出規則：\(url.lastPathComponent)")]
        } catch {
            logMessages = [.init(text: "匯出規則失敗：\(error.localizedDescription)", isError: true)]
        }
    }

    func importRules() {
        let panel = NSOpenPanel()
        panel.title = "匯入分類規則"
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let decodedRules = try JSONDecoder().decode([ClassificationRule].self, from: data)
            guard !decodedRules.filter(\.isUsable).isEmpty else {
                logMessages = [.init(text: "匯入失敗：檔案沒有可用規則。", isError: true)]
                return
            }
            rules = decodedRules
            pendingPlan = nil
            logMessages = [.init(text: "已匯入 \(decodedRules.count) 條規則。")]
        } catch {
            logMessages = [.init(text: "匯入規則失敗：\(error.localizedDescription)", isError: true)]
        }
    }

    private func finishPreview(_ plan: ClassificationPlan) {
        pendingPlan = plan
        isProcessing = false

        let summary = ClassificationMessage(
            text: "預覽完成：掃描 \(plan.scannedFiles)，符合 \(plan.matchedFiles)，將整理 \(plan.operations.count)，略過 \(plan.skippedFiles)，問題 \(plan.failedFiles)。",
            isError: plan.failedFiles > 0
        )
        logMessages = [summary] + Array(plan.messages.suffix(200))
    }

    private func finish(_ report: ClassificationReport) {
        finishApply(report)
    }

    private func finishApply(_ report: ClassificationReport) {
        lastReport = report
        isProcessing = false
        pendingPlan = nil

        var persistenceMessage: ClassificationMessage?
        if let transaction = report.transaction {
            do {
                _ = try transactionStore.save(transaction)
                lastTransaction = transaction
            } catch {
                persistenceMessage = .init(text: "整理完成，但復原紀錄儲存失敗：\(error.localizedDescription)", isError: true)
            }
        }

        let completedCount = report.copiedFiles + report.movedFiles
        let summary = ClassificationMessage(
            text: "完成：掃描 \(report.scannedFiles)，符合 \(report.matchedFiles)，整理 \(completedCount)，略過 \(report.skippedFiles)，失敗 \(report.failedFiles)。",
            isError: report.failedFiles > 0
        )
        logMessages = [summary] + [persistenceMessage].compactMap { $0 } + Array(report.messages.suffix(200))
    }

    private func finishUndo(_ report: UndoReport) {
        isProcessing = false
        lastTransaction = transactionStore.latestTransaction()?.transaction
        lastReport = nil
        pendingPlan = nil

        let summary = ClassificationMessage(
            text: "復原完成：移回 \(report.restoredFiles)，移除複製檔 \(report.removedFiles)，略過 \(report.skippedFiles)，失敗 \(report.failedFiles)。",
            isError: report.failedFiles > 0
        )
        logMessages = [summary] + Array(report.messages.suffix(200))
    }

    private func persistRules() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: Self.rulesKey)
    }

    private static func loadRules(from defaults: UserDefaults) -> [ClassificationRule] {
        guard
            let data = defaults.data(forKey: rulesKey),
            let decoded = try? JSONDecoder().decode([ClassificationRule].self, from: data),
            !decoded.isEmpty
        else {
            return ClassificationRule.defaultRules
        }
        return decoded
    }

    private static func loadOutputFolder(from defaults: UserDefaults) -> URL {
        if let path = defaults.string(forKey: outputFolderKey), !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return desktop.appendingPathComponent("C", isDirectory: true)
    }

    private static func loadOperationMode(from defaults: UserDefaults) -> OperationMode {
        guard
            let rawValue = defaults.string(forKey: operationModeKey),
            let mode = OperationMode(rawValue: rawValue)
        else {
            return .copy
        }
        return mode
    }

    private static func loadConflictStrategy(from defaults: UserDefaults) -> ConflictStrategy {
        guard
            let rawValue = defaults.string(forKey: conflictStrategyKey),
            let strategy = ConflictStrategy(rawValue: rawValue)
        else {
            return .rename
        }
        return strategy
    }
}

struct ContentView: View {
    @StateObject private var state = AppState()
    @ObservedObject private var openedURLRouter = OpenedURLRouter.shared
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 390)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            mainPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 920, minHeight: 620)
        .onReceive(openedURLRouter.$pendingURLs) { urls in
            guard !urls.isEmpty else { return }
            state.preview(urls)
            openedURLRouter.clear()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                AppAvatarView(size: 72)

                VStack(alignment: .leading, spacing: 5) {
                    Text("資料夾分類器")
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("規則")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            quickActionSection
            outputSection
            modeSection
            rulesSection

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var quickActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快速預覽")
                .font(.headline)

            HStack(spacing: 8) {
                Button {
                    state.previewDownloads()
                } label: {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
                .disabled(state.isProcessing)

                Button {
                    state.previewDesktop()
                } label: {
                    Label("Desktop", systemImage: "desktopcomputer")
                }
                .disabled(state.isProcessing)
            }
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("輸出資料夾")
                .font(.headline)

            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.secondary)
                Text(state.outputPath)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Button {
                    state.chooseOutputFolder()
                } label: {
                    Label("選擇", systemImage: "folder.badge.plus")
                }

                Button {
                    state.revealOutputFolder()
                } label: {
                    Label("打開", systemImage: "arrow.up.forward.app")
                }
            }
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("處理方式")
                .font(.headline)

            Picker("處理方式", selection: $state.operationMode) {
                ForEach(OperationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("同名衝突", selection: $state.conflictStrategy) {
                ForEach(ConflictStrategy.allCases) { strategy in
                    Text(strategy.title).tag(strategy)
                }
            }
            .pickerStyle(.segmented)

            Toggle("包含子資料夾", isOn: $state.includesSubfolders)
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("分類規則")
                    .font(.headline)
                Spacer()
                Button {
                    state.importRules()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("匯入規則")

                Button {
                    state.exportRules()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("匯出規則")

                Button {
                    state.addRule()
                } label: {
                    Image(systemName: "plus")
                }
                .help("新增規則")
            }

            HStack {
                Text("副檔名")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("名稱包含")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("目的資料夾")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                    .frame(width: 28)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach($state.rules) { $rule in
                        RuleRow(rule: $rule) {
                            state.removeRule(id: rule.id)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 150, maxHeight: 260)
        }
    }

    private var mainPanel: some View {
        VStack(spacing: 18) {
            dropZone
            previewPanel
            summaryStrip
            logPanel
        }
        .padding(22)
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor))

            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [8, 6])
                )

            VStack(spacing: 14) {
                Image(systemName: state.isProcessing ? "clock.arrow.circlepath" : "tray.and.arrow.down")
                    .font(.system(size: 46, weight: .medium))
                    .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)

                Text(state.isProcessing ? "處理中" : "拖放資料夾到這裡預覽")
                    .font(.title3.weight(.semibold))

                HStack(spacing: 10) {
                    Button {
                        state.chooseInputItems()
                    } label: {
                        Label("選擇資料夾", systemImage: "folder.badge.plus")
                    }
                    .disabled(state.isProcessing)

                    Button {
                        state.applyPendingPlan()
                    } label: {
                        Label("開始整理", systemImage: "play.fill")
                    }
                    .disabled(state.isProcessing || state.pendingPlan?.operations.isEmpty != false)

                    Button {
                        state.undoLatestCleanup()
                    } label: {
                        Label("復原", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(state.isProcessing)

                    Button {
                        state.revealOutputFolder()
                    } label: {
                        Label("查看輸出", systemImage: "magnifyingglass")
                    }
                }

                if state.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(28)
        }
        .frame(minHeight: 250)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            DropURLLoader.load(from: providers) { urls in
                state.preview(urls)
            }
        }
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("整理預覽")
                    .font(.headline)
                Spacer()
                if let plan = state.pendingPlan {
                    Text("\(plan.operations.count) 個待整理")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Button {
                    state.clearPreview()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("清除預覽")
                .disabled(state.pendingPlan == nil)
            }

            if let plan = state.pendingPlan {
                if plan.operations.isEmpty {
                    Text("沒有符合目前規則的檔案。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(plan.operations.prefix(80))) { operation in
                                PreviewRow(operation: operation, mode: plan.operationMode)
                            }

                            if plan.operations.count > 80 {
                                Text("另有 \(plan.operations.count - 80) 個項目未顯示。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                            }
                        }
                        .padding(10)
                    }
                    .frame(maxHeight: 160)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                }
            } else {
                Text("拖入資料夾後會先列出所有將要移動或複製的檔案。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 12) {
            if let plan = state.pendingPlan {
                MetricTile(title: "掃描", value: plan.scannedFiles, systemImage: "doc.text.magnifyingglass")
                MetricTile(title: "符合", value: plan.matchedFiles, systemImage: "checkmark.circle")
                MetricTile(title: "待整理", value: plan.operations.count, systemImage: "list.bullet.rectangle")
                MetricTile(title: "衝突", textValue: plan.conflictStrategy.title, systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                MetricTile(title: "問題", value: plan.failedFiles, systemImage: "exclamationmark.triangle", isError: plan.failedFiles > 0)
            } else if let report = state.lastReport {
                MetricTile(title: "掃描", value: report.scannedFiles, systemImage: "doc.text.magnifyingglass")
                MetricTile(title: "符合", value: report.matchedFiles, systemImage: "checkmark.circle")
                MetricTile(title: state.operationMode.completedTitle, value: report.copiedFiles + report.movedFiles, systemImage: "folder.fill.badge.gearshape")
                MetricTile(title: "略過", value: report.skippedFiles, systemImage: "forward")
                MetricTile(title: "失敗", value: report.failedFiles, systemImage: "exclamationmark.triangle", isError: report.failedFiles > 0)
            } else {
                MetricTile(title: "預設", value: state.rules.count, systemImage: "slider.horizontal.3")
                MetricTile(title: "模式", textValue: state.operationMode.title, systemImage: "arrow.left.arrow.right")
                MetricTile(title: "輸出", textValue: "C", systemImage: "folder")
            }
        }
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("紀錄")
                .font(.headline)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(state.logMessages) { message in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: message.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(message.isError ? Color.red : Color.green)
                                .frame(width: 18)
                            Text(message.text)
                                .font(.callout)
                                .foregroundStyle(message.isError ? Color.primary : Color.secondary)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxHeight: .infinity)
    }
}

struct AppAvatarView: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.31, blue: 0.36),
                            Color(red: 0.08, green: 0.50, blue: 0.48),
                            Color(red: 0.92, green: 0.39, blue: 0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.78, blue: 0.24))
                    .frame(width: size * 0.34, height: size * 0.16)
                    .offset(x: size * 0.13, y: -size * 0.34)

                RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.73, blue: 0.20),
                                Color(red: 0.96, green: 0.47, blue: 0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.68, height: size * 0.38)

                VStack(alignment: .leading, spacing: size * 0.06) {
                    Capsule()
                        .fill(Color.white.opacity(0.94))
                        .frame(width: size * 0.40, height: size * 0.05)
                    Capsule()
                        .fill(Color(red: 0.06, green: 0.36, blue: 0.44).opacity(0.85))
                        .frame(width: size * 0.34, height: size * 0.05)
                }
                .padding(.leading, size * 0.12)
                .padding(.bottom, size * 0.11)
            }
            .frame(width: size * 0.72, height: size * 0.56)
            .shadow(color: .black.opacity(0.18), radius: size * 0.04, y: size * 0.03)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.16), radius: size * 0.10, y: size * 0.05)
        .accessibilityHidden(true)
    }
}

struct RuleRow: View {
    @Binding var rule: ClassificationRule
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("mp4, jpg", text: $rule.extensionsText)
                .textFieldStyle(.roundedBorder)

            TextField("screenshot", text: $rule.nameContainsText)
                .textFieldStyle(.roundedBorder)

            TextField("影片", text: $rule.folderName)
                .textFieldStyle(.roundedBorder)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("刪除規則")
        }
    }
}

struct PreviewRow: View {
    var operation: ClassificationOperation
    var mode: OperationMode

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: mode == .copy ? "doc.on.doc" : "arrow.right")
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(operation.sourceURL.lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text("\(operation.destinationFolderName)/\(operation.destinationURL.lastPathComponent)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct MetricTile: View {
    var title: String
    var value: Int?
    var textValue: String?
    var systemImage: String
    var isError = false

    init(title: String, value: Int, systemImage: String, isError: Bool = false) {
        self.title = title
        self.value = value
        self.textValue = nil
        self.systemImage = systemImage
        self.isError = isError
    }

    init(title: String, textValue: String, systemImage: String, isError: Bool = false) {
        self.title = title
        self.value = nil
        self.textValue = textValue
        self.systemImage = systemImage
        self.isError = isError
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(isError ? Color.red : Color.accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(textValue ?? "\(value ?? 0)")
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private final class DropURLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []

    func append(_ url: URL) {
        lock.lock()
        urls.append(url)
        lock.unlock()
    }

    func snapshot() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }
}

enum DropURLLoader {
    static func load(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) -> Bool {
        let collector = DropURLCollector()
        let group = DispatchGroup()
        var acceptedProviderCount = 0

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            acceptedProviderCount += 1
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = makeURL(from: item) {
                    collector.append(url)
                }
                group.leave()
            }
        }

        guard acceptedProviderCount > 0 else { return false }

        group.notify(queue: .main) {
            completion(collector.snapshot())
        }
        return true
    }

    private static func makeURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let nsURL = item as? NSURL {
            return nsURL as URL
        }

        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }

        if let string = item as? String {
            return URL(string: string) ?? URL(fileURLWithPath: string)
        }

        return nil
    }
}
