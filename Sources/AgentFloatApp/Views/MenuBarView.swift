import SwiftUI
import AppKit
import AgentFloatCore

public struct MenuBarView: View {
    @ObservedObject public var taskManager: TaskManager
    public let serverPort: UInt16
    
    @State private var showingHistory = false
    
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
                        .frame(width: 8, height: 8)
                    Text("127.0.0.1:\(String(serverPort))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 待处理任务区
            VStack(alignment: .leading, spacing: 8) {
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
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                if taskManager.pendingTasks.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("当前没有待核对任务")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(taskManager.pendingTasks) { task in
                                pendingTaskRow(task: task)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: 240)
                }
            }
            
            Divider()
            
            // 历史记录折叠区
            DisclosureGroup(isExpanded: $showingHistory) {
                if taskManager.recentHistory.isEmpty {
                    Text("暂无历史记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(taskManager.recentHistory.prefix(15)) { task in
                                historyTaskRow(task: task)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .frame(maxHeight: 180)
                }
            } label: {
                Text("历史记录 (\(taskManager.recentHistory.count))")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
            
            // 底部快捷动作与状态
            VStack(spacing: 8) {
                HStack {
                    Button("清空历史记录") {
                        Task {
                            try? await taskManager.clearResolvedHistory()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("退出 AgentFloat") {
                        NSApp.terminate(nil)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 360)
    }
    
    private func pendingTaskRow(task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(task.status == .completed ? Color.green : (task.status == .error ? Color.red : Color.orange))
                    .frame(width: 8, height: 8)
                
                Text(task.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                
                Spacer()
                
                Text(task.typedSource.displayName)
                    .font(.system(size: 9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(3)
            }
            
            if let cwd = task.cwd {
                Text(cwd)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            HStack(spacing: 6) {
                Button("显示卡片") {
                    taskManager.showCard(for: task)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
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
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
                
                Spacer()
                
                Button("标为已处理") {
                    Task {
                        try? await taskManager.resolveTask(id: task.id)
                    }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.green)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func historyTaskRow(task: AgentTask) -> some View {
        HStack(spacing: 8) {
            Image(systemName: task.status == .completed ? "checkmark.circle" : "xmark.circle")
                .foregroundColor(task.status == .completed ? .green : .red)
                .font(.system(size: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                if let cwd = task.cwd {
                    Text(cwd)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if task.isResolved {
                Text("已处理")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
