import Testing
import CoreGraphics
@testable import AgentFloatCore

@Suite("PanelGeometryHelper Tests")
struct PanelGeometryHelperTests {
    
    let sampleScreen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    
    @Test("默认右上角计算")
    func defaultTopRightCalculation() {
        let defaultPos = SavedPanelPosition(topOffset: 20, horizontalOffset: 20, isRightAligned: true)
        let frame = PanelGeometryHelper.calculateFrame(
            saved: defaultPos,
            contentWidth: 350,
            contentHeight: 180,
            visibleFrame: sampleScreen
        )
        
        #expect(frame.width == 350.0)
        #expect(frame.height == 180.0)
        // 右边距: 1920 - 350 - 20 = 1550
        #expect(frame.origin.x == 1550.0)
        // 顶部锚点: 1080 - 20 = 1060; y = 1060 - 180 = 880
        #expect(frame.origin.y == 880.0)
    }
    
    @Test("靠左对齐计算与向下延伸")
    func leftAlignedCalculation() {
        let leftPos = SavedPanelPosition(topOffset: 30, horizontalOffset: 16, isRightAligned: false)
        let frame1 = PanelGeometryHelper.calculateFrame(
            saved: leftPos,
            contentWidth: 350,
            contentHeight: 100,
            visibleFrame: sampleScreen
        )
        #expect(frame1.origin.x == 16.0)
        #expect(frame1.origin.y == 950.0)
        #expect(frame1.maxY == 1050.0)
        
        // 当内容高度从 100 增加到 250 时，顶部 maxY 保持不变 (Top Anchor)，向下自适应延伸
        let frame2 = PanelGeometryHelper.calculateFrame(
            saved: leftPos,
            contentWidth: 350,
            contentHeight: 250,
            visibleFrame: sampleScreen
        )
        #expect(frame2.origin.x == 16.0)
        #expect(frame2.maxY == 1050.0)
        #expect(frame2.origin.y == 800.0)
    }
    
    @Test("屏幕右上边缘吸附")
    func snapToTopRightEdge() {
        // 用户拖拽到离右边 10pt、离上边 12pt 的位置 (小于阈值 30pt)
        let draggedFrame = CGRect(x: 1560, y: 888, width: 350, height: 180)
        let (snapped, pos) = PanelGeometryHelper.snapAndComputePosition(
            currentFrame: draggedFrame,
            visibleFrame: sampleScreen
        )
        
        // 自动吸附至 edgePadding (16pt)
        #expect(snapped.maxX == 1920.0 - 16.0)
        #expect(snapped.maxY == 1080.0 - 16.0)
        #expect(pos.isRightAligned == true)
        #expect(pos.horizontalOffset == 16.0)
        #expect(pos.topOffset == 16.0)
    }
    
    @Test("屏幕左下边缘吸附")
    func snapToBottomLeftEdge() {
        // 用户拖拽到离左边 8pt、离底边 15pt
        let draggedFrame = CGRect(x: 8, y: 15, width: 350, height: 180)
        let (snapped, pos) = PanelGeometryHelper.snapAndComputePosition(
            currentFrame: draggedFrame,
            visibleFrame: sampleScreen
        )
        
        #expect(snapped.minX == 16.0)
        #expect(snapped.minY == 16.0)
        #expect(pos.isRightAligned == false)
        #expect(pos.horizontalOffset == 16.0)
    }
    
    @Test("屏幕中游未触发吸附时安全内缩")
    func nonSnapFreePosition() {
        // 用户放在屏幕正中央 (远离任何边缘)
        let centerFrame = CGRect(x: 785, y: 450, width: 350, height: 180)
        let (snapped, pos) = PanelGeometryHelper.snapAndComputePosition(
            currentFrame: centerFrame,
            visibleFrame: sampleScreen
        )
        
        // 保持原位
        #expect(snapped.origin.x == 785)
        #expect(snapped.origin.y == 450)
        #expect(!pos.horizontalOffset.isZero)
    }
    
    @Test("屏幕防越界保护")
    func outOfBoundsClamping() {
        // 用户不小心拖出屏幕之外
        let outFrame = CGRect(x: 1850, y: -50, width: 350, height: 180)
        let (snapped, _) = PanelGeometryHelper.snapAndComputePosition(
            currentFrame: outFrame,
            visibleFrame: sampleScreen
        )
        
        // 必须被完全限制在屏幕安全区内
        #expect(snapped.maxX <= 1920 - 16)
        #expect(snapped.minY >= 16)
    }
}
