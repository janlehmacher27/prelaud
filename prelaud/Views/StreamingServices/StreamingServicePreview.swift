//
//  StreamingServicePreview.swift - WITH ADAPTIVE MINI PLAYER
//  MusicPreview
//
//  Updated to use service-specific mini players
//

import SwiftUI

struct StreamingServicePreview: View {
    let album: Album
    let service: StreamingService
    let onBack: () -> Void
    
    var body: some View {
        switch service {
        case .spotify:
            ImprovedSpotifyViewWithAdaptivePlayer(album: album, onBack: onBack)
        case .appleMusic:
            AppleMusicAlbumViewWithAdaptivePlayer(album: album, onBack: onBack)
        case .amazonMusic:
            AmazonMusicAlbumViewWithAdaptivePlayer(album: album, onBack: onBack)
        case .youtubeMusic:
            YouTubeMusicAlbumViewWithAdaptivePlayer(album: album, onBack: onBack)
        }
    }
}

// MARK: - Apple Music View with Adaptive Player
struct AppleMusicAlbumViewWithAdaptivePlayer: View {
    let album: Album
    let onBack: () -> Void
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.98, blue: 0.98),
                    Color(red: 0.95, green: 0.95, blue: 0.97)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.98, green: 0.98, blue: 0.98)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 500)
                        
                        VStack(spacing: 30) {
                            Spacer(minLength: 80)
                            
                            if let coverImage = album.coverImage {
                                Image(uiImage: coverImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 300, height: 300)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 300, height: 300)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 80))
                                            .foregroundColor(.gray.opacity(0.3))
                                    )
                                    .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
                            }
                            
                            VStack(spacing: 16) {
                                Text(album.title)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.black)
                                
                                Text(album.artist)
                                    .font(.system(size: 20))
                                    .foregroundColor(.black.opacity(0.6))
                                
                                Text("Album • 2024")
                                    .font(.system(size: 16))
                                    .foregroundColor(.black.opacity(0.4))
                            }
                        }
                    }
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 20) {
                            Button(action: {
                                if let firstSong = album.songs.first {
                                    audioPlayer.play(song: firstSong)
                                }
                            }) {
                                Label(audioPlayer.isPlaying ? "Pause" : "Play", systemImage: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 140, height: 50)
                                    .background(Color(red: 0.98, green: 0.26, blue: 0.40))
                                    .cornerRadius(25)
                            }
                            
                            Button(action: {}) {
                                Label("Shuffle", systemImage: "shuffle")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(Color(red: 0.98, green: 0.26, blue: 0.40))
                                    .frame(width: 140, height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(Color(red: 0.98, green: 0.26, blue: 0.40), lineWidth: 2)
                                    )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    VStack(spacing: 0) {
                        ForEach(Array(album.songs.enumerated()), id: \.element.id) { index, song in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(song.title)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(audioPlayer.currentSong?.id == song.id ?
                                                           Color(red: 0.98, green: 0.26, blue: 0.40) : .black)
                                        
                                        if audioPlayer.currentSong?.id == song.id && audioPlayer.isPlaying {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(red: 0.98, green: 0.26, blue: 0.40))
                                        }
                                    }
                                    
                                    HStack(spacing: 4) {
                                        if song.isExplicit {
                                            Text("E")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 15, height: 15)
                                                .background(Color.gray.opacity(0.6))
                                                .cornerRadius(2)
                                        }
                                        
                                        Text(song.artist)
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {}) {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                audioPlayer.play(song: song)
                            }
                            .background(
                                audioPlayer.currentSong?.id == song.id ?
                                Color(red: 0.98, green: 0.26, blue: 0.40).opacity(0.1) : Color.clear
                            )
                            
                            if index < album.songs.count - 1 {
                                Divider()
                                    .padding(.leading, 65)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            
            // Back Button
            VStack {
                HStack {
                    Button(action: {
                        HapticFeedbackManager.shared.navigationBack()
                        onBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.8))
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .padding(.leading, 20)
                    .padding(.top, 50)
                    
                    Spacer()
                }
                
                Spacer()
            }
            
            // Adaptive Mini Player
            VStack {
                Spacer()
                
                if audioPlayer.isPlaying && audioPlayer.currentSong != nil {
                    AdaptiveMiniPlayer(service: .appleMusic)
                        .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Amazon Music View with Adaptive Player
struct AmazonMusicAlbumViewWithAdaptivePlayer: View {
    let album: Album
    let onBack: () -> Void
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.20, blue: 0.24),
                    Color(red: 0.12, green: 0.16, blue: 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.24, blue: 0.28).opacity(0.8),
                                Color(red: 0.16, green: 0.20, blue: 0.24)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 500)
                        
                        VStack(spacing: 30) {
                            Spacer(minLength: 80)
                            
                            if let coverImage = album.coverImage {
                                Image(uiImage: coverImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 280, height: 280)
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 15)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.20, green: 0.24, blue: 0.28))
                                    .frame(width: 280, height: 280)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 80))
                                            .foregroundColor(.white.opacity(0.3))
                                    )
                                    .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 15)
                            }
                            
                            VStack(spacing: 16) {
                                Text(album.title)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(album.artist)
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Album • 2024 • \(album.songs.count) songs")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            Button(action: {
                                if let firstSong = album.songs.first {
                                    audioPlayer.play(song: firstSong)
                                }
                            }) {
                                HStack {
                                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    Text(audioPlayer.isPlaying ? "Pause" : "Play")
                                }
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 170, height: 50)
                                .background(Color(red: 0.00, green: 0.67, blue: 0.93))
                                .cornerRadius(25)
                            }
                            
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "shuffle")
                                    Text("Shuffle")
                                }
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 170, height: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.white.opacity(0.4), lineWidth: 2)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    VStack(spacing: 0) {
                        ForEach(Array(album.songs.enumerated()), id: \.element.id) { index, song in
                            HStack(spacing: 16) {
                                Text("\(index + 1)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(song.title)
                                            .font(.system(size: 16))
                                            .foregroundColor(audioPlayer.currentSong?.id == song.id ?
                                                           Color(red: 0.00, green: 0.67, blue: 0.93) : .white)
                                        
                                        if audioPlayer.currentSong?.id == song.id && audioPlayer.isPlaying {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(red: 0.00, green: 0.67, blue: 0.93))
                                        }
                                    }
                                    
                                    HStack(spacing: 4) {
                                        if song.isExplicit {
                                            Text("E")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.black)
                                                .frame(width: 15, height: 15)
                                                .background(Color.white.opacity(0.8))
                                                .cornerRadius(2)
                                        }
                                        
                                        Text(song.artist)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                audioPlayer.play(song: song)
                            }
                            .background(
                                audioPlayer.currentSong?.id == song.id ?
                                Color(red: 0.00, green: 0.67, blue: 0.93).opacity(0.1) : Color.clear
                            )
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            
            // Back Button
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
                }
                
                Spacer()
            }
            
            // Adaptive Mini Player
            VStack {
                Spacer()
                
                if audioPlayer.isPlaying && audioPlayer.currentSong != nil {
                    AdaptiveMiniPlayer(service: .amazonMusic)
                        .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - YouTube Music View with Adaptive Player
struct YouTubeMusicAlbumViewWithAdaptivePlayer: View {
    let album: Album
    let onBack: () -> Void
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.15, blue: 0.15),
                                Color.black
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 550)
                        
                        VStack(spacing: 30) {
                            Spacer(minLength: 80)
                            
                            if let coverImage = album.coverImage {
                                Image(uiImage: coverImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 320, height: 320)
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.7), radius: 40, x: 0, y: 20)
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                                    .frame(width: 320, height: 320)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 100))
                                            .foregroundColor(.white.opacity(0.3))
                                    )
                                    .shadow(color: .black.opacity(0.7), radius: 40, x: 0, y: 20)
                            }
                            
                            VStack(spacing: 16) {
                                Text(album.title)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(album.artist)
                                    .font(.system(size: 22))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Album • 2024")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 24) {
                            Button(action: {
                                if let firstSong = album.songs.first {
                                    audioPlayer.play(song: firstSong)
                                }
                            }) {
                                HStack {
                                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    Text(audioPlayer.isPlaying ? "Pause" : "Play")
                                }
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 170, height: 52)
                                .background(Color.white)
                                .cornerRadius(26)
                            }
                            
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "shuffle")
                                    Text("Shuffle")
                                }
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 170, height: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    VStack(spacing: 0) {
                        ForEach(Array(album.songs.enumerated()), id: \.element.id) { index, song in
                            HStack(spacing: 16) {
                                if let coverImage = album.coverImage {
                                    Image(uiImage: coverImage)
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(4)
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(red: 0.20, green: 0.20, blue: 0.20))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .foregroundColor(.white.opacity(0.3))
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(song.title)
                                            .font(.system(size: 16))
                                            .foregroundColor(audioPlayer.currentSong?.id == song.id ?
                                                           Color.red : .white)
                                        
                                        if audioPlayer.currentSong?.id == song.id && audioPlayer.isPlaying {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.red)
                                        }
                                    }
                                    
                                    HStack(spacing: 4) {
                                        if song.isExplicit {
                                            Text("E")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.black)
                                                .frame(width: 15, height: 15)
                                                .background(Color.white.opacity(0.8))
                                                .cornerRadius(2)
                                        }
                                        
                                        Text(song.artist)
                                        Text("•")
                                        Text(album.title)
                                    }
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Button(action: {}) {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(.white.opacity(0.7))
                                        .rotationEffect(.degrees(90))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                audioPlayer.play(song: song)
                            }
                            .background(
                                audioPlayer.currentSong?.id == song.id ?
                                Color.red.opacity(0.1) : Color.clear
                            )
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            
            // Back Button
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
                                    .fill(.black.opacity(0.4))
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .padding(.leading, 20)
                    .padding(.top, 50)
                    
                    Spacer()
                }
                
                Spacer()
            }
            
            // Adaptive Mini Player
            VStack {
                Spacer()
                
                if audioPlayer.isPlaying && audioPlayer.currentSong != nil {
                    AdaptiveMiniPlayer(service: .youtubeMusic)
                        .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Spotify View (already updated in previous artifact)
struct ImprovedSpotifyViewWithAdaptivePlayer: View {
    let album: Album
    let onBack: () -> Void
    
    var body: some View {
        // Use the existing ImprovedSpotifyView which already has the adaptive player
        ImprovedSpotifyView(album: album, onBack: onBack)
    }
}

#Preview {
    StreamingServicePreview(
        album: Album(
            title: "Test Album",
            artist: "Test Artist",
            songs: [
                Song(title: "Test Song 1", artist: "Test Artist", duration: 180),
                Song(title: "Test Song 2", artist: "Test Artist", duration: 210)
            ],
            coverImage: nil,
            releaseDate: Date()
        ),
        service: .spotify,
        onBack: { }
    )
}
