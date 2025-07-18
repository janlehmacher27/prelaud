//
//  DatabaseSyncView.swift
//  prelaud
//
//  Created by Jan Lehmacher on 19.07.25.
//

import SwiftUI

struct DatabaseSyncView: View {
    @StateObject private var syncManager = DatabaseSyncManager.shared
    
    var body: some View {
        ZStack {
            // Consistent app background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // App Logo/Icon
                Image(systemName: "music.note")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
                    .scaleEffect(syncManager.isSyncing ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), 
                              value: syncManager.isSyncing)
                
                VStack(spacing: 16) {
                    // App Name
                    Text("prelaud")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.white.opacity(0.9))
                    
                    // Sync Status
                    Text(syncManager.syncStatus)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                        .animation(.easeInOut(duration: 0.3), value: syncManager.syncStatus)
                    
                    // Progress Indicator
                    if syncManager.isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                            .scaleEffect(0.8)
                    }
                }
                
                Spacer()
                
                // Manual Reset Option (for debugging)
                if syncManager.isSyncing {
                    VStack(spacing: 8) {
                        Text("Having issues?")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Button("Reset App") {
                            Task {
                                await syncManager.forceCompleteReset()
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}
