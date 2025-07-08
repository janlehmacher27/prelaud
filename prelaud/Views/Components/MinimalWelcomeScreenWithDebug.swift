//
//  MinimalWelcomeScreenWithDebug.swift
//  prelaud
//
//  Created by Jan Lehmacher on 14.07.25.
//


//
//  Debug Setup Trigger - Ergänzung für MinimalWelcomeScreen
//  Füge diese Funktionen zu deiner MinimalWelcomeScreen hinzu
//

import SwiftUI

// MARK: - Erweiterte MinimalWelcomeScreen mit Debug-Funktion
struct MinimalWelcomeScreenWithDebug: View {
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
    
    // 🚧 DEBUG: Setup Reset Funktionalität
    @State private var debugTapCount = 0
    @State private var showDebugMenu = false
    @StateObject private var profileManager = UserProfileManager.shared
    
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
                    // Einfaches Icon - TAPPABLE für Debug
                    Image(systemName: "music.note")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.8))
                        .scaleEffect(iconScale)
                        .opacity(textOpacity)
                        .onTapGesture {
                            #if DEBUG
                            handleDebugTap()
                            #endif
                        }
                    
                    // Clean Typography
                    VStack(spacing: 16) {
                        HStack(spacing: 0) {
                            Text("pre")
                                .font(.system(size: 24, weight: .thin, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                                .tracking(1.5)
                                .onTapGesture {
                                    #if DEBUG
                                    handleDebugTap()
                                    #endif
                                }
                            
                            Text("laud")
                                .font(.system(size: 24, weight: .thin, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1.5)
                                .onTapGesture {
                                    #if DEBUG
                                    handleDebugTap()
                                    #endif
                                }
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
            
            // 🚧 DEBUG MENU (nur in Debug-Builds)
            #if DEBUG
            if showDebugMenu {
                debugMenuOverlay
            }
            #endif
        }
        .gesture(minimalSwipeGesture)
        .onTapGesture {
            startSeamlessTransition()
        }
    }
    
    // MARK: - 🚧 DEBUG FUNCTIONS
    
    #if DEBUG
    private func handleDebugTap() {
        debugTapCount += 1
        HapticFeedbackManager.shared.lightImpact()
        
        print("🚧 DEBUG: Tap count = \(debugTapCount)")
        
        if debugTapCount >= 5 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showDebugMenu = true
            }
            debugTapCount = 0
        }
        
        // Reset counter nach 3 Sekunden
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.debugTapCount > 0 {
                self.debugTapCount = 0
            }
        }
    }
    
    private var debugMenuOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showDebugMenu = false
                    }
                }
            
            // Debug Menu
            VStack(spacing: 24) {
                // Title
                Text("🚧 DEBUG MENU")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(1.0)
                
                // Buttons
                VStack(spacing: 16) {
                    debugButton(
                        title: "Reset Profile Setup",
                        subtitle: "Simulate first-time setup",
                        icon: "person.crop.circle.badge.minus"
                    ) {
                        profileManager.resetProfileForFirstTimeSetup()
                        HapticFeedbackManager.shared.heavyImpact()
                        showDebugMenu = false
                    }
                    
                    debugButton(
                        title: "Create Test Profile",
                        subtitle: "Skip setup with test data",
                        icon: "person.crop.circle.badge.plus"
                    ) {
                        profileManager.createDebugProfile()
                        HapticFeedbackManager.shared.success()
                        showDebugMenu = false
                        startSeamlessTransition()
                    }
                    
                    debugButton(
                        title: "Show Profile Status",
                        subtitle: "Print current profile info",
                        icon: "info.circle"
                    ) {
                        profileManager.debugProfileStatus()
                        HapticFeedbackManager.shared.lightImpact()
                    }
                }
                
                // Close Button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showDebugMenu = false
                    }
                }) {
                    Text("close")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(0.5)
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 40)
        }
    }
    
    private func debugButton(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(UltraMinimalButtonStyle())
    }
    #endif
    
    // MARK: - Original Functions (unverändert)
    
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

// MARK: - Integration in ContentView.swift
// Ersetze einfach 'MinimalWelcomeScreen' durch 'MinimalWelcomeScreenWithDebug'

/* 
ANLEITUNG:
1. In ContentView.swift ändere:
   MinimalWelcomeScreen(...) 
   zu:
   MinimalWelcomeScreenWithDebug(...)

2. Debug-Aktivierung:
   - 5x schnell auf das Icon oder "prelaud" Logo tippen
   - Debug-Menu erscheint mit 3 Optionen
   
3. Funktionen:
   - "Reset Profile Setup": Löscht Profil → nächster Start zeigt Setup
   - "Create Test Profile": Erstellt Test-Profil und überspringt Setup  
   - "Show Profile Status": Printet Debug-Info in Konsole
*/