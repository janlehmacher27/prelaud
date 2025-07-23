//
//  Fixed ContentView.swift - NAVIGATION BACKEND REPARIERT
//  MusicPreview
//
//  FIXED: onSelectAlbum Parameter wird jetzt korrekt an AlbumsView übergeben
//

import SwiftUI

// MARK: - Navigation Destination Types
enum NavigationDestination: Hashable {
    case albumDetail(Album)
    case settings
    case upload
}

// MARK: - FIXED: Album Extensions for Navigation
extension Album: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

// MARK: - Navigation Router Backend
@MainActor
class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()
    @Published var currentAlbum: Album?
    
    // Navigate to album detail
    func navigateToAlbum(_ album: Album) {
        currentAlbum = album
        path.append(NavigationDestination.albumDetail(album))
        print("🧭 NavigationRouter: Navigating to album: \(album.title)")
    }
    
    // Navigate back
    func navigateBack() {
        if !path.isEmpty {
            path.removeLast()
        }
        currentAlbum = nil
        print("🧭 NavigationRouter: Navigating back")
    }
    
    // Navigate to root
    func navigateToRoot() {
        path.removeLast(path.count)
        currentAlbum = nil
        print("🧭 NavigationRouter: Navigating to root")
    }
    
    // Clear navigation
    func clearNavigation() {
        path = NavigationPath()
        currentAlbum = nil
    }
}

struct ContentView: View {
    @State private var albums: [Album] = []
    @State private var selectedService: StreamingService = .spotify
    @State private var showingUpload = false
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var dataManager = DataPersistenceManager.shared
    @StateObject private var profileManager = UserProfileManager.shared
    @StateObject private var navigationRouter = NavigationRouter()
    
    // Welcome Screen State
    @State private var showWelcome = true
    @State private var showingSettings = false
    
    // Verbesserte Übergang States
    @State private var swipeProgress: Double = 0
    @State private var isTransitioning = false
    @State private var transitionPhase: TransitionPhase = .waiting
    @State private var revealProgress: Double = 0
    @State private var albumsOpacity: Double = 0
    @State private var welcomeScale: Double = 1.0
    @State private var welcomeOffset: CGFloat = 0
    
    enum TransitionPhase {
        case waiting
        case preparing
        case revealing
        case completing
        case complete
    }
    
    var body: some View {
        ZStack {
            // Profile Setup (wenn noch nicht eingerichtet)
            if !profileManager.isProfileSetup {
                ProfileSetupView()
                    .zIndex(10)
            } else {
                // FIXED: Korrekte NavigationStack Implementation
                NavigationStack(path: $navigationRouter.path) {
                    mainAppContent
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .environmentObject(navigationRouter)
            }
        }
        .onAppear {
            #if DEBUG
            debugSupabaseConnection()
            #endif
            
            audioManager.migrateFromSupabase()
            
            if albums.isEmpty {
                albums = dataManager.savedAlbums
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    // MARK: - FIXED: Destination View Handler
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .albumDetail(let album):
            StreamingServicePreview(
                album: album,
                service: selectedService,
                onBack: {
                    HapticFeedbackManager.shared.navigationBack()
                    navigationRouter.navigateBack()
                }
            )
            
        case .settings:
            SettingsView()
            
        case .upload:
            UploadView(
                onAlbumCreated: { album in
                    albums.append(album)
                    dataManager.saveAlbum(album)
                    showingUpload = false
                    showWelcome = false
                    navigationRouter.navigateToAlbum(album)
                    HapticFeedbackManager.shared.success()
                },
                onDismiss: {
                    showingUpload = false
                    navigationRouter.navigateBack()
                }
            )
        }
    }
    
    // MARK: - Main App Content
    private var mainAppContent: some View {
        ZStack {
            // ALBUMS VIEW - FIXED: Mit korrektem onSelectAlbum Parameter!
            if showWelcome {
                Color.clear
            } else {
                AlbumsView(
                    albums: $albums,
                    selectedService: $selectedService,
                    showingSettings: $showingSettings,
                    currentAlbum: $navigationRouter.currentAlbum,
                    onCreateAlbum: {
                        print("🎯 ContentView: onCreateAlbum called")
                        HapticFeedbackManager.shared.buttonTap()
                        showingUpload = true
                    },
                    onSelectAlbum: { album in
                        // FIXED: Diese Funktion war das fehlende Glied!
                        print("🎯 ContentView: onSelectAlbum called for: \(album.title)")
                        HapticFeedbackManager.shared.cardTap()
                        navigationRouter.navigateToAlbum(album)
                    }
                )
                .opacity(showWelcome ? 0.0 : 1.0)
                .scaleEffect(showWelcome ? 0.95 : 1.0)
                .offset(y: showWelcome ? 20 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.9), value: showWelcome)
            }
            
            // WELCOME SCREEN - mit cinematischem Swipe-up Übergang
            if showWelcome {
                MinimalWelcomeScreenWithDebug(
                    showWelcome: $showWelcome,
                    swipeProgress: $swipeProgress,
                    isTransitioning: $isTransitioning,
                    transitionPhase: $transitionPhase,
                    revealProgress: $revealProgress,
                    albumsOpacity: $albumsOpacity,
                    welcomeScale: $welcomeScale,
                    welcomeOffset: $welcomeOffset
                )
                .scaleEffect(welcomeScale)
                .offset(y: welcomeOffset)
                .animation(.spring(response: 0.8, dampingFraction: 0.9), value: welcomeScale)
                .animation(.spring(response: 0.8, dampingFraction: 0.9), value: welcomeOffset)
                .zIndex(5)
            }
            
            // UPLOAD SHEET
            if showingUpload {
                UploadView(
                    onAlbumCreated: { album in
                        print("🎯 ContentView: Album created: \(album.title)")
                        albums.append(album)
                        dataManager.saveAlbum(album)
                        showingUpload = false
                        showWelcome = false
                        navigationRouter.navigateToAlbum(album)
                        HapticFeedbackManager.shared.success()
                    },
                    onDismiss: {
                        print("🎯 ContentView: Upload dismissed")
                        showingUpload = false
                    }
                )
                .zIndex(15)
            }
            
            // MINI PLAYER - nur wenn nicht in Detail-View
            if audioPlayer.currentSong != nil && navigationRouter.path.isEmpty {
                VStack {
                    Spacer()
                    AdaptiveMiniPlayer(service: selectedService)
                        .padding(.bottom, 34) // Safe area
                }
                .zIndex(20)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Debug Functions
    
    #if DEBUG
    private func debugSupabaseConnection() {
        Task {
            let healthCheckResult = await PocketBaseManager.shared.performHealthCheck()
            print("🔍 PocketBase Health Check: \(healthCheckResult ? "✅ Connected" : "❌ Failed")")
        }
    }
    #endif
}
