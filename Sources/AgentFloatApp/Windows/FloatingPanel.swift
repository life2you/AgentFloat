import AppKit
import SwiftUI
import AgentFloatCore

public final class FloatingPanel: NSPanel {
    private var hasCustomPosition = false
    public let taskManager: TaskManager
    private var hostingView: NSHostingView<FloatingCardView>?
    
    public init(taskManager: TaskManager) {
        self.taskManager = taskManager
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 200),
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
    }
    
    public func updateVisibility() {
        if taskManager.undismissedTasks.isEmpty {
            self.orderOut(nil)
            return
        }
        
        guard let hosting = self.hostingView else { return }
        let fittingSize = hosting.fittingSize
        let finalWidth: CGFloat = 390
        let finalHeight = min(max(fittingSize.height, 120), 480)
        
        if !hasCustomPosition {
            positionAtTopRight(width: finalWidth, height: finalHeight)
        } else {
            let currentOrigin = self.frame.origin
            self.setFrame(NSRect(x: currentOrigin.x, y: currentOrigin.y, width: finalWidth, height: finalHeight), display: true)
        }
        
        self.orderFrontRegardless()
    }
    
    public func showCard(task: AgentTask, taskManager: TaskManager) {
        updateVisibility()
    }
    
    public func hideCard() {
        self.orderOut(nil)
    }
    
    private func positionAtTopRight(width: CGFloat, height: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let padding: CGFloat = 20
        let x = visibleFrame.maxX - width - padding
        let y = visibleFrame.maxY - height - padding
        
        self.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
