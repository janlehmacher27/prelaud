//
//  DebugLogsView.swift
//  prelaud
//
//  Debug Logs Viewer für Remote Debugging
//

import SwiftUI

struct DebugLogsView: View {
    @StateObject private var logger = RemoteLogger.shared
    @StateObject private var dataManager = DataPersistenceManager.shared
    @State private var selectedLevel: RemoteLogger.LogEntry.LogLevel?
    @State private var searchText = ""
    @State private var showingExport = false
    @State private var exportText = ""
    @State private var autoScroll = true
    
    var filteredLogs: [RemoteLogger.LogEntry] {
        var logs = logger.logs
        
        // Filter by level
        if let selectedLevel = selectedLevel {
            logs = logs.filter { $0.level == selectedLevel }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            logs = logs.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.file.localizedCaseInsensitiveContains(searchText) ||
                $0.function.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return logs
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Controls
                controlsSection
                
                // Logs List
                if filteredLogs.isEmpty {
                    emptyStateView
                } else {
                    logsListView
                }
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Export") {
                        exportLogs()
                    }
                    
                    Button("Clear") {
                        logger.clearLogs()
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("System Info") {
                        logger.logSystemInfo()
                    }
                    
                    Button("Data State") {
                        logger.logDataManagerState(dataManager)
                    }
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            NavigationView {
                ScrollView {
                    Text(exportText)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Export Logs")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: exportText) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Controls Section
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Level Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("All") {
                        selectedLevel = nil
                    }
                    .buttonStyle(FilterButtonStyle(isSelected: selectedLevel == nil))
                    
                    ForEach(RemoteLogger.LogEntry.LogLevel.allCases, id: \.self) { level in
                        Button(level.rawValue) {
                            selectedLevel = selectedLevel == level ? nil : level
                        }
                        .buttonStyle(FilterButtonStyle(isSelected: selectedLevel == level))
                    }
                }
                .padding(.horizontal)
            }
            
            // Stats
            HStack {
                Text("Total: \(logger.logs.count)")
                Text("•")
                Text("Filtered: \(filteredLogs.count)")
                Spacer()
                
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .font(.caption)
            .foregroundColor(.gray)
            
            Divider()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Logs List
    
    private var logsListView: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredLogs) { log in
                    LogEntryRow(log: log)
                        .id(log.id)
                }
            }
            .listStyle(PlainListStyle())
            .onChange(of: filteredLogs.count) {
                if autoScroll && !filteredLogs.isEmpty {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(filteredLogs.last?.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No logs found")
                .font(.headline)
                .foregroundColor(.gray)
            
            if !searchText.isEmpty || selectedLevel != nil {
                Text("Try adjusting your filters")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Button("Generate Test Log") {
                logger.info("Test log entry generated at \(Date())")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func exportLogs() {
        exportText = logger.exportLogs()
        showingExport = true
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let log: RemoteLogger.LogEntry
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.level.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(levelColor)
                
                Spacer()
                
                Text(log.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Text(log.message)
                .font(.system(.body, design: .default))
                .foregroundColor(.primary)
            
            HStack {
                Text("\(log.file):\(log.line)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(log.deviceName)
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                ScrollView {
                    Text(log.detailMessage)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Log Detail")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingDetail = false
                        }
                    }
                }
            }
        }
    }
    
    private var levelColor: Color {
        switch log.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        case .album: return .purple
        case .database: return .brown
        case .cloud: return .cyan
        }
    }
}

// MARK: - Filter Button Style

struct FilterButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    DebugLogsView()
}
