import SwiftUI
import AgentFloatCore

public struct FloatingCardView: View {
    public let task: AgentTask
    public let taskManager: TaskManager
    
    public init(task: AgentTask, taskManager: TaskManager) {
        self.task = task
        self.taskManager = taskManager
    }
    
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
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶栏：来源、状态与关闭按钮
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .foregroundColor(themeColor)
                        .font(.system(size: 14, weight: .semibold))
                    Text(task.status.displayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeColor)
                }
                
                // 来源标签
                Text(task.typedSource.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                
                if let duration = task.durationMs {
                    Text("\(Double(duration) / 1000.0, specifier: "%.1f")s")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 关闭卡片按钮（仅关闭，不标记为已处理）
                Button(action: {
                    Task {
                        try? await taskManager.dismissCurrentCard()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("关闭当前卡片 (不标记为已处理)")
            }
            
            // 醒目核心提示：严禁将任务结束等同于代码验证通过
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(themeColor)
                    .font(.system(size: 13))
                Text(task.verificationNotice)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeColor)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(themeColor.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(themeColor.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(6)
            
            // 任务标题与工作目录
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                if let cwd = task.cwd {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                        Text(cwd)
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // 摘要/结果显示
            if let result = task.resultSummary ?? task.errorMessage ?? task.promptSummary {
                Text(result)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.4))
                    .cornerRadius(6)
            }
            
            Divider()
            
            // 底部操作按钮
            HStack(spacing: 10) {
                Button(action: {
                    TerminalLauncher.activate(cwd: task.cwd, preferredApp: task.terminalApp)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal.fill")
                        Text("查看终端")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    Task {
                        try? await taskManager.resolveTask(id: task.id)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("已处理")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(themeColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeColor.opacity(0.35), lineWidth: 1.5)
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
}
