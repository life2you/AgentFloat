import SwiftUI
import AgentFloatCore

public struct FloatingCardView: View {
    @ObservedObject public var taskManager: TaskManager
    public var previewTask: AgentTask?
    
    public init(taskManager: TaskManager, previewTask: AgentTask? = nil) {
        self.taskManager = taskManager
        self.previewTask = previewTask
    }
    
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
            // 超紧凑顶栏
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
            
            // 列表内容
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

/// 超紧凑单项任务条目
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
            // 第 1 行：状态点 + 来源 + 标题 + 快捷操作
            HStack(spacing: 4) {
                Circle()
                    .fill(themeColor)
                    .frame(width: 6, height: 6)
                
                Text(task.typedSource.displayName)
                    .font(.system(size: 8, weight: .bold))
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
                
                // 按钮组直接内置于行内右侧
                HStack(spacing: 4) {
                    Button(action: {
                        TerminalLauncher.activate(cwd: task.cwd, preferredApp: task.terminalApp)
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "terminal")
                            Text("终端")
                        }
                        .font(.system(size: 9, weight: .medium))
                        .padding(.vertical, 2)
                        .padding(.horizontal, 5)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .help("激活当前终端窗口")
                    
                    Button(action: {
                        Task {
                            try? await taskManager.resolveTask(id: task.id)
                        }
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark")
                            Text("已处理")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(themeColor)
                        .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .help("标记为已处理")
                    
                    Button(action: {
                        Task {
                            try? await taskManager.dismissCard(id: task.id)
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(2)
                    }
                    .buttonStyle(.plain)
                    .help("隐藏此项卡片")
                }
            }
            
            // 第 2 行：核心警告提示 + 工作目录
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
            
            // 第 3 行（如有摘要或报错，紧凑单行展示）
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
