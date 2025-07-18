//
//  RemoteLogger.swift
//  prelaud
//
//  Remote Logging System für Debug zwischen verschiedenen Geräten
//

import Foundation
import UIKit

class RemoteLogger: ObservableObject {
    static let shared = RemoteLogger()
    
    @Published var logs: [LogEntry] = []
    private let maxLogs = 200
    private let logsKey = "remote_debug_logs"
    
    struct LogEntry: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let deviceName: String
        let level: LogLevel
        let message: String
        let file: String
        let function: String
        let line: Int
        
        init(timestamp: Date, deviceName: String, level: LogLevel, message: String, file: String, function: String, line: Int) {
            self.id = UUID()
            self.timestamp = timestamp
            self.deviceName = deviceName
            self.level = level
            self.message = message
            self.file = file
            self.function = function
            self.line = line
        }
        
        enum LogLevel: String, Codable, CaseIterable {
            case debug = "🔧 DEBUG"
            case info = "ℹ️ INFO"
            case warning = "⚠️ WARNING"
            case error = "❌ ERROR"
            case success = "✅ SUCCESS"
            case album = "🎵 ALBUM"
            case database = "💾 DATABASE"
            case cloud = "☁️ CLOUD"
        }
        
        var formattedMessage: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return "[\(formatter.string(from: timestamp))] [\(deviceName)] \(level.rawValue) \(message)"
        }
        
        var detailMessage: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            return """
            [\(formatter.string(from: timestamp))]
            Device: \(deviceName)
            Level: \(level.rawValue)
            File: \(file):\(line) in \(function)
            Message: \(message)
            """
        }
    }
    
    private init() {
        loadLogs()
    }
    
    // MARK: - Public Logging Methods
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .success, file: file, function: function, line: line)
    }
    
    func album(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .album, file: file, function: function, line: line)
    }
    
    func database(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .database, file: file, function: function, line: line)
    }
    
    func cloud(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .cloud, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging
    
    private func log(_ message: String, level: LogEntry.LogLevel, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let deviceName = UIDevice.current.name
        
        let entry = LogEntry(
            timestamp: Date(),
            deviceName: deviceName,
            level: level,
            message: message,
            file: fileName,
            function: function,
            line: line
        )
        
        DispatchQueue.main.async {
            self.logs.append(entry)
            
            // Limit logs
            if self.logs.count > self.maxLogs {
                self.logs = Array(self.logs.suffix(self.maxLogs))
            }
            
            self.saveLogs()
        }
        
        // Also print to console for Xcode debugging
        print(entry.formattedMessage)
    }
    
    // MARK: - System Info Logging
    
    func logSystemInfo() {
        info("=== SYSTEM INFO ===")
        info("Device: \(UIDevice.current.name)")
        info("Model: \(UIDevice.current.model)")
        info("System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        info("App Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "unknown")")
        info("Build: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "unknown")")
        info("Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        #if DEBUG
        info("Build Configuration: DEBUG")
        #else
        info("Build Configuration: RELEASE")
        #endif
        
        info("==================")
    }
    
    @MainActor
    func logDataManagerState(_ dataManager: DataPersistenceManager) {
        database("=== DATA MANAGER STATE ===")
        database("Saved Albums Count: \(dataManager.savedAlbums.count)")
        database("Is Loading: \(dataManager.isLoading)")
        database("Has Cloud Sync: \(dataManager.hasCloudSync)")
        database("Is Syncing To Cloud: \(dataManager.isSyncingToCloud)")
        database("Cloud Sync Error: \(dataManager.cloudSyncError ?? "none")")
        
        // UserDefaults check
        if let data = UserDefaults.standard.data(forKey: "SavedAlbums") {
            database("UserDefaults data size: \(data.count) bytes")
            
            if let albums = try? JSONDecoder().decode([EncodableAlbum].self, from: data) {
                database("UserDefaults contains \(albums.count) albums")
                for (index, album) in albums.enumerated() {
                    database("  Album \(index + 1): \(album.title) by \(album.artist)")
                }
            } else {
                error("Failed to decode albums from UserDefaults")
            }
        } else {
            warning("No UserDefaults data found for SavedAlbums")
        }
        
        database("========================")
    }
    
    // MARK: - Persistence
    
    private func saveLogs() {
        do {
            let data = try JSONEncoder().encode(logs)
            UserDefaults.standard.set(data, forKey: logsKey)
        } catch {
            print("Failed to save logs: \(error)")
        }
    }
    
    private func loadLogs() {
        guard let data = UserDefaults.standard.data(forKey: logsKey),
              let savedLogs = try? JSONDecoder().decode([LogEntry].self, from: data) else {
            return
        }
        
        logs = savedLogs
    }
    
    // MARK: - Utilities
    
    func clearLogs() {
        logs.removeAll()
        UserDefaults.standard.removeObject(forKey: logsKey)
        info("Logs cleared")
    }
    
    func getLogsAsString() -> String {
        return logs.map { $0.formattedMessage }.joined(separator: "\n")
    }
    
    func getLogsForLevel(_ level: LogEntry.LogLevel) -> [LogEntry] {
        return logs.filter { $0.level == level }
    }
    
    func exportLogs() -> String {
        let header = """
        ===== PRELAUD DEBUG LOG EXPORT =====
        Export Date: \(Date())
        Device: \(UIDevice.current.name)
        Total Logs: \(logs.count)
        =====================================
        
        """
        
        let logContent = logs.map { $0.detailMessage }.joined(separator: "\n\n")
        
        return header + logContent
    }
}
