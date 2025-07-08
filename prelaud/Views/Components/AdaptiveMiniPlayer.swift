//
//  AdaptiveMiniPlayer.swift - VERBESSERT MIT AUTHENTISCHEM SPOTIFY DESIGN
//  prelaud
//
//  Fixed bottom clipping and improved Spotify authenticity
//

import SwiftUI

struct AdaptiveMiniPlayer: View {
    let service: StreamingService
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    
    var body: some View {
        if let currentSong = audioPlayer.currentSong {
            Group {
                switch service {
                case .spotify:
                    AuthenticSpotifyMiniPlayer(song: currentSong)
                case .appleMusic:
                    AppleMusicMiniPlayer(song: currentSong)
                case .amazonMusic:
                    AmazonMusicMiniPlayer(song: currentSong)
                case .youtubeMusic:
                    YouTubeMusicMiniPlayer(song: currentSong)
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: audioPlayer.isPlaying)
        }
    }
}

// MARK: - AUTHENTISCHER SPOTIFY MINI PLAYER (wie im echten Spotify)
struct AuthenticSpotifyMiniPlayer: View {
    let song: Song
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @State private var isDragging = false
    @State private var dominantColor: Color = Color(red: 0.2, green: 0.2, blue: 0.2)
    
    var body: some View {
        HStack(spacing: 12) {
            // Album Cover (rund, wie im echten Spotify)
            albumCover
            
            // Song Info
            songInfo
            
            Spacer()
            
            // Controls (nur die wichtigsten)
            spotifyControls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(spotifyMiniPlayerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: -2)
        .padding(.horizontal, 8)
        .padding(.bottom, 8) // Minimaler Abstand wie im echten Spotify
        .onAppear {
            extractDominantColor()
        }
        .onTapGesture {
            // Expand zum Full Player
            HapticFeedbackManager.shared.lightImpact()
        }
    }
    
    private var albumCover: some View {
        Group {
            if let coverImage = song.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(red: 0.18, green: 0.18, blue: 0.18))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.4))
                    )
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 4)) // Leicht abgerundet wie im Screenshot
    }
    
    private var songInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(song.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(song.artist)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
    }
    
    private var spotifyControls: some View {
        HStack(spacing: 16) {
            // Devices Button (Spotify Connect)
            Button(action: {
                HapticFeedbackManager.shared.lightImpact()
            }) {
                Image(systemName: "tv.and.hifispeaker.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(SpotifyButtonStyle())
            
            // Play/Pause Button
            Button(action: {
                HapticFeedbackManager.shared.playPause()
                audioPlayer.togglePlayback()
            }) {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            .buttonStyle(SpotifyButtonStyle())
        }
    }
    
    // MARK: - Dynamic Background basierend auf Album Cover
    private var spotifyMiniPlayerBackground: some View {
        LinearGradient(
            colors: [
                dominantColor.opacity(0.9),
                dominantColor.opacity(0.7),
                Color.black.opacity(0.8)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .overlay(
            // Zusätzlicher dunkler Overlay für bessere Lesbarkeit
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.clear,
                    Color.black.opacity(0.4)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    // MARK: - Extract Dominant Color from Album Cover
    private func extractDominantColor() {
        guard let coverImage = song.coverImage else {
            dominantColor = Color(red: 0.2, green: 0.2, blue: 0.2)
            return
        }
        
        // Vereinfachte Farbextraktion
        DispatchQueue.global(qos: .background).async {
            let dominantUIColor = coverImage.averageColor ?? UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.dominantColor = Color(dominantUIColor)
                }
            }
        }
    }
}


// MARK: - Spotify Button Style
struct SpotifyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Apple Music Mini Player (mit verbessertem Padding)
struct AppleMusicMiniPlayer: View {
    let song: Song
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Rounded album cover
            Group {
                if let coverImage = song.coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                                .foregroundColor(.gray.opacity(0.4))
                        )
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Apple Music controls
            HStack(spacing: 16) {
                Button(action: {
                    HapticFeedbackManager.shared.playPause()
                    audioPlayer.togglePlayback()
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                }
                .buttonStyle(MinimalButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.6))
                }
                .buttonStyle(MinimalButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20) // FIXED: Abstand zum unteren Rand
    }
}

// MARK: - Amazon Music Mini Player (mit verbessertem Padding)
struct AmazonMusicMiniPlayer: View {
    let song: Song
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Square album cover
            Group {
                if let coverImage = song.coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color(red: 0.2, green: 0.24, blue: 0.28))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.4))
                        )
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Amazon controls
            HStack(spacing: 18) {
                Button(action: {
                    HapticFeedbackManager.shared.playPause()
                    audioPlayer.togglePlayback()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.00, green: 0.67, blue: 0.93))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(MinimalButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(90))
                }
                .buttonStyle(MinimalButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.16, green: 0.20, blue: 0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20) // FIXED: Abstand zum unteren Rand
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

// MARK: - YouTube Music Mini Player (mit verbessertem Padding)
struct YouTubeMusicMiniPlayer: View {
    let song: Song
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail-style cover
            Group {
                if let coverImage = song.coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill) // YouTube aspect ratio
                } else {
                    Rectangle()
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .overlay(
                            Image(systemName: "play.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.4))
                        )
                }
            }
            .frame(width: 64, height: 36) // 16:9 aspect ratio
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(song.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Music")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .lineLimit(1)
            }
            
            Spacer()
            
            // YouTube controls
            HStack(spacing: 16) {
                Button(action: {
                    HapticFeedbackManager.shared.playPause()
                    audioPlayer.togglePlayback()
                }) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(MinimalButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(90))
                }
                .buttonStyle(MinimalButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8) // Leicht abgerundet für besseres Design
                .fill(.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20) // FIXED: Abstand zum unteren Rand
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
    }
}

// MARK: - UIImage Extension für Farbextraktion
extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        
        let extentVector = CIVector(x: inputImage.extent.origin.x,
                                   y: inputImage.extent.origin.y,
                                   z: inputImage.extent.size.width,
                                   w: inputImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage",
                                   parameters: [kCIInputImageKey: inputImage,
                                              kCIInputExtentKey: extentVector]) else { return nil }
        
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: nil)
        
        return UIColor(red: CGFloat(bitmap[0]) / 255,
                      green: CGFloat(bitmap[1]) / 255,
                      blue: CGFloat(bitmap[2]) / 255,
                      alpha: CGFloat(bitmap[3]) / 255)
    }
}

#Preview {
    VStack(spacing: 20) {
        AuthenticSpotifyMiniPlayer(
            song: Song(title: "Scherben", artist: "Bxgdan", duration: 180)
        )
        
        AppleMusicMiniPlayer(
            song: Song(title: "Test Song", artist: "Test Artist", duration: 180)
        )
        
        AmazonMusicMiniPlayer(
            song: Song(title: "Test Song", artist: "Test Artist", duration: 180)
        )
        
        YouTubeMusicMiniPlayer(
            song: Song(title: "Test Song", artist: "Test Artist", duration: 180)
        )
    }
    .background(Color.black)
}
