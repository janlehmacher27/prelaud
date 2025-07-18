import SwiftUI

@main
struct MusicPreviewApp: App {
    @StateObject private var databaseSync = DatabaseSyncManager.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main Content
                if databaseSync.shouldShowSetup {
                    ProfileSetupView()
                } else if databaseSync.syncComplete {
                    ContentView()
                } else {
                    DatabaseSyncView()
                }
            }
            .task {
                // Perform database sync on app launch
                await databaseSync.performStartupSync()
            }
        }
    }
}
