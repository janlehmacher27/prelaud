//
//  StreamingServicePreview.swift - FIXED VERSION
//  MusicPreview
//
//  Fixed missing onDismiss parameter in AlbumShareSheet
//

import SwiftUI

struct StreamingServicePreview: View {
    let album: Album
    let service: StreamingService
    let onBack: () -> Void
    
    @State private var showingShareSheet = false
    
    var body: some View {
        Group {
            switch service {
            case .spotify:
                ImprovedSpotifyView(album: album, onBack: onBack)
            case .appleMusic:
                AppleMusicAlbumView(album: album, onBack: onBack)
            case .amazonMusic:
                AmazonMusicAlbumView(album: album, onBack: onBack)
            case .youtubeMusic:
                YouTubeMusicAlbumView(album: album, onBack: onBack)
            }
        }
        .overlay(
            // Share Button Overlay für alle Services
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        HapticFeedbackManager.shared.lightImpact()
                        showingShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(service == .appleMusic ? .black.opacity(0.8) : .white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(service == .appleMusic ? .white.opacity(0.8) : .black.opacity(0.3))
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                
                Spacer()
            }
        )
        .sheet(isPresented: $showingShareSheet) {
            // FIXED: Added onDismiss parameter
            AlbumShareSheet(album: album, onDismiss: {
                showingShareSheet = false
            })
        }
    }
}

// MARK: - Spotify View with Share
struct ImprovedSpotifyViewWithShare: View {
    let album: Album
    let onBack: () -> Void
    let onShare: () -> Void
    @State private var scrollOffset: CGFloat = 0
    @State private var isLiked = false
    @State private var isShuffleActive = false
    @State private var showingOptions = false
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Spotify Gradient Background
                spotifyBackground
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header Section
                        headerSection
                            .frame(height: 478)
                        
                        // Songs List
                        songsSection
                        
                        // Bottom spacing for mini player
                        Color.clear.frame(height: audioPlayer.currentSong != nil ? 80 : 20)
                    }
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
                
                // Header Blur Effect
                if scrollOffset > 200 {
                    VStack {
                        headerBlurOverlay
                        Spacer()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .actionSheet(isPresented: $showingOptions) {
            albumOptionsSheet
        }
    }
    
    // MARK: - Spotify Background
    private var spotifyBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.12, blue: 0.12),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Navigation
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: { showingOptions = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            
            Spacer()
            
            // Album Cover
            albumCoverSection
            
            // Album Info
            albumInfoSection
            
            // Control Buttons
            controlButtonsSection
        }
    }
    
    // MARK: - Album Cover Section
    private var albumCoverSection: some View {
        VStack {
            if let coverImage = album.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: min(UIScreen.main.bounds.width - 48, 300))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .frame(width: min(UIScreen.main.bounds.width - 48, 300), height: min(UIScreen.main.bounds.width - 48, 300))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                    )
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
            }
        }
    }
    
    // MARK: - Album Info Section
    private var albumInfoSection: some View {
        VStack(spacing: 8) {
            Text(album.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(album.artist)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Text("\(album.songs.count) songs")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Control Buttons Section
    private var controlButtonsSection: some View {
        HStack(spacing: 32) {
            // Heart Button
            Button(action: { isLiked.toggle() }) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 24))
                    .foregroundColor(isLiked ? .green : .white.opacity(0.7))
            }
            
            // Download Button
            Button(action: {}) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Share Button
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Options Button
            Button(action: { showingOptions = true }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Shuffle Button
            Button(action: { isShuffleActive.toggle() }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isShuffleActive ? .green : .white.opacity(0.7))
            }
            
            // Play Button
            playButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Songs Section
    private var songsSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(album.songs.enumerated()), id: \.element.id) { index, song in
                SpotifySongRow(
                    song: song,
                    trackNumber: index + 1,
                    isPlaying: audioPlayer.currentSong?.id == song.id && audioPlayer.isPlaying,
                    onTap: {
                        if audioPlayer.currentSong?.id == song.id {
                            audioPlayer.togglePlayback()
                        } else {
                            audioPlayer.play(song: song)
                        }
                    }
                )
                .padding(.horizontal, 20)
            }
        }
        .background(Color.black)
    }
    
    // MARK: - Header Blur Overlay
    private var headerBlurOverlay: some View {
        VStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text(album.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { showingOptions = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(
            Color.black.opacity(0.8)
                .background(.ultraThinMaterial, in: Rectangle())
        )
    }
    
    // MARK: - Play Button
    private var playButton: some View {
        Button(action: {
            if let firstSong = album.songs.first {
                if audioPlayer.currentSong?.id == firstSong.id {
                    audioPlayer.togglePlayback()
                } else {
                    audioPlayer.play(song: firstSong)
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(.green)
                    .frame(width: 56, height: 56)
                
                Image(systemName: audioPlayer.isPlaying && album.songs.contains(where: { $0.id == audioPlayer.currentSong?.id }) ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .offset(x: audioPlayer.isPlaying ? 0 : 1)
            }
        }
        .buttonStyle(MinimalButtonStyle())
    }
    
    // MARK: - Action Sheet (Updated)
    private var albumOptionsSheet: ActionSheet {
        ActionSheet(
            title: Text("Album Options"),
            buttons: [
                .default(Text("Add to Playlist")),
                .default(Text("Add to Library")),
                .default(Text("Album Radio")),
                .default(Text("Share")) { onShare() }, // Use the share callback
                .default(Text("View Artist")),
                .default(Text("Show Credits")),
                .cancel(Text("Cancel"))
            ]
        )
    }
}

// MARK: - Spotify Song Row
struct SpotifySongRow: View {
    let song: Song
    let trackNumber: Int
    let isPlaying: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Track Number or Play Indicator
                ZStack {
                    Text("\(trackNumber)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(isPlaying ? 0 : 0.5))
                    
                    if isPlaying {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                }
                .frame(width: 24)
                
                // Song Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isPlaying ? .green : .white)
                        .lineLimit(1)
                    
                    if !song.artist.isEmpty {
                        Text(song.artist)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Duration
                Text(formatDuration(song.duration))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                
                // More Options
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Other Service Views (Simplified versions with share)
struct AppleMusicAlbumViewWithShare: View {
    let album: Album
    let onBack: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        // Use existing AppleMusicAlbumView but add share button in toolbar
        AppleMusicAlbumView(album: album, onBack: onBack)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.black.opacity(0.8))
                    }
                }
            }
    }
}

struct AmazonMusicAlbumViewWithShare: View {
    let album: Album
    let onBack: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        AmazonMusicAlbumView(album: album, onBack: onBack)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
    }
}

struct YouTubeMusicAlbumViewWithShare: View {
    let album: Album
    let onBack: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        YouTubeMusicAlbumView(album: album, onBack: onBack)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
    }
}
