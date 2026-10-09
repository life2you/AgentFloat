import AppKit
import SwiftUI
import AgentFloatCore

public final class FloatingPanel: NSPanel {
    private var hasCustomPosition = false
    
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
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
    }
    
    public func showCard(task: AgentTask, taskManager: TaskManager) {
        let cardView = FloatingCardView(task: task, taskManager: taskManager)
        let hostingView = NSHostingView(rootView: cardView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        self.contentView = hostingView
        
        let fittingSize = hostingView.fittingSize
        let finalWidth: CGFloat = 380
        let finalHeight = max(fittingSize.height, 180)
        
        if !hasCustomPosition {
            positionAtTopRight(width: finalWidth, height: finalHeight)
        } else {
            let currentOrigin = self.frame.origin
            self.setFrame(NSRect(x: currentOrigin.x, y: currentOrigin.y, width: finalWidth, height: finalHeight), display: true)
        }
        
        self.orderFrontRegardless()
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
