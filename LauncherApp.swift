import AppKit
import Foundation

struct LauncherConfig: Codable {
    var recentProjects: [String]
    var pinnedProjects: [String]
    var commands: [String: String]

    static func `default`() -> LauncherConfig {
        LauncherConfig(
            recentProjects: [],
            pinnedProjects: [],
            commands: [
                "codex": "codex",
                "claude": "claude",
            ]
        )
    }
}

enum ConfigStore {
    static let fileManager = FileManager.default
    static let supportDirectory = fileManager.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/ai-code-launcher", isDirectory: true)
    static let configURL = supportDirectory.appendingPathComponent("config.json", isDirectory: false)

    static func load() -> LauncherConfig {
        guard let data = try? Data(contentsOf: configURL) else {
            return .default()
        }

        let decoder = JSONDecoder()
        guard let config = try? decoder.decode(LauncherConfig.self, from: data) else {
            return .default()
        }

        return sanitize(config)
    }

    static func save(_ config: LauncherConfig) {
        let sanitized = sanitize(config)
        try? fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(sanitized) else {
            return
        }
        try? data.write(to: configURL, options: .atomic)
    }

    private static func sanitize(_ config: LauncherConfig) -> LauncherConfig {
        var result = config
        result.recentProjects = dedupeExistingDirectories(config.recentProjects)
        result.pinnedProjects = dedupeExistingDirectories(config.pinnedProjects)
        result.commands["codex"] = normalizedCommand(config.commands["codex"], fallback: "codex")
        result.commands["claude"] = normalizedCommand(config.commands["claude"], fallback: "claude")
        return result
    }

    private static func normalizedCommand(_ command: String?, fallback: String) -> String {
        let trimmed = command?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func dedupeExistingDirectories(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for path in paths {
            let normalized = NSString(string: path).expandingTildeInPath
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: normalized, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            if seen.insert(normalized).inserted {
                result.append(normalized)
            }
        }

        return result
    }
}

final class LauncherViewController: NSViewController {
    private var config = ConfigStore.load()
    private var selectedProject: String?

    private let projectPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let codexCommandField = NSTextField(string: "")
    private let claudeCommandField = NSTextField(string: "")
    private let statusLabel = NSTextField(labelWithString: "选择一个项目目录，然后直接打开 Codex 或 Claude Code。")
    private let pinButton = NSButton(title: "收藏当前项目", target: nil, action: nil)
    private let revealButton = NSButton(title: "在 Finder 中显示", target: nil, action: nil)
    private let codexButton = NSButton(title: "用 Codex 打开", target: nil, action: nil)
    private let claudeButton = NSButton(title: "用 Claude Code 打开", target: nil, action: nil)

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 360))
        buildUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        codexCommandField.stringValue = config.commands["codex"] ?? "codex"
        claudeCommandField.stringValue = config.commands["claude"] ?? "claude"
        refreshProjectMenu(preferredSelection: nil)
    }

    private func buildUI() {
        let titleLabel = NSTextField(labelWithString: "AI Code Launcher")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)

        let subtitleLabel = NSTextField(labelWithString: "少做三件事：找文件夹、切目录、再敲启动命令。")
        subtitleLabel.textColor = .secondaryLabelColor

        let projectLabel = NSTextField(labelWithString: "项目目录")
        projectLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        projectPopup.target = self
        projectPopup.action = #selector(projectSelectionChanged(_:))
        projectPopup.translatesAutoresizingMaskIntoConstraints = false
        projectPopup.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let chooseButton = NSButton(title: "选择文件夹...", target: self, action: #selector(chooseFolder(_:)))
        revealButton.target = self
        revealButton.action = #selector(revealInFinder(_:))
        pinButton.target = self
        pinButton.action = #selector(togglePin(_:))

        let projectButtons = NSStackView(views: [chooseButton, revealButton, pinButton])
        projectButtons.orientation = .horizontal
        projectButtons.spacing = 10
        projectButtons.distribution = .fillEqually

        let codexFieldRow = labeledRow(label: "Codex 命令", field: codexCommandField)
        let claudeFieldRow = labeledRow(label: "Claude 命令", field: claudeCommandField)

        let saveSettingsButton = NSButton(title: "保存设置", target: self, action: #selector(saveSettings(_:)))
        codexButton.target = self
        codexButton.action = #selector(openInCodex(_:))
        claudeButton.target = self
        claudeButton.action = #selector(openInClaude(_:))

        let launchButtons = NSStackView(views: [codexButton, claudeButton, saveSettingsButton])
        launchButtons.orientation = .horizontal
        launchButtons.spacing = 10
        launchButtons.distribution = .fillEqually

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let contentStack = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            spacer(height: 8),
            projectLabel,
            projectPopup,
            projectButtons,
            spacer(height: 8),
            codexFieldRow,
            claudeFieldRow,
            spacer(height: 8),
            launchButtons,
            spacer(height: 6),
            statusLabel,
        ])
        contentStack.orientation = .vertical
        contentStack.spacing = 12
        contentStack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: view.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ])
    }

    private func labeledRow(label: String, field: NSTextField) -> NSView {
        let title = NSTextField(labelWithString: label)
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.alignment = .right
        title.setContentHuggingPriority(.required, for: .horizontal)
        title.widthAnchor.constraint(equalToConstant: 92).isActive = true

        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let row = NSStackView(views: [title, field])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    private func spacer(height: CGFloat) -> NSView {
        let spacer = NSView(frame: .zero)
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    private func allProjects() -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for path in config.pinnedProjects + config.recentProjects {
            if seen.insert(path).inserted {
                result.append(path)
            }
        }

        return result
    }

    private func displayName(for path: String) -> String {
        let lastComponent = URL(fileURLWithPath: path).lastPathComponent
        return lastComponent.isEmpty ? path : lastComponent
    }

    private func refreshProjectMenu(preferredSelection: String?) {
        let projects = allProjects()
        projectPopup.removeAllItems()

        if projects.isEmpty {
            projectPopup.addItem(withTitle: "还没有保存过项目目录")
            projectPopup.lastItem?.isEnabled = false
            selectedProject = nil
            updateControls()
            return
        }

        for project in projects {
            let pinnedMark = config.pinnedProjects.contains(project) ? "★ " : ""
            let title = "\(pinnedMark)\(displayName(for: project))    \(project)"
            projectPopup.addItem(withTitle: title)
            projectPopup.lastItem?.representedObject = project
        }

        let targetProject = preferredSelection ?? selectedProject ?? projects.first
        if let targetProject, let index = projects.firstIndex(of: targetProject) {
            projectPopup.selectItem(at: index)
            selectedProject = targetProject
        } else {
            projectPopup.selectItem(at: 0)
            selectedProject = projects.first
        }

        updateControls()
    }

    private func updateControls() {
        let hasProject = selectedProject != nil
        pinButton.isEnabled = hasProject
        revealButton.isEnabled = hasProject
        codexButton.isEnabled = hasProject
        claudeButton.isEnabled = hasProject

        if let selectedProject {
            let isPinned = config.pinnedProjects.contains(selectedProject)
            pinButton.title = isPinned ? "取消收藏当前项目" : "收藏当前项目"
            statusLabel.stringValue = selectedProject
        } else {
            pinButton.title = "收藏当前项目"
            statusLabel.stringValue = "先选一个项目目录。你也可以直接点“选择文件夹...”。"
        }
    }

    private func addRecentProject(_ path: String) {
        config.recentProjects.removeAll { $0 == path }
        config.recentProjects.insert(path, at: 0)
        if config.recentProjects.count > 20 {
            config.recentProjects = Array(config.recentProjects.prefix(20))
        }
        ConfigStore.save(config)
    }

    private func saveCommandFields() {
        config.commands["codex"] = normalizedCommand(codexCommandField.stringValue, fallback: "codex")
        config.commands["claude"] = normalizedCommand(claudeCommandField.stringValue, fallback: "claude")
        ConfigStore.save(config)
    }

    private func normalizedCommand(_ command: String, fallback: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func shellQuoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func launch(tool: String) {
        guard let project = selectedProject else {
            statusLabel.stringValue = "先选一个项目目录。"
            return
        }

        saveCommandFields()
        let command = config.commands[tool] ?? (tool == "codex" ? "codex" : "claude")
        let shellCommand = "cd \(shellQuoted(project)) && \(command)"
        let scriptLines = [
            "tell application \"Terminal\"",
            "activate",
            "do script \"\(appleScriptEscaped(shellCommand))\"",
            "end tell",
        ]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = scriptLines.flatMap { ["-e", $0] }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            statusLabel.stringValue = "启动失败：\(error.localizedDescription)"
            return
        }

        guard process.terminationStatus == 0 else {
            statusLabel.stringValue = "Terminal 启动失败，退出码 \(process.terminationStatus)。"
            return
        }

        addRecentProject(project)
        refreshProjectMenu(preferredSelection: project)
        statusLabel.stringValue = "已在 \(displayName(for: project)) 中启动 \(tool == "codex" ? "Codex" : "Claude Code")。"
    }

    @objc private func chooseFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "选择项目目录"
        panel.message = "选一个项目目录，之后它会出现在最近使用列表里。"

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            selectedProject = path
            addRecentProject(path)
            refreshProjectMenu(preferredSelection: path)
        }
    }

    @objc private func revealInFinder(_ sender: Any?) {
        guard let selectedProject else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: selectedProject)])
    }

    @objc private func togglePin(_ sender: Any?) {
        guard let selectedProject else { return }

        if config.pinnedProjects.contains(selectedProject) {
            config.pinnedProjects.removeAll { $0 == selectedProject }
            statusLabel.stringValue = "已取消收藏 \(displayName(for: selectedProject))。"
        } else {
            config.pinnedProjects.insert(selectedProject, at: 0)
            config.pinnedProjects = Array(NSOrderedSet(array: config.pinnedProjects)) as? [String] ?? config.pinnedProjects
            statusLabel.stringValue = "已收藏 \(displayName(for: selectedProject))。"
        }

        ConfigStore.save(config)
        refreshProjectMenu(preferredSelection: selectedProject)
    }

    @objc private func saveSettings(_ sender: Any?) {
        saveCommandFields()
        statusLabel.stringValue = "命令设置已保存。"
    }

    @objc private func projectSelectionChanged(_ sender: Any?) {
        guard let item = projectPopup.selectedItem,
              let path = item.representedObject as? String else {
            selectedProject = nil
            updateControls()
            return
        }

        selectedProject = path
        updateControls()
    }

    @objc private func openInCodex(_ sender: Any?) {
        launch(tool: "codex")
    }

    @objc private func openInClaude(_ sender: Any?) {
        launch(tool: "claude")
    }
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let viewController = LauncherViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "AI Code Launcher"
        window.contentViewController = viewController
        window.makeKeyAndOrderFront(nil)

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
