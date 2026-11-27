import AppKit
import ServiceManagement

// 菜单栏一键切换显示器输入源的小应用（LSUIElement，无 Dock 图标）
// 切换逻辑全部在 Resources/switch_hdmi.sh 中，本应用只负责界面与调用
//
// 重要设计约束：菜单结构在启动时一次性构建（输入源列表加载后插入一次），
// 之后只"原地"更新标题/勾选状态，绝不在菜单打开期间增删条目，
// 否则 NSMenu 跟踪会立即关闭，表现为"点击没反应"。

struct InputSource {
    let code: String
    let label: String
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var toggleItem: NSMenuItem!
    private var statusRow: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var inputRows: [NSMenuItem] = []
    private var inputs: [InputSource] = []
    private var currentCode: String?
    private var readingCurrent = false

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "HDMI 切换") {
                button.image = img
            } else {
                button.title = "⇄"
            }
        }

        menu.autoenablesItems = false
        menu.delegate = self

        toggleItem = NSMenuItem(title: "一键切换", action: #selector(toggleInput(_:)), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.isEnabled = true
        menu.addItem(toggleItem)

        statusRow = NSMenuItem(title: "当前输入: 读取中…", action: nil, keyEquivalent: "")
        statusRow.isEnabled = false
        menu.addItem(statusRow)

        menu.addItem(.separator())

        loginItem = NSMenuItem(title: "开机自启", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        refreshInputs()
        refreshCurrent()
    }

    // MARK: - 菜单：只做原地刷新，不改结构

    func menuWillOpen(_ menu: NSMenu) {
        updateCurrentDisplay()
        refreshCurrent()
    }

    // MARK: - 数据刷新

    private func refreshInputs() {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let output = runScript(args: ["list"])
            let list = output.split(separator: "\n").compactMap { line -> InputSource? in
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return InputSource(code: String(parts[0]), label: String(parts[1]))
            }
            guard !list.isEmpty else { return }
            DispatchQueue.main.async {
                self.inputs = list
                self.rebuildInputRows()
            }
        }
    }

    private func refreshCurrent() {
        guard !readingCurrent else { return }
        readingCurrent = true
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let output = runScript(args: ["current"]).trimmingCharacters(in: .whitespacesAndNewlines)
            let code = output.isEmpty ? nil : output
            DispatchQueue.main.async {
                self.readingCurrent = false
                self.currentCode = code
                self.updateCurrentDisplay()
            }
        }
    }

    // MARK: - 原地更新（不增删条目）

    private func rebuildInputRows() {
        for row in inputRows { menu.removeItem(row) }
        inputRows = []
        let insertIndex = menu.index(of: statusRow) + 1
        for input in inputs {
            let row = NSMenuItem(title: input.label, action: #selector(switchTo(_:)), keyEquivalent: "")
            row.target = self
            row.isEnabled = true
            row.representedObject = input.code
            menu.insertItem(row, at: insertIndex)
            inputRows.append(row)
        }
        updateCurrentDisplay()
    }

    private func updateCurrentDisplay() {
        let text: String
        if readingCurrent {
            text = "当前输入: 读取中…"
        } else if let code = currentCode {
            let label = inputs.first(where: { $0.code == code })?.label ?? "输入 \(code)"
            text = "当前输入: \(label)"
        } else {
            text = "当前输入: 读取失败"
        }
        statusRow.title = text
        for row in inputRows {
            row.state = (row.representedObject as? String) == currentCode ? .on : .off
        }
    }

    // MARK: - 动作

    @objc private func toggleInput(_ sender: NSMenuItem) {
        DispatchQueue.global().async { [weak self] in
            _ = runScript(args: ["toggle"])
            DispatchQueue.main.async { self?.refreshCurrent() }
        }
    }

    @objc private func switchTo(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        DispatchQueue.global().async { [weak self] in
            _ = runScript(args: [code])
            DispatchQueue.main.async { self?.refreshCurrent() }
        }
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "设置开机自启失败"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        sender.state = service.status == .enabled ? .on : .off
    }
}

// 顶层脚本调用（后台线程使用），带超时保护：显示器无响应时 m1ddc 可能长时间卡住
private func runScript(args: [String], timeout: TimeInterval = 5) -> String {
    let bundleScript = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/switch_hdmi.sh")
    let process = Process()
    process.executableURL = bundleScript
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
    } catch {
        return ""
    }
    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning && Date() < deadline {
        Thread.sleep(forTimeInterval: 0.1)
    }
    if process.isRunning {
        process.terminate()
        Thread.sleep(forTimeInterval: 0.2)
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        process.waitUntilExit()
        return ""
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
