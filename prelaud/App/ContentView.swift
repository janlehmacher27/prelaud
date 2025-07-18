//
//  ContentView.swift - CINEMATISCHER SWIPE-UP ÜBERGANG (CLEANED)
//  MusicPreview
//
//  Nur Welcome Screen Animation + Navigation zu AlbumsView
//

import SwiftUI

struct ContentView: View {
    @State private var albums: [Album] = []
    @State private var currentAlbum: Album?
    @State private var selectedService: StreamingService = .spotify
    @State private var showingUpload = false
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @StateObject private var supabaseManager = AudioManager.shared
    @StateObject private var dataManager = DataPersistenceManager.shared
    @StateObject private var profileManager = UserProfileManager.shared
    @StateObject private var syncManager = DatabaseSyncManager.shared
    
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
            if syncManager.shouldShowSetup {
                ProfileSetupView()
            } else {
                ZStack {
                    // Profile Setup (wenn noch nicht eingerichtet)
                    if !profileManager.isProfileSetup {
                        ProfileSetupView()
                            .zIndex(10)
                    } else {
                        // Normale App-Flows
                        mainAppContent
                    }
                }
                .onAppear {
                    if albums.isEmpty {
                        albums = dataManager.savedAlbums
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
                .task {
                    await PocketBaseManager.shared.performHealthCheck()
                    
                    if syncManager.syncComplete {
                        await performBackgroundValidation()
                    }
                }
            }
        }
    }
    
    // MARK: - Main App Content
    private var mainAppContent: some View {
        ZStack {
            // ALBUMS VIEW - immer da, aber unsichtbar bis Transition
            AlbumsView(
                albums: $albums,
                selectedService: $selectedService,
                showingSettings: $showingSettings,
                currentAlbum: $currentAlbum,
                onCreateAlbum: {
                    HapticFeedbackManager.shared.buttonTap()
                    showingUpload = true
                }
            )
            .opacity(showWelcome ? 0 : 1)
            .scaleEffect(showWelcome ? 0.98 : 1.0)
            .blur(radius: showWelcome ? 1 : 0)
            .animation(.spring(response: 1.4, dampingFraction: 0.8), value: showWelcome)
            
            // WELCOME SCREEN - verschwindet bei Transition
            if showWelcome {
                MinimalWelcomeScreen(
                    showWelcome: $showWelcome,
                    swipeProgress: $swipeProgress,
                    isTransitioning: $isTransitioning,
                    transitionPhase: $transitionPhase,
                    revealProgress: $revealProgress,
                    albumsOpacity: $albumsOpacity,
                    welcomeScale: $welcomeScale,
                    welcomeOffset: $welcomeOffset
                )
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showingUpload) {
            UploadView(
                onAlbumCreated: { album in
                    HapticFeedbackManager.shared.success()
                    withAnimation(.smooth(duration: 0.5)) {
                        albums.append(album)
                        dataManager.saveAlbum(album)
                        showingUpload = false
                    }
                },
                onDismiss: {
                    HapticFeedbackManager.shared.lightImpact()
                    showingUpload = false
                }
            )
        }
        .fullScreenCover(item: $currentAlbum) { album in
            StreamingServicePreview(
                album: album,
                service: selectedService,
                onBack: {
                    HapticFeedbackManager.shared.navigationBack()
                    currentAlbum = nil
                }
            )
        }
    }
    
    // MARK: - Background Validation
    private func performBackgroundValidation() async {
        if let profile = UserProfileManager.shared.userProfile,
           let cloudId = profile.cloudId {
            
            do {
                let _ = try await PocketBaseManager.shared.getUserById(cloudId)
                print("✅ Background validation passed")
            } catch {
                print("❌ Background validation failed")
                await syncManager.forceCompleteReset()
            }
        }
    }
}

// MARK: - MINIMAL WELCOME SCREEN (umbenennt für Klarheit)
struct MinimalWelcomeScreen: View {
    @Binding var showWelcome: Bool
    @Binding var swipeProgress: Double
    @Binding var isTransitioning: Bool
    @Binding var transitionPhase: ContentView.TransitionPhase
    @Binding var revealProgress: Double
    @Binding var albumsOpacity: Double
    @Binding var welcomeScale: Double
    @Binding var welcomeOffset: CGFloat
    
    @State private var textOpacity: Double = 1.0
    @State private var iconScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Clean schwarzer Hintergrund
            Color.black
                .ignoresSafeArea()
                .scaleEffect(welcomeScale)
                .offset(y: welcomeOffset)
                .opacity(isTransitioning ? (1.0 - revealProgress) : 1.0)
            
            // Minimale Lichteffekte nur bei Swipe
            if swipeProgress > 0.3 {
                RadialGradient(
                    colors: [
                        Color.white.opacity(swipeProgress * 0.08),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 200
                )
                .animation(.easeOut(duration: 0.4), value: swipeProgress)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Minimaler Content
                VStack(spacing: 40) {
                    // Einfaches Icon
                    Image(systemName: "music.note")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.8))
                        .scaleEffect(iconScale)
                        .opacity(textOpacity)
                    
                    // Clean Typography
                    VStack(spacing: 16) {
                        HStack(spacing: 0) {
                            Text("pre")
                                .font(.system(size: 24, weight: .thin, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                                .tracking(1.5)
                            
                            Text("laud")
                                .font(.system(size: 24, weight: .thin, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1.5)
                        }
                        .opacity(textOpacity)
                        
                        // Minimal Swipe Hint
                        VStack(spacing: 8) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 12, weight: .ultraLight))
                                .foregroundColor(.white.opacity(0.3))
                                .scaleEffect(1.0 + swipeProgress * 0.2)
                            
                            Text("swipe up")
                                .font(.system(size: 11, weight: .light, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(1.0)
                                .opacity(1.0 - swipeProgress * 0.5)
                        }
                        .opacity(textOpacity * 0.8)
                    }
                }
                
                Spacer()
                Spacer()
            }
        }
        .gesture(minimalSwipeGesture)
    }
    
    // MARK: - Gesture Handling
    private var minimalSwipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height < 0 {
                    let progress = min(1.0, abs(value.translation.height) / 100.0)
                    
                    withAnimation(.linear(duration: 0.1)) {
                        swipeProgress = progress
                        textOpacity = 1.0 - progress * 0.5
                        iconScale = 1.0 + progress * 0.1
                    }
                    
                    if progress > 0.7 && swipeProgress <= 0.7 {
                        HapticFeedbackManager.shared.lightImpact()
                    }
                }
            }
            .onEnded { value in
                let threshold: CGFloat = -50
                
                if value.translation.height < threshold {
                    startSeamlessTransition()
                } else {
                    resetToInitialState()
                }
            }
    }
    
    private func startSeamlessTransition() {
        HapticFeedbackManager.shared.mediumImpact()
        
        isTransitioning = true
        transitionPhase = .preparing
        
        withAnimation(.easeInOut(duration: 1.2)) {
            textOpacity = 0
            iconScale = 0.8
            welcomeScale = 0.9
            welcomeOffset = -50
            revealProgress = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showWelcome = false
            isTransitioning = false
            transitionPhase = .complete
            
            resetAllStates()
        }
    }
    
    private func resetToInitialState() {
        withAnimation(.easeOut(duration: 0.3)) {
            swipeProgress = 0
            textOpacity = 1.0
            iconScale = 1.0
        }
    }
    
    private func resetAllStates() {
        swipeProgress = 0
        textOpacity = 1.0
        iconScale = 1.0
        revealProgress = 0
        welcomeScale = 1.0
        welcomeOffset = 0
        transitionPhase = .waiting
    }
}
