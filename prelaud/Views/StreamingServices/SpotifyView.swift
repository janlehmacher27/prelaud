//
//  SpotifyView.swift - FIXED BOTTOM CLIPPING
//  MusicPreview
//
//  Fixed mini player clipping and improved layout
//

import SwiftUI

struct ImprovedSpotifyView: View {
    let album: Album
    let onBack: () -> Void
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
                        
                        // FIXED: Mehr Bottom Spacing für Mini Player
                        Color.clear.frame(height: audioPlayer.currentSong != nil ? 140 : 40)
                    }
                }
                .coordinateSpace(name: "scroll")
                
                // Sticky Header with Back Button
                stickyHeader
                
                // FIXED: Mini Player Overlay mit korrekter Positionierung
                VStack {
                    Spacer()
                    
                    if audioPlayer.currentSong != nil {
                        AdaptiveMiniPlayer(service: .spotify)
                            .background(
                                // Zusätzlicher Hintergrund für bessere Sichtbarkeit
                                Rectangle()
                                    .fill(.clear)
                                    .background(.ultraThinMaterial.opacity(0.05))
                                    .ignoresSafeArea(.container, edges: .bottom)
                            )
                    }
                }
                .ignoresSafeArea(.container, edges: .bottom) // FIXED: Safe Area ignorieren
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
                // Top margin
                Color.clear.frame(height: 70)
                
                // Album cover
                albumCover
                
                // Album info
                albumInfo
                
                // Control buttons
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
            
            // Album title
            HStack {
                Text(album.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            Color.clear.frame(height: 8)
            
            // Artist with avatar
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
            
            // Metadata
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
            // Like button
            likeButton
            
            Spacer().frame(width: 20)
            
            // Additional buttons
            additionalButtons
            
            Spacer()
            
            // Shuffle and play buttons
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
            
            Button(action: { showingOptions = true }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(MinimalButtonStyle())
        }
    }
    
    private var playbackButtons: some View {
        HStack(spacing: 16) {
            // Shuffle button
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
            
            // Main play button
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
                // Back button (always visible)
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
                
                // Album title (when scrolled)
                if scrollOffset > 280 {
                    Text(album.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .transition(.opacity)
                        .padding(.top, 50)
                }
                
                Spacer()
                
                // Sticky play button (when scrolled)
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
    
    // MARK: - Action Sheet
    private var albumOptionsSheet: ActionSheet {
        ActionSheet(
            title: Text("Album Options"),
            buttons: [
                .default(Text("Add to Playlist")),
                .default(Text("Add to Library")),
                .default(Text("Album Radio")),
                .default(Text("Share")),
                .default(Text("View Artist")),
                .default(Text("Show Credits")),
                .cancel(Text("Cancel"))
            ]
        )
    }
}

// MARK: - FIXED Song Row Component
struct SpotifySongRowFixed: View {
    let song: Song
    let index: Int
    let isCurrentSong: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Song title with EQ indicator
                HStack(spacing: 8) {
                    // Animated EQ indicator for currently playing song
                    if isCurrentSong && isPlaying {
                        AnimatedEQIndicator()
                    }
                    
                    Text(song.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isCurrentSong ?
                                       Color(red: 0.11, green: 0.73, blue: 0.33) : .white)
                        .lineLimit(1)
                }
                
                // Artist with explicit badge
                HStack(spacing: 4) {
                    if song.isExplicit {
                        Text("E")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 15, height: 15)
                            .background(Color.white.opacity(0.6))
                            .cornerRadius(2)
                    }
                    
                    Text(song.artist)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // More options button (only this remains on the right)
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(MinimalButtonStyle())
        }
        .frame(height: 64)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .background(
            isCurrentSong ?
            Color.white.opacity(0.05) : Color.clear
        )
    }
}

// MARK: - Animated EQ Indicator
struct AnimatedEQIndicator: View {
    @State private var animationValues: [CGFloat] = [0.3, 0.7, 0.4]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                    .frame(width: 2, height: 12 * animationValues[index])
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.5...1.2))
                        .repeatForever(autoreverses: true),
                        value: animationValues[index]
                    )
            }
        }
        .frame(width: 10, height: 12)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        for index in 0..<3 {
            Timer.scheduledTimer(withTimeInterval: Double.random(in: 0.1...0.3), repeats: true) { _ in
                withAnimation {
                    animationValues[index] = CGFloat.random(in: 0.3...1.0)
                }
            }
        }
    }
}

#Preview {
    ImprovedSpotifyView(
        album: Album(
            title: "Test Album",
            artist: "Test Artist",
            songs: [
                Song(title: "Test Song 1", artist: "Test Artist", duration: 180),
                Song(title: "Test Song 2", artist: "Test Artist", duration: 210)
            ],
            coverImage: nil as UIImage?,
            releaseDate: Date()
        ),
        onBack: { }
    )
}
