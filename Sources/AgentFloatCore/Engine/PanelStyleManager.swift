import Foundation
import Combine

/// 悬浮窗展示样式模式
public enum FloatingPanelStyle: String, Codable, Sendable, CaseIterable {
    /// 灵动岛模式（屏幕顶端刘海融合形态，支持紧凑刘海 / 实时横幅弹出 / 悬停展开工作台三态）
    case dynamicIsland = "dynamicIsland"
    /// 经典卡片模式（可拖拽、边缘磁吸的悬浮卡片）
    case card = "card"
    
    public var displayName: String {
        switch self {
        case .dynamicIsland:
            return "灵动岛"
        case .card:
            return "经典卡片"
        }
    }
    
    public var iconName: String {
        switch self {
        case .dynamicIsland:
            return "capsule.inset.filled"
        case .card:
            return "macwindow.on.rectangle"
        }
    }
}

/// 灵动岛展开状态
public enum DynamicIslandState: String, Sendable, Equatable {
    /// 紧凑刘海态（贴合屏幕顶端，左右双翼显示脉冲波形、来源与待核对徽章）
    case collapsed
    /// 新任务到达时的实时活动横幅态（iOS 灵动岛大胶囊风格，数秒后自动缩回刘海）
    case peeking
    /// 悬停或点击展开的完整工作台态（Bento 仪表盘布局）
    case expanded
}

/// 悬浮窗样式与灵动岛状态管理器
@MainActor
public final class PanelStyleManager: ObservableObject {
    public static let shared = PanelStyleManager()
    public static let styleStorageKey = "AgentFloat_FloatingPanelStyle"
    
    @Published public var style: FloatingPanelStyle {
        didSet {
            guard oldValue != style else { return }
            UserDefaults.standard.set(style.rawValue, forKey: Self.styleStorageKey)
            if style == .dynamicIsland {
                isPinned = false
                islandState = .collapsed
            }
            onStyleOrStateChanged?()
        }
    }
    
    @Published public var islandState: DynamicIslandState = .collapsed {
        didSet {
            guard oldValue != islandState else { return }
            if islandState != .peeking {
                cancelPeekTimer()
            }
            onStyleOrStateChanged?()
        }
    }
    
    /// 是否由用户点击固定展开（固定时不随鼠标移出自动收起）
    @Published public var isPinned: Bool = false
    
    @Published public var isHovering: Bool = false {
        didSet {
            guard oldValue != isHovering else { return }
            handleHoverChanged(isHovering)
        }
    }
    
    /// 当样式或灵动岛尺寸状态变化时通知窗口重算 Frame
    public var onStyleOrStateChanged: (() -> Void)?
    
    private var peekCollapseTask: Task<Void, Never>?
    private var hoverRetractTask: Task<Void, Never>?
    private var lastKnownTopTaskKey: String?
    
    public init(userDefaults: UserDefaults = .standard) {
        if let raw = userDefaults.string(forKey: Self.styleStorageKey),
           let saved = FloatingPanelStyle(rawValue: raw) {
            self.style = saved
        } else {
            self.style = .dynamicIsland
        }
    }
    
    /// 切换悬浮窗模式（灵动岛 <-> 经典卡片）
    public func toggleStyle() {
        style = (style == .dynamicIsland) ? .card : .dynamicIsland
    }
    
    /// 当任务列表更新时触发：若有新任务或任务更新，灵动岛自动进入 peeking 预览态
    public func handleTasksUpdated(_ tasks: [AgentTask]) {
        guard !tasks.isEmpty else {
            lastKnownTopTaskKey = nil
            isPinned = false
            cancelPeekTimer()
            cancelHoverTimer()
            if islandState != .collapsed {
                islandState = .collapsed
            }
            return
        }
        
        let top = tasks[0]
        let currentKey = "\(top.id)_\(Int(top.updatedAt.timeIntervalSince1970))_\(tasks.count)"
        let isNewOrUpdated = (lastKnownTopTaskKey != nil && lastKnownTopTaskKey != currentKey) || (lastKnownTopTaskKey == nil)
        lastKnownTopTaskKey = currentKey
        
        guard style == .dynamicIsland else { return }
        
        if isNewOrUpdated && islandState == .collapsed {
            triggerPeek()
        } else if islandState == .peeking && !isHovering {
            scheduleAutoCollapse(after: 4.5)
        }
    }
    
    /// 手动触发灵动岛预览展开并在超时后收起
    public func triggerPeek(duration: TimeInterval = 4.5) {
        guard style == .dynamicIsland else { return }
        if islandState != .expanded {
            islandState = .peeking
            if !isHovering {
                scheduleAutoCollapse(after: duration)
            }
        }
    }
    
    /// 展开灵动岛完整工作台
    public func expandIsland(pin: Bool = false) {
        cancelPeekTimer()
        cancelHoverTimer()
        if pin {
            isPinned = true
        }
        islandState = .expanded
    }
    
    /// 收起灵动岛为顶部紧凑刘海
    public func collapseIsland() {
        isPinned = false
        cancelPeekTimer()
        cancelHoverTimer()
        islandState = .collapsed
    }
    
    private func handleHoverChanged(_ hovering: Bool) {
        guard style == .dynamicIsland else { return }
        if hovering {
            cancelPeekTimer()
            cancelHoverTimer()
            // 鼠标移入顶部刘海时，平滑展开工作台
            if islandState == .collapsed {
                hoverRetractTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    guard !Task.isCancelled, let self = self, self.isHovering else { return }
                    self.islandState = .expanded
                }
            }
        } else {
            cancelHoverTimer()
            if !isPinned {
                hoverRetractTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 380_000_000)
                    guard !Task.isCancelled, let self = self, !self.isHovering, !self.isPinned else { return }
                    self.islandState = .collapsed
                }
            }
        }
    }
    
    private func scheduleAutoCollapse(after seconds: TimeInterval) {
        cancelPeekTimer()
        peekCollapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled, let self = self else { return }
            if self.islandState == .peeking && !self.isHovering && !self.isPinned {
                self.islandState = .collapsed
            }
        }
    }
    
    private func cancelPeekTimer() {
        peekCollapseTask?.cancel()
        peekCollapseTask = nil
    }
    
    private func cancelHoverTimer() {
        hoverRetractTask?.cancel()
        hoverRetractTask = nil
    }
}
