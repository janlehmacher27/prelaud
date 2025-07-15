//
//  AlbumShareSheet.swift - MINIMAL DESIGN VERSION
//  prelaud
//
//  Ultra-minimal share sheet matching app's aesthetic
//

import SwiftUI

struct AlbumShareSheet: View {
    let album: Album
    @Environment(\.dismiss) private var dismiss
    
    @State private var targetUsername = ""
    @State private var isSharing = false
    @State private var shareResult: String?
    @State private var shareError: String?
    @State private var canDownload = false
    @State private var showAdvancedOptions = false
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Consistent background gradient matching the app
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Minimal header
                headerSection
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                
                // Content area
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 40) {
                        // Album preview - ultra minimal
                        albumPreviewSection
                        
                        // Share form - clean and simple
                        shareFormSection
                        
                        // Advanced options - collapsible
                        advancedOptionsSection
                        
                        // Share action
                        shareActionSection
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
        .onTapGesture {
            // Dismiss keyboard on background tap
            isTextFieldFocused = false
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button("cancel") {
                HapticFeedbackManager.shared.lightImpact()
                dismiss()
            }
            .font(.system(size: 11, weight: .light, design: .monospaced))
            .foregroundColor(.white.opacity(0.4))
            .tracking(1.0)
            
            Spacer()
            
            Text("share")
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .tracking(1.0)
            
            Spacer()
            
            // Invisible balance button
            Text("cancel")
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.clear)
                .tracking(1.0)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Album Preview
    private var albumPreviewSection: some View {
        VStack(spacing: 24) {
            // Cover - minimal square
            Group {
                if let coverImage = album.coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.02))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundColor(.white.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.05), lineWidth: 0.5)
                        )
                }
            }
            
            // Info - minimal typography
            VStack(spacing: 8) {
                Text(album.title)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Text("by \(album.artist)")
                    .font(.system(size: 11, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(0.5)
                
                Text("\(album.songs.count) songs")
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
                    .tracking(0.5)
            }
        }
    }
    
    // MARK: - Share Form
    private var shareFormSection: some View {
        VStack(spacing: 24) {
            // Username input - ultra minimal
            VStack(spacing: 16) {
                HStack {
                    Text("with")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.0)
                    
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("@")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.white.opacity(0.3))
                        
                        TextField("", text: $targetUsername)
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.white.opacity(0.8))
                            .textFieldStyle(PlainTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isTextFieldFocused)
                    }
                    
                    // Minimal underline
                    Rectangle()
                        .fill(isTextFieldFocused ? .white.opacity(0.3) : .white.opacity(0.08))
                        .frame(height: 0.5)
                        .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)
                    
                    // Status text
                    if !targetUsername.isEmpty {
                        HStack {
                            Text("album will be shared with @\(targetUsername)")
                                .font(.system(size: 9, weight: .light, design: .monospaced))
                                .foregroundColor(.white.opacity(0.25))
                                .tracking(0.5)
                            
                            Spacer()
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }
    
    // MARK: - Advanced Options
    private var advancedOptionsSection: some View {
        VStack(spacing: 16) {
            // Toggle for advanced options
            Button(action: {
                HapticFeedbackManager.shared.lightImpact()
                withAnimation(.smooth(duration: 0.3)) {
                    showAdvancedOptions.toggle()
                }
            }) {
                HStack {
                    Text("permissions")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.0)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.2))
                        .rotationEffect(.degrees(showAdvancedOptions ? 90 : 0))
                        .animation(.smooth(duration: 0.3), value: showAdvancedOptions)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Collapsible options
            if showAdvancedOptions {
                VStack(spacing: 16) {
                    // Listen permission (always on)
                    permissionRow(
                        icon: "play.circle",
                        title: "can listen",
                        subtitle: "play all songs",
                        isOn: .constant(true),
                        disabled: true
                    )
                    
                    // Download permission
                    permissionRow(
                        icon: "arrow.down.circle",
                        title: "can download",
                        subtitle: "save for offline",
                        isOn: $canDownload,
                        disabled: false
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func permissionRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>, disabled: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(disabled ? 0.2 : 0.4))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.white.opacity(disabled ? 0.3 : 0.6))
                
                Text(subtitle)
                    .font(.system(size: 9, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(disabled ? 0.15 : 0.25))
                    .tracking(0.5)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .toggleStyle(MinimalToggleStyle())
                .disabled(disabled)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Share Action
    private var shareActionSection: some View {
        VStack(spacing: 20) {
            // Share button - minimal
            Button(action: shareAlbum) {
                HStack(spacing: 8) {
                    if isSharing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black.opacity(0.8)))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .light))
                    }
                    
                    Text(isSharing ? "sharing" : "share album")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .tracking(1.0)
                }
                .foregroundColor(.black.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(canShare ? .white.opacity(0.9) : .white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white.opacity(canShare ? 0 : 0.05), lineWidth: 0.5)
                        )
                )
            }
            .disabled(!canShare)
            .animation(.easeInOut(duration: 0.2), value: canShare)
            .animation(.easeInOut(duration: 0.2), value: isSharing)
            
            // Result messages - minimal
            resultMessages
        }
    }
    
    private var resultMessages: some View {
        VStack(spacing: 12) {
            if let result = shareResult {
                HStack {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(result)
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(0.5)
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            if let error = shareError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(error)
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(0.5)
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }
    
    // MARK: - Computed Properties
    private var canShare: Bool {
        !targetUsername.isEmpty && !isSharing
    }
    
    // MARK: - Actions
    private func shareAlbum() {
        guard canShare else { return }
        
        HapticFeedbackManager.shared.mediumImpact()
        isSharing = true
        shareResult = nil
        shareError = nil
        
        // Dismiss keyboard
        isTextFieldFocused = false
        
        // Simulate sharing process
        Task {
            do {
                // Simulate network delay
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                await MainActor.run {
                    isSharing = false
                    shareResult = "shared with @\(targetUsername)"
                    
                    HapticFeedbackManager.shared.success()
                    
                    // Auto-dismiss after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                }
                
            } catch {
                await MainActor.run {
                    isSharing = false
                    shareError = "sharing failed"
                    
                    HapticFeedbackManager.shared.error()
                    
                    // Clear error after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.shareError = nil
                    }
                }
            }
        }
    }
}

// MARK: - Minimal Toggle Style
struct MinimalToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            Button(action: {
                HapticFeedbackManager.shared.lightImpact()
                configuration.isOn.toggle()
            }) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isOn ? .white.opacity(0.8) : .white.opacity(0.05))
                    .frame(width: 32, height: 18)
                    .overlay(
                        Circle()
                            .fill(configuration.isOn ? .black.opacity(0.8) : .white.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .offset(x: configuration.isOn ? 6 : -6)
                            .animation(.smooth(duration: 0.2), value: configuration.isOn)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(configuration.isOn ? 0 : 0.1), lineWidth: 0.5)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

#Preview {
    AlbumShareSheet(
        album: Album(
            title: "Test Album",
            artist: "Test Artist",
            songs: [
                Song(title: "Test Song", artist: "Test Artist", duration: 180)
            ],
            coverImage: nil,
            releaseDate: Date()
        )
    )
}
