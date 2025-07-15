//
//  StreamingServicePreview.swift - WITH WORKING SHARE FUNCTIONALITY
//  MusicPreview
//
//  Updated to include functional share album capability
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
            AlbumShareSheet(album: album)
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
                        Color.clear.frame(height: audioPlayer.currentSong != nil ? 140 : 40)
                    }
                }
                .coordinateSpace(name: "scroll")
                
                // Sticky Header with Back Button
                stickyHeader
                
                // Mini Player Overlay
                VStack {
                    Spacer()
                    
                    if audioPlayer.currentSong != nil {
                        AdaptiveMiniPlayer(service: .spotify)
                            .background(
                                Rectangle()
                                    .fill(.clear)
                                    .background(.ultraThinMaterial.opacity(0.05))
                                    .ignoresSafeArea(.container, edges: .bottom)
                            )
                    }
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .actionSheet(isPresented: $showingOptions) {
            albumOptionsSheet
        }
    }
    
    // MARK: - Background
    private var spotifyBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.25, green: 0.25, blue: 0.25),
                Color(red: 0.15, green: 0.15, blue: 0.15),
                Color(red: 0.05, green: 0.05, blue: 0.05),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        GeometryReader { headerGeometry in
            VStack(spacing: 0) {
                Color.clear.frame(height: 70)
                albumCover
                albumInfo
                controlButtons
                Color.clear.frame(height: 10)
            }
            .onAppear {
                let offset = headerGeometry.frame(in: .named("scroll")).minY
                scrollOffset = -offset
            }
            .onChange(of: headerGeometry.frame(in: .named("scroll")).minY) { _, newValue in
                scrollOffset = -newValue
            }
        }
    }
    
    private var albumCover: some View {
        Group {
            if let coverImage = album.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 232, height: 232)
            } else {
                Rectangle()
                    .fill(Color(red: 0.3, green: 0.3, blue: 0.3))
                    .frame(width: 232, height: 232)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
    }
    
    private var albumInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 24)
            
            HStack {
                Text(album.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            Color.clear.frame(height: 8)
            
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 0.4, green: 0.4, blue: 0.4))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    )
                
                Text(album.artist)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            Color.clear.frame(height: 8)
            
            HStack {
                Text("Album • 2025")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 16)
            
            Color.clear.frame(height: 8)
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 0) {
            likeButton
            Spacer().frame(width: 20)
            additionalButtons
            Spacer()
            playbackButtons
        }
        .padding(.horizontal, 16)
    }
    
    private var likeButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isLiked.toggle()
            }
            HapticFeedbackManager.shared.lightImpact()
        }) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                .frame(width: 28, height: 36)
                .overlay(
                    Group {
                        if let coverImage = album.coverImage {
                            Image(uiImage: coverImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 24, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        } else {
                            Rectangle()
                                .fill(Color(red: 0.3, green: 0.3, blue: 0.3))
                                .frame(width: 24, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.3))
                                )
                        }
                    }
                )
        }
        .buttonStyle(MinimalButtonStyle())
    }
    
    private var additionalButtons: some View {
        HStack(spacing: 20) {
            Button(action: {}) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(MinimalButtonStyle())
            
            Button(action: {}) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(MinimalButtonStyle())
            
            // SHARE BUTTON - Updated to use onShare
            Button(action: {
                HapticFeedbackManager.shared.lightImpact()
                onShare()
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(MinimalButtonStyle())
        }
    }
    
    private var playbackButtons: some View {
        HStack(spacing: 16) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isShuffleActive.toggle()
                }
                HapticFeedbackManager.shared.selection()
            }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 24))
                    .foregroundColor(isShuffleActive ? Color(red: 0.11, green: 0.73, blue: 0.33) : .white.opacity(0.7))
            }
            .buttonStyle(MinimalButtonStyle())
            
            Button(action: {
                if let firstSong = album.songs.first {
                    HapticFeedbackManager.shared.playPause()
                    audioPlayer.play(song: firstSong)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .offset(x: audioPlayer.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(MinimalButtonStyle())
        }
    }
    
    // MARK: - Songs Section
    private var songsSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(album.songs.enumerated()), id: \.element.id) { index, song in
                SpotifySongRowFixed(
                    song: song,
                    index: index,
                    isCurrentSong: audioPlayer.currentSong?.id == song.id,
                    isPlaying: audioPlayer.currentSong?.id == song.id && audioPlayer.isPlaying,
                    onTap: {
                        HapticFeedbackManager.shared.songSelected()
                        audioPlayer.play(song: song)
                    }
                )
            }
        }
        .background(Color.clear)
    }
    
    // MARK: - Sticky Header
    private var stickyHeader: some View {
        VStack {
            HStack {
                Button(action: {
                    HapticFeedbackManager.shared.navigationBack()
                    onBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.black.opacity(0.3))
                        )
                }
                .buttonStyle(MinimalButtonStyle())
                .padding(.leading, 20)
                .padding(.top, 50)
                
                Spacer()
                
                if scrollOffset > 280 {
                    Text(album.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .transition(.opacity)
                        .padding(.top, 50)
                }
                
                Spacer()
                
                if scrollOffset > 280 {
                    stickyPlayButton
                        .transition(.opacity)
                        .padding(.trailing, 20)
                        .padding(.top, 50)
                } else {
                    Color.clear
                        .frame(width: 32, height: 32)
                        .padding(.trailing, 20)
                        .padding(.top, 50)
                }
            }
            
            Spacer()
        }
    }
    
    private var stickyPlayButton: some View {
        Button(action: {
            if let firstSong = album.songs.first {
                HapticFeedbackManager.shared.playPause()
                audioPlayer.play(song: firstSong)
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                    .frame(width: 32, height: 32)
                
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
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
