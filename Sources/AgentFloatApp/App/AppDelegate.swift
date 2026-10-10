import AppKit
import SwiftUI
import Combine
import AgentFloatCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
    private var taskStore: SQLiteTaskStore!
    private var taskManager: TaskManager!
    private var httpServer: LocalHttpServer!
    private var floatingPanel: FloatingPanel!
    
    private var cancellables = Set<AnyCancellable>()
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为后台常驻 Accessory 应用（不显示在 Dock 中，专属于菜单栏）
        NSApp.setActivationPolicy(.accessory)
        
        do {
            // 初始化 SQLite 存储与任务管理器
            let store = try SQLiteTaskStore()
            self.taskStore = store
            
            let manager = TaskManager(store: store)
            self.taskManager = manager
            
            // 初始化悬浮卡片面板
            let panel = FloatingPanel(taskManager: manager)
            self.floatingPanel = panel
            
            // 绑定悬浮卡片展示联动（多任务聚合列表）
            manager.onTasksChanged = { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.floatingPanel.updateVisibility()
                }
            }
            
            manager.onCardTaskChanged = { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.floatingPanel.updateVisibility()
                }
            }
            
            // 启动本地 HTTP 服务
            let serverPort = LocalHttpServer.configuredPort
            let server = LocalHttpServer(port: serverPort, taskManager: manager)
            try server.start()
            self.httpServer = server
            
            // 自动检测并无感接入本地 Agent 生态 (Codex 与 Pi Agent 零配置一键直连)
            Task.detached(priority: .utility) {
                let status = AutoIntegrationManager.autoSetupAll()
                for msg in status.messages {
                    print("[AutoIntegration] \(msg)")
                }
            }
            
            // 初始加载历史任务
            Task {
                await manager.loadTasks()
            }
            
            // 初始化菜单栏状态项与弹出框
            setupStatusItem()
            setupPopover()
            bindTaskManager()
            
        } catch {
            print("[AgentFloatApp] 启动失败: \(error)")
            let alert = NSAlert()
            alert.messageText = "AgentFloat 启动失败"
            alert.informativeText = "无法初始化本地数据库或本地网络服务: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.runModal()
            NSApp.terminate(nil)
        }
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        httpServer?.stop()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: "AgentFloat")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        updateBadge(count: 0)
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 320)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(taskManager: taskManager, serverPort: httpServer?.port ?? LocalHttpServer.defaultPort)
        )
    }
    
    private func bindTaskManager() {
        taskManager.$pendingTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pending in
                self?.updateBadge(count: pending.count)
            }
            .store(in: &cancellables)
    }
    
    private func updateBadge(count: Int) {
        guard let button = statusItem?.button else { return }
        if count > 0 {
            button.title = " \(count)"
            button.image = NSImage(systemSymbolName: "macwindow.badge.plus", accessibilityDescription: "AgentFloat (\(count))")
        } else {
            button.title = ""
            button.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: "AgentFloat")
        }
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
