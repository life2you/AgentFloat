import SwiftUI
import AgentFloatCore

public struct FloatingCardView: View {
    @ObservedObject public var taskManager: TaskManager
    public var previewTask: AgentTask?
    
    public init(taskManager: TaskManager, previewTask: AgentTask? = nil) {
        self.taskManager = taskManager
        self.previewTask = previewTask
    }
    
    /// 兼容老接口
    public init(task: AgentTask, taskManager: TaskManager) {
        self.taskManager = taskManager
        self.previewTask = task
    }
    
    private var tasksToDisplay: [AgentTask] {
        if let preview = previewTask {
            return [preview]
        }
        return taskManager.undismissedTasks
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶栏：多任务聚合标识与全局快捷动作
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "macwindow.on.rectangle")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 13, weight: .semibold))
                    Text("待核对任务")
                        .font(.system(size: 12, weight: .bold))
                    
                    Text("\(tasksToDisplay.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                
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
                
                // 关闭整个悬浮窗（不标记为已处理）
                Button(action: {
                    Task {
                        try? await taskManager.dismissAllCards()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("关闭全部卡片 (保留在待处理列表中)")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            
            Divider()
                .opacity(0.6)
            
            // 列表内容：紧凑卡片排布
            if tasksToDisplay.isEmpty {
                VStack(spacing: 4) {
                    Text("暂无待核对任务")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.vertical, showsIndicators: tasksToDisplay.count > 3) {
                    LazyVStack(spacing: 8) {
                        ForEach(tasksToDisplay) { item in
                            CompactTaskRow(task: item, taskManager: taskManager)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 400)
            }
        }
        .frame(width: 390)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 5)
        .animation(.easeInOut(duration: 0.2), value: tasksToDisplay)
    }
}

/// 紧凑任务单条卡片
private struct CompactTaskRow: View {
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
    
    private var statusIcon: String {
        switch task.status {
        case .completed:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.octagon.fill"
        case .aborted:
            return "stop.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 第 1 行：状态 + 来源 + 耗时 + 单项关闭
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .foregroundColor(themeColor)
                    .font(.system(size: 11, weight: .bold))
                
                Text(task.status.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(themeColor)
                
                Text(task.typedSource.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(3)
                
                if let duration = task.durationMs {
                    Text("\(Double(duration) / 1000.0, specifier: "%.1f")s")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 单项关闭卡片
                Button(action: {
                    Task {
                        try? await taskManager.dismissCard(id: task.id)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(2)
                }
                .buttonStyle(.plain)
                .help("关闭此项卡片 (不标记为已处理)")
            }
            
            // 第 2 行：醒目核心提示（紧凑横幅）
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(themeColor)
                    .font(.system(size: 10))
                Text(task.verificationNotice)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(themeColor)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(themeColor.opacity(0.1))
            .cornerRadius(4)
            
            // 第 3 行：标题与工作目录
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let cwd = task.cwd {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 9))
                        Text(cwd)
                            .font(.system(size: 9, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // 第 4 行：输出或摘要（如果存在）
            if let result = task.resultSummary ?? task.errorMessage ?? task.promptSummary {
                Text(result)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.35))
                    .cornerRadius(4)
            }
            
            // 第 5 行：紧凑操作按钮
            HStack(spacing: 8) {
                Spacer()
                
                Button(action: {
                    TerminalLauncher.activate(cwd: task.cwd, preferredApp: task.terminalApp)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "terminal.fill")
                        Text("查看终端")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    Task {
                        try? await taskManager.resolveTask(id: task.id)
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                        Text("已处理")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 10)
                    .background(themeColor)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeColor.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
