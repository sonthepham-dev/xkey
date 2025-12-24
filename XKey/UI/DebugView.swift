//
//  DebugView.swift
//  XKey
//
//  SwiftUI Debug Window - Optimized with List for virtualized rendering
//

import SwiftUI

struct DebugView: View {
    @ObservedObject var viewModel: DebugViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            VStack(spacing: 4) {
                HStack {
                    Text(viewModel.statusText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                HStack {
                    Text("Log file: ~/XKey_Debug.log")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(viewModel.logLines.count) lines")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            // Input text area
            VStack(alignment: .leading, spacing: 4) {
                Text("Input Test Area:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $viewModel.inputText)
                    .font(.system(size: 16))
                    .frame(height: 200)
                    .border(Color.gray.opacity(0.3))
            }
            .padding()
            
            // Debug logs section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Debug Logs:")
                        .font(.system(size: 12, weight: .semibold))
                    
                    Spacer()
                    
                    Button("Read Word Before Cursor (⌘⇧R)") {
                        viewModel.readWordBeforeCursor()
                    }
                    
                    Toggle("Verbose", isOn: $viewModel.isVerboseLogging)
                        .toggleStyle(.checkbox)
                        .help("Show all debug messages (may cause lag)")
                    
                    Toggle("Enable Logging", isOn: $viewModel.isLoggingEnabled)
                        .toggleStyle(.checkbox)
                        .onChange(of: viewModel.isLoggingEnabled) { _ in
                            viewModel.toggleLogging()
                        }
                    
                    Button("Open Log File") {
                        viewModel.openLogFile()
                    }
                    .help("Open log file in Finder")
                    
                    Button("Clear") {
                        viewModel.clearLogs()
                    }
                    
                    Button("Copy") {
                        viewModel.copyLogs()
                    }
                }
                
                // Optimized log viewer using List for virtualization
                LogListView(lines: viewModel.logLines)
            }
            .padding()
        }
        .frame(width: 800, height: 600)
        .onAppear {
            viewModel.windowDidBecomeVisible()
        }
        .onDisappear {
            viewModel.windowDidBecomeHidden()
        }
    }
}

// MARK: - Optimized Log List View

/// Virtualized log list - only renders visible lines
struct LogListView: View {
    let lines: [String]
    
    @State private var autoScroll = true
    @State private var lastLineCount = 0
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        LogLineView(line: line)
                            .id(index)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .border(Color.gray.opacity(0.3))
            .onChange(of: lines.count) { newCount in
                if autoScroll && newCount > lastLineCount {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(newCount - 1, anchor: .bottom)
                    }
                }
                lastLineCount = newCount
            }
        }
    }
}

// MARK: - Individual Log Line View

/// Single log line - optimized for reuse
struct LogLineView: View {
    let line: String
    
    var body: some View {
        Text(line)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(lineColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
    
    /// Color based on log level
    private var lineColor: Color {
        if line.contains("❌") || line.contains("ERROR") {
            return .red
        } else if line.contains("⚠️") || line.contains("WARNING") {
            return .orange
        } else if line.contains("✅") || line.contains("SUCCESS") {
            return .green
        } else if line.contains("🔍") || line.contains("DEBUG") {
            return .purple
        } else {
            return .primary
        }
    }
}

// MARK: - Preview

#Preview {
    DebugView(viewModel: DebugViewModel())
}
