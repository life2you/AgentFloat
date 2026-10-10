import SwiftUI
import AppKit
import AgentFloatCore

public struct MenuBarView: View {
    @ObservedObject public var taskManager: TaskManager
    public let serverPort: UInt16
    
    public init(taskManager: TaskManager, serverPort: UInt16 = 41920) {
        self.taskManager = taskManager
        self.serverPort = serverPort
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶部状态栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "macwindow.on.rectangle")
                        .foregroundColor(.accentColor)
                    Text("AgentFloat")
                        .font(.headline)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("127.0.0.1:\(String(serverPort))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 待处理任务区
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("待处理任务 (\(taskManager.pendingTasks.count))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if !taskManager.pendingTasks.isEmpty {
                        Button("全部已处理") {
                            Task {
                                try? await taskManager.markAllResolved()
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                
                if taskManager.pendingTasks.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.green.opacity(0.8))
                        Text("当前没有待核对任务")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(taskManager.pendingTasks) { task in
                                pendingTaskRow(task: task)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 6)
                    }
                    .frame(maxHeight: 260)
                }
            }
            
            Divider()
            
            // 底部操作栏
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                    Text("自动联动: Codex & Pi")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("重新检测") {
                    _ = AutoIntegrationManager.autoSetupAll()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
                .help("重新检测并修复本地 Codex 与 Pi Agent 联动配置")
                
                Button("退出") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 340)
    }
    
    private func pendingTaskRow(task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(task.status == .completed ? Color.green : (task.status == .error ? Color.red : Color.orange))
                    .frame(width: 7, height: 7)
                
                Text(task.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                
                Spacer()
                
                Text(task.typedSource.displayName)
                    .font(.system(size: 8.5))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(3)
            }
            
            if let cwd = task.cwd {
                Text(cwd)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            HStack(spacing: 6) {
                Button("显示卡片") {
                    taskManager.showCard(for: task)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10.5))
                .foregroundColor(.accentColor)
                
                Button("终端") {
                    TerminalLauncher.activate(
                        cwd: task.cwd,
                        preferredApp: task.terminalApp,
                        sessionId: task.sessionId,
                        source: task.source
                    )
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10.5))
                .foregroundColor(.accentColor)
                
                Spacer()
                
                Button(action: {
                    Task {
                        try? await taskManager.resolveTask(id: task.id)
                    }
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.green)
                        .padding(3)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("标记为已处理")
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}
