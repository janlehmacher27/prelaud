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
    @StateObject private var supabaseManager = SupabaseAudioManager.shared
    @StateObject private var dataManager = DataPersistenceManager.shared
    @StateObject private var profileManager = UserProfileManager.shared
    
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
                // Normale App-Flows
                mainAppContent
            }
        }
        .onAppear {
            #if DEBUG
            debugSupabaseConnection()
            #endif
            
            supabaseManager.migrateFromDropbox()
            
            if albums.isEmpty {
                albums = dataManager.savedAlbums
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
            .opacity(showWelcome ? 0.0 : 1.0)
            .scaleEffect(showWelcome ? 0.95 : 1.0)
            .offset(y: showWelcome ? 20 : 0)
            .animation(.easeInOut(duration: 1.0), value: showWelcome)
            .zIndex(0)
            
            // NAHTLOSER ÜBERGANGS-EFFEKT
            if isTransitioning {
                WipeTransitionEffect(progress: revealProgress)
                    .zIndex(1)
            }
            
            // Upload View
            if showingUpload {
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
                .zIndex(3)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // WELCOME SCREEN - verschwindet nahtlos
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
                .zIndex(2)
            }
            
            // Fullscreen Album Preview
            if let album = currentAlbum {
                StreamingServicePreview(
                    album: album,
                    service: selectedService,
                    onBack: {
                        HapticFeedbackManager.shared.navigationBack()
                        withAnimation(.smooth(duration: 0.4)) {
                            currentAlbum = nil
                        }
                    }
                )
                .ignoresSafeArea()
                .zIndex(4)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                        
                        Text("swipe up to continue")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.white.opacity(0.4))
                            .opacity(textOpacity * (1.0 - swipeProgress))
                    }
                }
                
                Spacer()
                
                // Minimaler Swipe Indicator
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.white.opacity(0.2))
                                .frame(width: 24, height: 1)
                                .opacity(1.0 - swipeProgress * Double(index + 1))
                        }
                    }
                    
                    Text("swipe")
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                        .tracking(0.5)
                        .opacity(1.0 - swipeProgress * 2)
                }
                .padding(.bottom, 50)
            }
        }
        .gesture(minimalSwipeGesture)
        .onTapGesture {
            startSeamlessTransition()
        }
    }
    
    // MARK: - MINIMAL SWIPE GESTURE
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
                    
                    // Minimales Haptic Feedback
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
    
    // MARK: - NAHTLOSER ÜBERGANG
    private func startSeamlessTransition() {
        HapticFeedbackManager.shared.mediumImpact()
        
        isTransitioning = true
        transitionPhase = .preparing
        
        // Nahtloser Cross-Fade
        withAnimation(.easeInOut(duration: 1.2)) {
            textOpacity = 0
            iconScale = 0.8
            welcomeScale = 0.9
            welcomeOffset = -50
            revealProgress = 1.0
        }
        
        // Welcome Screen entfernen nach Animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showWelcome = false
            isTransitioning = false
            transitionPhase = .complete
            
            resetAllStates()
        }
    }
    
    // MARK: - Reset Functions
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

// MARK: - NAHTLOSER WIPE ÜBERGANG
struct WipeTransitionEffect: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            // Vertikaler Wipe von unten nach oben
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.8),
                    Color.clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .offset(y: -progress * UIScreen.main.bounds.height)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.2), value: progress)
            
            // Subtiler Lichtstreifen
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(height: 60)
                .offset(y: -progress * (UIScreen.main.bounds.height + 60))
                .ignoresSafeArea()
                .animation(.easeOut(duration: 1.0), value: progress)
        }
    }
}
