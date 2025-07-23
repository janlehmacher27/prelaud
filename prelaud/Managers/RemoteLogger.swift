//
//  Fixed RemoteLogger.swift
//  prelaud
//
//  FIXED: Dekodierungsfehler und Performance-Verbesserungen
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
    
    // MARK: - FIXED: Data Manager State Logging with Better Error Handling
    
    @MainActor
    func logDataManagerState(_ dataManager: DataPersistenceManager) {
        database("=== DATA MANAGER STATE ===")
        database("Saved Albums Count: \(dataManager.savedAlbums.count)")
        database("Is Loading: \(dataManager.isLoading)")
        database("Has Cloud Sync: \(dataManager.hasCloudSync)")
        database("Is Syncing To Cloud: \(dataManager.isSyncingToCloud)")
        database("Cloud Sync Error: \(dataManager.cloudSyncError ?? "none")")
        
        // FIXED: UserDefaults check with proper error handling
        if let data = UserDefaults.standard.data(forKey: "SavedAlbums") {
            database("UserDefaults data size: \(data.count) bytes")
            
            // Try both decoding strategies
            var decodingSuccess = false
            
            // First try: ISO8601 strategy
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let albums = try decoder.decode([EncodableAlbum].self, from: data)
                database("✅ UserDefaults decode successful (ISO8601): \(albums.count) albums")
                decodingSuccess = true
                
                // Log first few albums for verification
                for (index, album) in albums.prefix(3).enumerated() {
                    database("  Album \(index + 1): '\(album.title)' by '\(album.artist)'")
                }
                if albums.count > 3 {
                    database("  ... and \(albums.count - 3) more albums")
                }
                
            } catch {
                database("⚠️ ISO8601 decoding failed: \(error.localizedDescription)")
                
                // Second try: secondsSince1970 strategy
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .secondsSince1970
                    let albums = try decoder.decode([EncodableAlbum].self, from: data)
                    database("✅ UserDefaults decode successful (fallback): \(albums.count) albums")
                    decodingSuccess = true
                    
                } catch {
                    database("❌ Both decoding strategies failed")
                    database("ISO8601 Error: \(error.localizedDescription)")
                    
                    // Try to get more specific error information
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            database("Data corrupted at: \(context.debugDescription)")
                        case .keyNotFound(let key, let context):
                            database("Key not found: \(key.stringValue) at \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            database("Type mismatch for \(type) at \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            database("Value not found for \(type) at \(context.debugDescription)")
                        @unknown default:
                            database("Unknown decoding error: \(error)")
                        }
                    }
                }
            }
            
            if !decodingSuccess {
                // Try to analyze the raw data
                if let jsonString = String(data: data, encoding: .utf8) {
                    let preview = String(jsonString.prefix(200))
                    database("Raw JSON preview: \(preview)...")
                } else {
                    database("❌ Cannot convert data to string")
                }
            }
            
        } else {
            warning("⚠️ No UserDefaults data found for SavedAlbums key")
        }
        
        database("========================")
    }
    
    // MARK: - Persistence with Error Handling
    
    private func saveLogs() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(logs)
            UserDefaults.standard.set(data, forKey: logsKey)
        } catch {
            print("❌ Failed to save logs: \(error)")
        }
    }
    
    private func loadLogs() {
        guard let data = UserDefaults.standard.data(forKey: logsKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let savedLogs = try decoder.decode([LogEntry].self, from: data)
            logs = savedLogs
        } catch {
            print("❌ Failed to load logs: \(error)")
            // Don't clear logs on load failure, just start fresh
            logs = []
        }
    }
    
    // MARK: - Utilities
    
    func clearLogs() {
        logs.removeAll()
        UserDefaults.standard.removeObject(forKey: logsKey)
        info("🧹 Logs cleared")
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
    
    // MARK: - Performance Analysis
    
    func getPerformanceStats() -> String {
        let errorCount = logs.filter { $0.level == .error }.count
        let warningCount = logs.filter { $0.level == .warning }.count
        let successCount = logs.filter { $0.level == .success }.count
        let databaseCount = logs.filter { $0.level == .database }.count
        
        return """
        📊 LOG PERFORMANCE STATS
        Total Logs: \(logs.count)
        Errors: \(errorCount)
        Warnings: \(warningCount)
        Success: \(successCount)
        Database: \(databaseCount)
        """
    }
    
    // MARK: - Debug Helpers
    
    func findSpammyLogs() -> [String: Int] {
        var messageCounts: [String: Int] = [:]
        
        for log in logs {
            let key = "\(log.file):\(log.line) - \(log.message.prefix(50))"
            messageCounts[key, default: 0] += 1
        }
        
        // Return only messages that appear more than 5 times
        return messageCounts.filter { $0.value > 5 }
    }
    
    func logSpamAnalysis() {
        let spammyLogs = findSpammyLogs()
        
        if spammyLogs.isEmpty {
            info("✅ No spam detected in logs")
        } else {
            warning("⚠️ SPAM DETECTED:")
            for (message, count) in spammyLogs.sorted(by: { $0.value > $1.value }) {
                warning("  \(count)x: \(message)")
            }
        }
    }
}
