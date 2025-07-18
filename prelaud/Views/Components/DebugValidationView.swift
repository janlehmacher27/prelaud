//
//  DebugValidationView.swift
//  prelaud
//
//  Created by Jan Lehmacher on 19.07.25.
//


//
//  DebugValidationView.swift - USER VALIDATION DEBUGGING
//  prelaud
//
//  Add this view to debug and fix user validation issues
//

import SwiftUI

struct DebugValidationView: View {
    @StateObject private var profileManager = UserProfileManager.shared
    @StateObject private var syncManager = DatabaseSyncManager.shared
    @State private var debugOutput = ""
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    Text("Debug User Validation")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.top, 50)
                    
                    // Current Status
                    statusSection
                    
                    // Debug Actions
                    actionsSection
                    
                    // Debug Output
                    outputSection
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Status")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(title: "Profile Setup", value: profileManager.isProfileSetup ? "✅ Yes" : "❌ No")
                StatusRow(title: "Username", value: profileManager.userProfile?.username ?? "❌ None")
                StatusRow(title: "Artist Name", value: profileManager.userProfile?.artistName ?? "❌ None")
                StatusRow(title: "Cloud ID", value: profileManager.userProfile?.cloudId ?? "❌ Missing")
                StatusRow(title: "Sync Complete", value: syncManager.syncComplete ? "✅ Yes" : "❌ No")
                StatusRow(title: "Needs Setup", value: syncManager.needsSetup ? "⚠️ Yes" : "✅ No")
                StatusRow(title: "Sync Status", value: syncManager.syncStatus)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug Actions")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ActionButton(title: "Run Full Debug", color: .blue) {
                    await runFullDebug()
                }
                
                ActionButton(title: "Fix Missing Cloud ID", color: .orange) {
                    await fixMissingCloudId()
                }
                
                ActionButton(title: "Force User Recreation", color: .purple) {
                    await forceUserRecreation()
                }
                
                ActionButton(title: "Skip Validation (Testing)", color: .yellow) {
                    skipValidation()
                }
                
                ActionButton(title: "Complete Reset (Nuclear)", color: .red) {
                    await completeReset()
                }
                
                ActionButton(title: "Test PocketBase Connection", color: .green) {
                    await testConnection()
                }
            }
        }
    }
    
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug Output")
                .font(.headline)
                .foregroundColor(.white)
            
            ScrollView {
                Text(debugOutput.isEmpty ? "No debug output yet..." : debugOutput)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 200)
            .background(Color.black)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Debug Actions
    
    private func runFullDebug() async {
        isLoading = true
        debugOutput = ""
        
        appendLog("🔍 ===== FULL USER VALIDATION DEBUG =====")
        
        // 1. Check local profile
        appendLog("\n📱 LOCAL PROFILE STATUS:")
        appendLog("   - isProfileSetup: \(profileManager.isProfileSetup)")
        appendLog("   - userProfile exists: \(profileManager.userProfile != nil)")
        
        if let profile = profileManager.userProfile {
            appendLog("   - username: @\(profile.username)")
            appendLog("   - artistName: \(profile.artistName)")
            appendLog("   - cloudId: \(profile.cloudId ?? "❌ MISSING")")
            appendLog("   - bio: \(profile.bio ?? "empty")")
            appendLog("   - createdAt: \(profile.createdAt)")
        } else {
            appendLog("   - ❌ NO PROFILE FOUND")
        }
        
        // 2. Check UserDefaults
        appendLog("\n💾 USERDEFAULTS CHECK:")
        let hasProfileData = UserDefaults.standard.object(forKey: "UserProfile") != nil
        let isSetupComplete = UserDefaults.standard.bool(forKey: "IsProfileSetup")
        
        appendLog("   - UserProfile key exists: \(hasProfileData)")
        appendLog("   - IsProfileSetup: \(isSetupComplete)")
        
        // 3. Check DatabaseSyncManager state
        appendLog("\n🔄 SYNC MANAGER STATUS:")
        appendLog("   - needsSetup: \(syncManager.needsSetup)")
        appendLog("   - syncComplete: \(syncManager.syncComplete)")
        appendLog("   - shouldShowSetup: \(syncManager.shouldShowSetup)")
        appendLog("   - isSyncing: \(syncManager.isSyncing)")
        appendLog("   - syncStatus: \(syncManager.syncStatus)")
        
        // 4. Test PocketBase connection
        appendLog("\n🌐 POCKETBASE CONNECTION:")
        let pocketBase = PocketBaseManager.shared
        let isConnected = await pocketBase.testConnection()
        appendLog("   - Connected: \(isConnected ? "✅" : "❌")")
        appendLog("   - Base URL: \(pocketBase.baseURL)")
        
        // 5. If we have a cloudId, try to fetch the user
        if let cloudId = profileManager.userProfile?.cloudId {
            appendLog("\n👤 CLOUD USER CHECK:")
            do {
                let cloudUser = try await pocketBase.getUserById(cloudId)
                appendLog("   - ✅ User found in database")
                appendLog("   - Cloud username: @\(cloudUser.username)")
                appendLog("   - Cloud artistName: \(cloudUser.artistName)")
                appendLog("   - Cloud bio: \(cloudUser.bio)")
            } catch {
                appendLog("   - ❌ User NOT found in database: \(error)")
                appendLog("   - This is why validation fails!")
            }
        }
        
        appendLog("\n🎯 RECOMMENDATION:")
        if profileManager.userProfile?.cloudId == nil {
            appendLog("   - Missing cloudId -> Use 'Fix Missing Cloud ID'")
        } else if !isConnected {
            appendLog("   - No connection -> Check internet/PocketBase server")
        } else {
            appendLog("   - User not in database -> Use 'Force User Recreation'")
        }
        
        appendLog("\n=====================================")
        isLoading = false
    }
    
    private func fixMissingCloudId() async {
        isLoading = true
        appendLog("🔧 Attempting to fix missing cloudId...")
        
        let success = await profileManager.fixMissingCloudId()
        
        if success {
            appendLog("✅ CloudId fixed successfully!")
            appendLog("   - New cloudId: \(profileManager.userProfile?.cloudId ?? "still missing")")
        } else {
            appendLog("❌ Failed to fix cloudId")
        }
        
        isLoading = false
    }
    
    private func forceUserRecreation() async {
        isLoading = true
        appendLog("🔄 Force recreating user in PocketBase...")
        
        await syncManager.forceRecreateCloudUser()
        
        appendLog("   - Sync status: \(syncManager.syncStatus)")
        appendLog("   - Needs setup: \(syncManager.needsSetup)")
        appendLog("   - Sync complete: \(syncManager.syncComplete)")
        
        isLoading = false
    }
    
    private func skipValidation() {
        appendLog("⚠️ Skipping validation for testing...")
        syncManager.skipValidationForTesting()
        appendLog("   - Validation skipped")
        appendLog("   - App should now proceed to main interface")
    }
    
    private func completeReset() async {
        isLoading = true
        appendLog("💥 Performing complete reset...")
        
        await syncManager.forceCompleteReset()
        
        appendLog("   - All local data cleared")
        appendLog("   - App will now show setup screen")
        
        isLoading = false
    }
    
    private func testConnection() async {
        isLoading = true
        appendLog("🌐 Testing PocketBase connection...")
        
        let pocketBase = PocketBaseManager.shared
        let isConnected = await pocketBase.performHealthCheck()
        
        appendLog("   - Connection: \(isConnected ? "✅ Success" : "❌ Failed")")
        appendLog("   - Base URL: \(pocketBase.baseURL)")
        
        isLoading = false
    }
    
    private func appendLog(_ message: String) {
        debugOutput += message + "\n"
    }
}

// MARK: - Helper Views

struct StatusRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title + ":")
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .foregroundColor(.white)
                .font(.system(.body, design: .monospaced))
            
            Spacer()
        }
    }
}

struct ActionButton: View {
    let title: String
    let color: Color
    let action: () async -> Void
    
    @State private var isLoading = false
    
    var body: some View {
        Button(action: {
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
            }
            .padding()
            .background(color.opacity(0.8))
            .cornerRadius(8)
        }
        .disabled(isLoading)
    }
}

// MARK: - Integration into ContentView
// Add this to your ContentView for debugging:

/*
 // Add this gesture to your ContentView to show debug view
 .onTapGesture(count: 5) {
     // Show debug view after 5 taps
 }
 
 // Or add as a sheet:
 .sheet(isPresented: $showingDebug) {
     DebugValidationView()
 }
 */
