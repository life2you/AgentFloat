import Foundation
import CoreGraphics

/// 持久化保存的悬浮窗停靠偏好
public struct SavedPanelPosition: Codable, Equatable, Sendable {
    public var topOffset: CGFloat
    public var horizontalOffset: CGFloat
    public var isRightAligned: Bool
    
    public init(topOffset: CGFloat = 20, horizontalOffset: CGFloat = 20, isRightAligned: Bool = true) {
        self.topOffset = topOffset
        self.horizontalOffset = horizontalOffset
        self.isRightAligned = isRightAligned
    }
}

/// 悬浮窗几何计算器：支持屏幕边缘磁吸吸附、顶部对齐锚点与多分辨率自适应
public struct PanelGeometryHelper: Sendable {
    /// 触发边缘吸附的磁吸判定阈值 (点数)
    public static let snapThreshold: CGFloat = 30
    /// 吸附至屏幕边缘时的安全内边距
    public static let edgePadding: CGFloat = 16
    
    /// 根据保存的位置偏好和当前内容尺寸计算目标 Frame (以顶部 Top 为锚点，向下自适应延伸)
    public static func calculateFrame(
        saved: SavedPanelPosition,
        contentWidth: CGFloat,
        contentHeight: CGFloat,
        visibleFrame: CGRect
    ) -> CGRect {
        let x: CGFloat
        if saved.isRightAligned {
            x = visibleFrame.maxX - contentWidth - saved.horizontalOffset
        } else {
            x = visibleFrame.minX + saved.horizontalOffset
        }
        
        let topY = visibleFrame.maxY - saved.topOffset
        var y = topY - contentHeight
        
        // 垂直防越界：若延伸超出屏幕底部，自动上推贴紧底部
        let minY = visibleFrame.minY + edgePadding
        let maxY = visibleFrame.maxY - contentHeight - edgePadding
        if y < minY {
            y = minY
        }
        if y > maxY {
            y = maxY
        }
        
        // 水平防越界
        let minX = visibleFrame.minX + edgePadding
        let maxX = visibleFrame.maxX - contentWidth - edgePadding
        let clampedX = min(max(x, minX), maxX)
        
        return CGRect(x: clampedX, y: y, width: contentWidth, height: contentHeight)
    }
    
    /// 当用户拖拽停靠后，计算边缘磁吸后的 Frame 及最新的相对位置偏好
    public static func snapAndComputePosition(
        currentFrame: CGRect,
        visibleFrame: CGRect,
        snapThreshold: CGFloat = snapThreshold,
        edgePadding: CGFloat = edgePadding
    ) -> (snappedFrame: CGRect, position: SavedPanelPosition) {
        var x = currentFrame.origin.x
        var y = currentFrame.origin.y
        let w = currentFrame.width
        let h = currentFrame.height
        
        // 1. 水平轴磁力吸附
        let distLeft = currentFrame.minX - visibleFrame.minX
        let distRight = visibleFrame.maxX - currentFrame.maxX
        
        var isRightAligned = (distRight < distLeft)
        
        if distLeft < snapThreshold {
            x = visibleFrame.minX + edgePadding
            isRightAligned = false
        } else if distRight < snapThreshold {
            x = visibleFrame.maxX - w - edgePadding
            isRightAligned = true
        } else {
            // 未触发吸附时 clamp 到屏幕安全区
            let minAllowedX = visibleFrame.minX + edgePadding
            let maxAllowedX = visibleFrame.maxX - w - edgePadding
            x = min(max(x, minAllowedX), maxAllowedX)
        }
        
        // 2. 垂直轴磁力吸附
        let distTop = visibleFrame.maxY - currentFrame.maxY
        let distBottom = currentFrame.minY - visibleFrame.minY
        
        if distTop < snapThreshold {
            y = visibleFrame.maxY - h - edgePadding
        } else if distBottom < snapThreshold {
            y = visibleFrame.minY + edgePadding
        } else {
            // 未触发吸附时 clamp 到屏幕安全区
            let minAllowedY = visibleFrame.minY + edgePadding
            let maxAllowedY = visibleFrame.maxY - h - edgePadding
            y = min(max(y, minAllowedY), maxAllowedY)
        }
        
        let snappedFrame = CGRect(x: x, y: y, width: w, height: h)
        
        // 3. 计算相对 top 与横向的 offset
        let topOffset = max(0, visibleFrame.maxY - snappedFrame.maxY)
        let horizontalOffset: CGFloat
        if isRightAligned {
            horizontalOffset = max(0, visibleFrame.maxX - snappedFrame.maxX)
        } else {
            horizontalOffset = max(0, snappedFrame.minX - visibleFrame.minX)
        }
        
        let position = SavedPanelPosition(
            topOffset: topOffset,
            horizontalOffset: horizontalOffset,
            isRightAligned: isRightAligned
        )
        
        return (snappedFrame, position)
    }
}
