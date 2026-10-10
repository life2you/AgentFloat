import AppKit
import SwiftUI
import AgentFloatCore

public final class FloatingPanel: NSPanel {
    private static let positionStorageKey = "AgentFloat_FloatingPanelPosition"
    
    public let taskManager: TaskManager
    private var hostingView: NSHostingView<FloatingCardView>?
    private var moveDebounceWorkItem: DispatchWorkItem?
    private var isSnapping = false
    
    public init(taskManager: TaskManager) {
        self.taskManager = taskManager
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 180),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isFloatingPanel = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        
        let cardView = FloatingCardView(taskManager: taskManager)
        let hosting = NSHostingView(rootView: cardView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        self.hostingView = hosting
        self.contentView = hosting
        
        // 监听窗口移动，实现拖拽停止后的自动防抖吸附与位置记忆
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMoveHandler),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override public var canBecomeKey: Bool {
        return true
    }
    
    override public var canBecomeMain: Bool {
        return false
    }
    
    override public func sendEvent(_ event: NSEvent) {
        super.sendEvent(event)
        // 用户鼠标松开拖动时，立即触发边缘磁吸与位置持久化
        if event.type == .leftMouseUp && self.isVisible {
            moveDebounceWorkItem?.cancel()
            snapToNearestEdgeAndSave(animated: true)
        }
    }
    
    public func updateVisibility() {
        if taskManager.undismissedTasks.isEmpty {
            self.orderOut(nil)
            return
        }
        
        guard let hosting = self.hostingView else { return }
        let fittingSize = hosting.fittingSize
        let finalWidth: CGFloat = 350
        let finalHeight = min(max(fittingSize.height, 90), 420)
        
        guard let screen = self.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            self.orderFrontRegardless()
            return
        }
        
        let savedPosition = loadSavedPosition()
        let targetFrame = PanelGeometryHelper.calculateFrame(
            saved: savedPosition,
            contentWidth: finalWidth,
            contentHeight: finalHeight,
            visibleFrame: screen.visibleFrame
        )
        
        self.setFrame(targetFrame, display: true)
        self.orderFrontRegardless()
    }
    
    public func showCard(task: AgentTask, taskManager: TaskManager) {
        updateVisibility()
    }
    
    public func hideCard() {
        self.orderOut(nil)
    }
    
    @objc private func windowDidMoveHandler() {
        guard self.isVisible, !isSnapping else { return }
        moveDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.snapToNearestEdgeAndSave(animated: true)
        }
        self.moveDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }
    
    /// 执行屏幕边缘磁吸并保存位置偏好
    public func snapToNearestEdgeAndSave(animated: Bool = true) {
        guard !isSnapping else { return }
        guard let screen = self.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        
        let visibleFrame = screen.visibleFrame
        let currentFrame = self.frame
        
        let (snappedFrame, newPosition) = PanelGeometryHelper.snapAndComputePosition(
            currentFrame: currentFrame,
            visibleFrame: visibleFrame
        )
        
        savePosition(newPosition)
        
        if snappedFrame != currentFrame {
            self.isSnapping = true
            if animated {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.18
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    self.animator().setFrame(snappedFrame, display: true)
                }, completionHandler: { [weak self] in
                    self?.isSnapping = false
                })
            } else {
                self.setFrame(snappedFrame, display: true)
                self.isSnapping = false
            }
        }
    }
    
    // MARK: - 持久化
    
    private func loadSavedPosition() -> SavedPanelPosition {
        if let data = UserDefaults.standard.data(forKey: Self.positionStorageKey),
           let pos = try? JSONDecoder().decode(SavedPanelPosition.self, from: data) {
            return pos
        }
        return SavedPanelPosition(topOffset: 20, horizontalOffset: 20, isRightAligned: true)
    }
    
    private func savePosition(_ position: SavedPanelPosition) {
        if let data = try? JSONEncoder().encode(position) {
            UserDefaults.standard.set(data, forKey: Self.positionStorageKey)
        }
    }
}
