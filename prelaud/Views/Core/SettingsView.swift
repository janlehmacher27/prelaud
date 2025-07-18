//
//  Enhanced SettingsView.swift mit Debug Integration
//  prelaud
//
//  Settings erweitert um Debug-Funktionalität
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataPersistenceManager.shared
    @StateObject private var profileManager = UserProfileManager.shared
    @StateObject private var logger = RemoteLogger.shared
    
    // Debug States
    @State private var showingDebugLogs = false
    @State private var showingDataValidation = false
    @State private var validationResults = ""
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Section
                profileSection
                
                // Storage Section
                storageSection
                
                // Debug Section (immer sichtbar für besseres Debugging)
                debugSection
                
                // Cloud Sync Section
                if dataManager.hasCloudSync {
                    cloudSyncSection
                }
                
                // About Section
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingDebugLogs) {
            DebugLogsView()
        }
        .sheet(isPresented: $showingDataValidation) {
            NavigationView {
                ScrollView {
                    Text(validationResults)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Data Validation")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingDataValidation = false
                        }
                    }
                }
            }
        }
        .onAppear {
            logger.info("⚙️ Settings view appeared")
            logger.logDataManagerState(dataManager)
        }
    }
    
    // MARK: - Profile Section
    
    private var profileSection: some View {
        Section("Profile") {
            if let profile = profileManager.userProfile {
                HStack {
                    VStack(alignment: .leading) {
                        Text("@\(profile.username)")
                            .font(.headline)
                        
                        Text("User ID: \(profile.id.uuidString.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(profile.username.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundColor(.blue)
                        )
                }
                
                Button("Edit Profile") {
                    logger.info("👤 Edit profile tapped")
                    // Profile editing logic
                }
                
            } else {
                Button("Setup Profile") {
                    logger.info("👤 Setup profile tapped")
                    // Profile setup logic
                }
            }
        }
    }
    
    // MARK: - Storage Section
    
    private var storageSection: some View {
        Section("Storage") {
            let storageInfo = dataManager.getStorageInfo()
            
            HStack {
                Label("Albums", systemImage: "opticaldisc")
                Spacer()
                Text("\(storageInfo.albumCount)")
                    .foregroundColor(.gray)
            }
            
            HStack {
                Label("Songs", systemImage: "music.note")
                Spacer()
                Text("\(storageInfo.songCount)")
                    .foregroundColor(.gray)
            }
            
            // Album List
            if !dataManager.savedAlbums.isEmpty {
                ForEach(dataManager.savedAlbums) { album in
                    AlbumStorageRow(album: album)
                }
            }
            
            // Storage Actions
            Button("Validate Data Integrity") {
                validateDataIntegrity()
            }
            .foregroundColor(.blue)
            
            Button("Clear All Data") {
                clearAllData()
            }
            .foregroundColor(.red)
        }
    }
    
    // MARK: - Debug Section
    
    private var debugSection: some View {
        Section("Debug Tools") {
            // Device Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Device: \(UIDevice.current.name)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("App: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "unknown")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Debug Actions
            Button("Show Debug Logs") {
                logger.info("🔍 Debug logs opened")
                showingDebugLogs = true
            }
            
            Button("Log System Info") {
                logger.logSystemInfo()
            }
            
            Button("Log Data Manager State") {
                logger.logDataManagerState(dataManager)
            }
            
            Button("Create Test Album") {
                logger.info("🧪 Creating test album...")
                dataManager.createTestAlbum()
            }
            
            Button("Validate Data Integrity") {
                validateDataIntegrity()
            }
            
            // Debug Statistics
            HStack {
                Text("Total Logs")
                Spacer()
                Text("\(logger.logs.count)")
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("Cloud Sync")
                Spacer()
                Text(dataManager.hasCloudSync ? "✅ Enabled" : "❌ Disabled")
                    .foregroundColor(dataManager.hasCloudSync ? .green : .red)
            }
            
            if dataManager.isSyncingToCloud {
                HStack {
                    Text("Syncing...")
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let error = dataManager.cloudSyncError {
                Text("Sync Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Cloud Sync Section
    
    private var cloudSyncSection: some View {
        Section("Cloud Sync") {
            HStack {
                Label("Status", systemImage: "cloud")
                Spacer()
                Text("Connected")
                    .foregroundColor(.green)
            }
            
            Button("Refresh from Cloud") {
                Task {
                    logger.cloud("🔄 Manual cloud refresh initiated")
                    await dataManager.refreshFromCloud()
                }
            }
            
            Button("Force Sync All") {
                logger.cloud("🔄 Force sync all albums")
                // Force sync implementation
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")
                    .foregroundColor(.gray)
            }
            
            #if DEBUG
            HStack {
                Text("Configuration")
                Spacer()
                Text("Debug")
                    .foregroundColor(.orange)
            }
            #else
            HStack {
                Text("Configuration")
                Spacer()
                Text("Release")
                    .foregroundColor(.green)
            }
            #endif
        }
    }
    
    // MARK: - Actions
    
    private func validateDataIntegrity() {
        logger.info("🔍 Starting data validation from Settings")
        dataManager.validateDataIntegrity()
        
        // Create validation results
        var results = "=== DATA VALIDATION RESULTS ===\n\n"
        results += "Timestamp: \(Date())\n"
        results += "Device: \(UIDevice.current.name)\n\n"
        
        results += "In-Memory Albums: \(dataManager.savedAlbums.count)\n"
        
        if let data = UserDefaults.standard.data(forKey: "SavedAlbums") {
            results += "UserDefaults Size: \(data.count) bytes\n"
            
            if let albums = try? JSONDecoder().decode([EncodableAlbum].self, from: data) {
                results += "UserDefaults Albums: \(albums.count)\n"
                results += "Data Integrity: ✅ PASSED\n\n"
                
                results += "Albums in Storage:\n"
                for (index, album) in albums.enumerated() {
                    results += "\(index + 1). \(album.title) by \(album.artist)\n"
                }
            } else {
                results += "UserDefaults Albums: DECODE ERROR\n"
                results += "Data Integrity: ❌ FAILED\n"
            }
        } else {
            results += "UserDefaults: NO DATA\n"
            results += "Data Integrity: ❌ FAILED\n"
        }
        
        results += "\n=== END VALIDATION ==="
        
        validationResults = results
        showingDataValidation = true
        
        logger.success("✅ Data validation completed")
    }
    
    private func clearAllData() {
        logger.warning("⚠️ Clear all data requested from Settings")
        
        // Show confirmation
        let alert = UIAlertController(
            title: "Clear All Data",
            message: "This will permanently delete all your albums. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            logger.info("📱 Clear data cancelled")
        })
        
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { _ in
            logger.warning("🗑️ Clearing all data confirmed")
            dataManager.clearAllData()
            logger.success("✅ All data cleared")
        })
        
        // Present alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
}

// MARK: - Album Storage Row (remains the same)

struct AlbumStorageRow: View {
    let album: Album
    @StateObject private var dataManager = DataPersistenceManager.shared
    @StateObject private var logger = RemoteLogger.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover
            if let coverImage = album.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.05))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(album.songs.count) songs")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Delete Button
            Button(action: {
                logger.warning("🗑️ Delete album requested: \(album.title)")
                HapticFeedbackManager.shared.mediumImpact()
                dataManager.deleteAlbum(album)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
        )
    }
}

// Removed duplicate MinimalButtonStyle - using existing one from project

#Preview {
    SettingsView()
}
