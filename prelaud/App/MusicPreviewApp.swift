//
//  MusicPreviewApp.swift
//  MusicPreview
//
//  Updated for Supabase Storage only
//

import SwiftUI

@main
struct MusicPreviewApp: App {
    
    init() {
        print("🎵 MusicPreview App starting...")
        
        // Lade gespeicherte Supabase URLs
        SupabaseAudioManager.shared.loadUploadedFiles()
        
        print("✅ App initialization complete")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Optional: Führe Migration von Dropbox zu Supabase durch
                    SupabaseAudioManager.shared.migrateFromDropbox()
                }
        }
    }
}
