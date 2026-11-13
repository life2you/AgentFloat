import SwiftUI
import AgentFloatCore

public struct FloatingCardView: View {
    @ObservedObject public var taskManager: TaskManager
    @ObservedObject public var styleManager: PanelStyleManager
    public var previewTask: AgentTask?
    
    public init(
        taskManager: TaskManager,
        styleManager: PanelStyleManager = .shared,
        previewTask: AgentTask? = nil
    ) {
        self.taskManager = taskManager
        self.styleManager = styleManager
        self.previewTask = previewTask
    }
    
    public init(
        task: AgentTask,
        taskManager: TaskManager,
        styleManager: PanelStyleManager = .shared
    ) {
        self.taskManager = taskManager
        self.styleManager = styleManager
        self.previewTask = task
    }
    
    private var tasksToDisplay: [AgentTask] {
        if let preview = previewTask {
            return [preview]
        }
        return taskManager.undismissedTasks
    }
    
    public var body: some View {
        Group {
            switch styleManager.style {
            case .dynamicIsland:
                NotchDynamicIslandView(
                    tasks: tasksToDisplay,
                    taskManager: taskManager,
                    styleManager: styleManager
                )
            case .card:
                classicCardBody
            }
        }
        .onHover { hovering in
            styleManager.isHovering = hovering
        }
    }
    
    // MARK: - 经典卡片模式
    
    private var classicCardBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "macwindow.on.rectangle")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 11, weight: .semibold))
                    Text("待核对任务")
                        .font(.system(size: 11, weight: .bold))
                    
                    Text("\(tasksToDisplay.count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                .help("AgentFloat v\(AgentFloatVersion.current)")
                
                Spacer()
                
                if tasksToDisplay.count > 1 {
                    Button(action: {
                        Task {
                            try? await taskManager.markAllResolved()
                        }
                    }) {
                        Text("全部已处理")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("标记列表中所有任务为已处理")
                }
                
                Button(action: {
                    styleManager.style = .dynamicIsland
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "capsule.inset.filled")
                            .font(.system(size: 9, weight: .semibold))
                        Text("灵动岛")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("切换为顶部刘海灵动岛模式")
                
                Button(action: {
                    Task {
                        try? await taskManager.dismissAllCards()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("关闭全部卡片 (保留在菜单栏待办中)")
            }
            .padding(.horizontal, 10)
            .padding(.top, 7)
            .padding(.bottom, 6)
            
            Divider()
                .opacity(0.5)
            
            if tasksToDisplay.isEmpty {
                VStack(spacing: 4) {
                    Text("暂无待核对任务")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                ScrollView(.vertical, showsIndicators: tasksToDisplay.count > 3) {
                    LazyVStack(spacing: 5) {
                        ForEach(tasksToDisplay) { item in
                            UltraCompactTaskRow(task: item, taskManager: taskManager)
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 360)
            }
        }
        .frame(width: 350)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.18), value: tasksToDisplay)
    }
}

// MARK: - 屏幕顶边无缝刘海几何形状 (带顶部内凹双耳弧角)

private struct NotchIslandShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        let tr = min(topCornerRadius, rect.width / 4, rect.height / 2)
        let br = min(bottomCornerRadius, rect.width / 3, rect.height / 2)
        
        var path = Path()
        // 从左上角顶点出发 (贴合屏幕最顶端 y = 0)
        path.move(to: CGPoint(x: 0, y: 0))
        
        // 左上内凹耳弧：从 (0, 0) 向右下平滑弯入 (tr, tr)
        path.addQuadCurve(
            to: CGPoint(x: tr, y: tr),
            control: CGPoint(x: tr, y: 0)
        )
        
        // 左侧垂直边向下至左下圆角起点
        path.addLine(to: CGPoint(x: tr, y: rect.height - br))
        
        // 左下外凸圆角：从 (tr, height - br) 到 (tr + br, height)
        path.addQuadCurve(
            to: CGPoint(x: tr + br, y: rect.height),
            control: CGPoint(x: tr, y: rect.height)
        )
        
        // 底边水平向右
        path.addLine(to: CGPoint(x: rect.width - tr - br, y: rect.height))
        
        // 右下外凸圆角
        path.addQuadCurve(
            to: CGPoint(x: rect.width - tr, y: rect.height - br),
            control: CGPoint(x: rect.width - tr, y: rect.height)
        )
        
        // 右侧垂直边向上至右上内凹耳弧起点
        path.addLine(to: CGPoint(x: rect.width - tr, y: tr))
        
        // 右上内凹耳弧：从 (width - tr, tr) 向右上平滑贴回屏幕顶边 (width, 0)
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: 0),
            control: CGPoint(x: rect.width - tr, y: 0)
        )
        
        path.closeSubpath()
        return path
    }
}

/// 仅沿刘海侧边与底边绘制微光描边（顶部完全贴合黑边不封口）
private struct NotchBottomGlowStrokeShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let tr = min(topCornerRadius, rect.width / 4, rect.height / 2)
        let br = min(bottomCornerRadius, rect.width / 3, rect.height / 2)
        
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: tr, y: tr), control: CGPoint(x: tr, y: 0))
        path.addLine(to: CGPoint(x: tr, y: rect.height - br))
        path.addQuadCurve(to: CGPoint(x: tr + br, y: rect.height), control: CGPoint(x: tr, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width - tr - br, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: rect.width - tr, y: rect.height - br), control: CGPoint(x: rect.width - tr, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width - tr, y: tr))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: 0), control: CGPoint(x: rect.width - tr, y: 0))
        return path
    }
}

// MARK: - 灵动岛动态声波与呼吸光环组件

private struct LiveWaveformView: View {
    let color: Color
    @State private var phase: Bool = false
    
    var body: some View {
        HStack(spacing: 2.2) {
            ForEach(0..<4, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(
                        width: 2.4,
                        height: barHeight(for: idx)
                    )
            }
        }
        .frame(height: 13)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.65)
                .repeatForever(autoreverses: true)
            ) {
                phase = true
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        switch index {
        case 0: return phase ? 11 : 5
        case 1: return phase ? 5 : 13
        case 2: return phase ? 13 : 6
        default: return phase ? 6 : 10
        }
    }
}

private struct CameraLensIndicator: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.08, green: 0.09, blue: 0.13))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
            Circle()
                .fill(Color(red: 0.18, green: 0.35, blue: 0.65).opacity(0.55))
                .frame(width: 4, height: 4)
                .offset(x: -1, y: -1)
        }
    }
}

private struct AgentEmblemOrb: View {
    let task: AgentTask
    let color: Color
    var size: CGFloat = 42
    @State private var pulse = false
    
    private var sourceSymbol: String {
        switch task.typedSource {
        case .pi: return "sparkles"
        case .codex: return "cpu.fill"
        case .claude: return "brain.head.profile"
        case .dsh: return "bolt.horizontal.circle.fill"
        case .custom: return "terminal.fill"
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(pulse ? 0.45 : 0.12), lineWidth: 2)
                .frame(width: size + 6, height: size + 6)
                .scaleEffect(pulse ? 1.06 : 0.94)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.38),
                            color.opacity(0.10),
                            Color.white.opacity(0.04)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.55), lineWidth: 1.2)
                )
            
            Image(systemName: sourceSymbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(color)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - 全新刘海融合式灵动岛主视图

private struct NotchDynamicIslandView: View {
    let tasks: [AgentTask]
    let taskManager: TaskManager
    @ObservedObject var styleManager: PanelStyleManager
    @State private var selectedTaskId: String?
    
    private var activeTask: AgentTask? {
        if let id = selectedTaskId, let matched = tasks.first(where: { $0.id == id }) {
            return matched
        }
        return tasks.first
    }
    
    private func statusColor(for task: AgentTask?) -> Color {
        guard let task = task else {
            return Color(red: 0.22, green: 0.90, blue: 0.52)
        }
        switch task.status {
        case .completed:
            return Color(red: 0.22, green: 0.90, blue: 0.52)
        case .error, .aborted:
            return Color(red: 1.0, green: 0.32, blue: 0.36)
        case .unknown:
            return Color.orange
        }
    }
    
    private var dominantColor: Color {
        if tasks.contains(where: { $0.status == .error || $0.status == .aborted }) {
            return Color(red: 1.0, green: 0.32, blue: 0.36)
        }
        return statusColor(for: activeTask)
    }
    
    private var topEarRadius: CGFloat {
        switch styleManager.islandState {
        case .collapsed: return 11
        case .peeking: return 13
        case .expanded: return 14
        }
    }
    
    private var bottomRadius: CGFloat {
        switch styleManager.islandState {
        case .collapsed: return 14
        case .peeking: return 18
        case .expanded: return 20
        }
    }
    
    private var totalWidth: CGFloat {
        switch styleManager.islandState {
        case .collapsed: return 276
        case .peeking: return 460
        case .expanded: return 528
        }
    }
    
    fileprivate static func formatDuration(_ durationMs: Int) -> String {
        let seconds = Double(durationMs) / 1000.0
        if seconds >= 60 {
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return secs > 0 ? "\(mins)m\(secs)s" : "\(mins)m"
        }
        return String(format: "%.1fs", seconds)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // 纯黑无缝刘海主体
            NotchIslandShape(
                topCornerRadius: topEarRadius,
                bottomCornerRadius: bottomRadius
            )
            .fill(Color.black)
            .overlay(
                NotchBottomGlowStrokeShape(
                    topCornerRadius: topEarRadius,
                    bottomCornerRadius: bottomRadius
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.02),
                            dominantColor.opacity(0.42),
                            Color.white.opacity(0.14),
                            dominantColor.opacity(0.42),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.0
                )
            )
            
            // 内容区（左右留出顶部内凹耳弧宽度 topEarRadius）
            Group {
                switch styleManager.islandState {
                case .collapsed:
                    collapsedNotchContent
                case .peeking:
                    peekingLiveBannerContent
                case .expanded:
                    expandedBentoStageContent
                }
            }
            .padding(.horizontal, topEarRadius + 10)
        }
        .frame(width: totalWidth)
        .environment(\.colorScheme, .dark)
        .animation(.spring(response: 0.34, dampingFraction: 0.80), value: styleManager.islandState)
        .animation(.easeInOut(duration: 0.2), value: tasks)
    }
    
    // MARK: 1. 紧凑刘海态 (贴合屏幕顶边，左右双翼 + 中央镜头 + 动态声波)
    
    private var collapsedNotchContent: some View {
        HStack(spacing: 8) {
            // 左翼：动态声波 + Agent 来源名
            HStack(spacing: 6) {
                LiveWaveformView(color: dominantColor)
                if let task = activeTask {
                    Text(task.typedSource.displayName)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 6)
            
            // 中央：仿硬件摄像头指示点
            CameraLensIndicator()
            
            Spacer(minLength: 6)
            
            // 右翼：核验提示 + 数量徽章
            HStack(spacing: 5) {
                Text(activeTask?.status == .error ? "待查错" : "待验证")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(dominantColor)
                
                Text("\(tasks.count)")
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 1)
                    .background(dominantColor)
                    .clipShape(Capsule())
            }
        }
        .frame(height: 28)
        .contentShape(Rectangle())
        .onTapGesture {
            styleManager.expandIsland(pin: true)
        }
    }
    
    // MARK: 2. iOS 实时活动横幅态 (Peeking - 超薄单层约 62pt 高)
    
    private var peekingLiveBannerContent: some View {
        VStack(spacing: 3) {
            if let task = activeTask {
                let color = statusColor(for: task)
                let target = TerminalLauncher.detectActiveTerminal(preferred: task.terminalApp, source: task.source)
                
                HStack(spacing: 10) {
                    // 左侧：发光脉冲 Agent 徽标球 (32pt)
                    AgentEmblemOrb(task: task, color: color, size: 32)
                    
                    // 中间：标题 + 醒目核验胶囊（紧凑双行）
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(task.typedSource.displayName)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(color)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(color.opacity(0.16))
                                .clipShape(Capsule())
                            
                            Text(task.title)
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            if let duration = task.durationMs {
                                Text(Self.formatDuration(duration))
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        
                        HStack(spacing: 6) {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                Text(task.verificationNotice)
                                    .font(.system(size: 9, weight: .heavy))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(color)
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                            
                            if let cwd = task.cwd {
                                Text(URL(fileURLWithPath: cwd).lastPathComponent)
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.55))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 右侧：iOS 灵动岛风格双圆形操作键 (30pt)
                    HStack(spacing: 6) {
                        Button(action: {
                            _ = TerminalLauncher.activate(
                                cwd: task.cwd,
                                preferredApp: task.terminalApp,
                                sessionId: task.sessionId,
                                source: task.source
                            )
                            Task {
                                try? await taskManager.resolveTask(id: task.id)
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.14))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                                Image(systemName: target.actionIconName)
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("\(target.actionHelp)并标记为已确认")
                        
                        Button(action: {
                            Task {
                                try? await taskManager.resolveTask(id: task.id)
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11.5, weight: .heavy))
                                    .foregroundColor(.black)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("确认代码已人工核验")
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            styleManager.expandIsland(pin: true)
        }
    }
    
    // MARK: 3. 完整展开紧凑流线舱 (约 96pt 高，顶栏 + 无挤压单层主舱)
    
    private var expandedBentoStageContent: some View {
        let task = activeTask
        let color = statusColor(for: task)
        
        return VStack(spacing: 6) {
            // 顶部超薄刘海翼栏
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    LiveWaveformView(color: dominantColor)
                    Text("AGENT ISLAND")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: true, vertical: false)
                    
                    Text("\(tasks.count)")
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 0.5)
                        .background(dominantColor)
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                    
                    // 若有多条任务，直接在顶栏内联切换胶囊
                    if tasks.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, item in
                                    let isSelected = (item.id == task?.id)
                                    let itemColor = statusColor(for: item)
                                    Button(action: {
                                        selectedTaskId = item.id
                                    }) {
                                        HStack(spacing: 3) {
                                            Circle()
                                                .fill(itemColor)
                                                .frame(width: 4.5, height: 4.5)
                                            Text("#\(idx + 1) \(item.typedSource.displayName)")
                                                .font(.system(size: 8.5, weight: .bold))
                                                .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.65))
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? itemColor.opacity(0.26) : Color.white.opacity(0.08))
                                        )
                                        .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxWidth: 150)
                    }
                }
                
                Spacer(minLength: 4)
                CameraLensIndicator()
                Spacer(minLength: 4)
                
                // 右翼工具簇
                HStack(spacing: 4) {
                    if tasks.count > 1 {
                        Button(action: {
                            Task {
                                try? await taskManager.markAllResolved()
                            }
                        }) {
                            Text("全部核验")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(dominantColor)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(dominantColor.opacity(0.14))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: {
                        styleManager.isPinned.toggle()
                    }) {
                        Image(systemName: styleManager.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(styleManager.isPinned ? dominantColor : .white.opacity(0.55))
                            .padding(4)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(styleManager.isPinned ? "已固定展开（点击改为鼠标移开自动收起）" : "固定展开状态")
                    
                    Button(action: {
                        styleManager.style = .card
                    }) {
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(4)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("切换为经典悬浮窗卡片")
                    
                    Button(action: {
                        styleManager.collapseIsland()
                    }) {
                        Image(systemName: "chevron.compact.up")
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(4)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("收起回顶部刘海")
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(height: 20)
            .padding(.top, 5)
            
            if let current = task {
                let target = TerminalLauncher.detectActiveTerminal(preferred: current.terminalApp, source: current.source)
                
                // 单层一体式横向主舱（去除多余内嵌小框，保证中间文案与右侧按钮绝不挤压变形）
                HStack(spacing: 11) {
                    // 左：发光脉冲徽标球 (34pt)
                    AgentEmblemOrb(task: current, color: color, size: 34)
                        .padding(.leading, 2)
                    
                    // 中：第 1 行 [来源胶囊 + 标题 + 耗时]；第 2 行 [核验警示胶囊 + 目录]
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(current.typedSource.displayName)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(color)
                                .lineLimit(1)
                                .padding(.horizontal, 5.5)
                                .padding(.vertical, 1)
                                .background(color.opacity(0.16))
                                .clipShape(Capsule())
                                .fixedSize(horizontal: true, vertical: false)
                            
                            Text(current.title)
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            if let duration = current.durationMs {
                                Text(Self.formatDuration(duration))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        
                        HStack(spacing: 6) {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .font(.system(size: 8.5, weight: .bold))
                                Text(current.verificationNotice)
                                    .font(.system(size: 9, weight: .heavy))
                                    .lineLimit(1)
                            }
                            .foregroundColor(color)
                            .padding(.horizontal, 6.5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(color.opacity(0.16))
                            )
                            .fixedSize(horizontal: true, vertical: false)
                            
                            if let cwd = current.cwd {
                                HStack(spacing: 2.5) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 8))
                                    Text(URL(fileURLWithPath: cwd).lastPathComponent)
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .lineLimit(1)
                                }
                                .foregroundColor(.white.opacity(0.5))
                                .help(cwd)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 右：固定尺寸不换行的双胶囊按钮 + 隐藏按钮
                    HStack(spacing: 6) {
                        Button(action: {
                            _ = TerminalLauncher.activate(
                                cwd: current.cwd,
                                preferredApp: current.terminalApp,
                                sessionId: current.sessionId,
                                source: current.source
                            )
                            Task {
                                try? await taskManager.resolveTask(id: current.id)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: target.actionIconName)
                                    .font(.system(size: 10, weight: .bold))
                                Text(target.actionTitle)
                                    .font(.system(size: 10, weight: .bold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.14))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .fixedSize(horizontal: true, vertical: false)
                        .help("\(target.actionHelp)并标记为已确认")
                        
                        Button(action: {
                            Task {
                                try? await taskManager.resolveTask(id: current.id)
                            }
                        }) {
                            HStack(spacing: 3.5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10.5, weight: .bold))
                                Text("已验证")
                                    .font(.system(size: 10, weight: .heavy))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(color)
                            )
                        }
                        .buttonStyle(.plain)
                        .fixedSize(horizontal: true, vertical: false)
                        .help("标记为已人工核验通过")
                        
                        Button(action: {
                            Task {
                                try? await taskManager.dismissCard(id: current.id)
                            }
                        }) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.45))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .fixedSize(horizontal: true, vertical: false)
                        .help("暂时隐藏此任务通知")
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(color.opacity(0.28), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.bottom, 8)
    }
}

/// 经典卡片单项任务条目
private struct UltraCompactTaskRow: View {
    let task: AgentTask
    let taskManager: TaskManager
    
    private var themeColor: Color {
        switch task.status {
        case .completed:
            return Color.green
        case .error, .aborted:
            return Color.red
        case .unknown:
            return Color.orange
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Circle()
                    .fill(themeColor)
                    .frame(width: 6, height: 6)
                
                Text(task.typedSource.displayName)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(3)
                
                Text(task.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let duration = task.durationMs {
                    Text("\(Double(duration) / 1000.0, specifier: "%.1f")s")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 4)
                
                let target = TerminalLauncher.detectActiveTerminal(preferred: task.terminalApp, source: task.source)
                
                HStack(spacing: 4) {
                    Button(action: {
                        _ = TerminalLauncher.activate(
                            cwd: task.cwd,
                            preferredApp: task.terminalApp,
                            sessionId: task.sessionId,
                            source: task.source
                        )
                        Task {
                            try? await taskManager.resolveTask(id: task.id)
                        }
                    }) {
                        Image(systemName: target.actionIconName)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(Color.secondary.opacity(0.18))
                            .cornerRadius(4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("\(target.actionHelp)并标记为已确认")
                    
                    Button(action: {
                        Task {
                            try? await taskManager.resolveTask(id: task.id)
                        }
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(themeColor)
                            .cornerRadius(4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("标记为已处理")
                    
                    Button(action: {
                        Task {
                            try? await taskManager.dismissCard(id: task.id)
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(3)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("隐藏此项卡片")
                }
            }
            
            HStack(spacing: 5) {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                    Text(task.verificationNotice)
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(themeColor)
                
                if let cwd = task.cwd {
                    Text("•")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary.opacity(0.4))
                    
                    HStack(spacing: 2) {
                        Image(systemName: "folder")
                            .font(.system(size: 7))
                        Text(cwd)
                            .font(.system(size: 8, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if let result = task.errorMessage ?? task.resultSummary ?? task.promptSummary {
                Text(result)
                    .font(.system(size: 8.5))
                    .foregroundColor(task.status == .error ? Color.red.opacity(0.9) : .secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.25))
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(themeColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
