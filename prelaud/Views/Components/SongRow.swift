//
//  SongRow.swift - MINIMAL DESIGN (FIXED)
//  MusicPreview
//
//  Warning resolved: onPlay closure comparison
//

import SwiftUI

struct SongRow: View {
    let song: Song
    let showArtist: Bool
    let onPlay: (() -> Void)?  // FIXED: Made optional
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    
    // FIXED: Updated initializer with optional onPlay
    init(song: Song, showArtist: Bool = true, onPlay: (() -> Void)? = nil) {
        self.song = song
        self.showArtist = showArtist
        self.onPlay = onPlay
    }
    
    private var isCurrentSong: Bool {
        audioPlayer.currentSong?.id == song.id
    }
    
    private var isPlaying: Bool {
        isCurrentSong && audioPlayer.isPlaying
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.songSelected()
            
            // FIXED: Proper optional handling
            if let customOnPlay = onPlay {
                customOnPlay()
            } else {
                audioPlayer.play(song: song)
            }
        }) {
            HStack(spacing: 12) {
                // Album Cover or Play Indicator
                ZStack {
                    if let coverImage = song.coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(0.08))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(.white.opacity(0.4))
                            )
                    }
                    
                    // Play indicator overlay
                    if isPlaying {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.6))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "waveform")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            )
                    }
                }
                
                // Song Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isCurrentSong ? .white : .white.opacity(0.9))
                        .lineLimit(1)
                    
                    if showArtist {
                        HStack(spacing: 8) {
                            Text(song.artist)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                            
                            if song.isExplicit {
                                Text("E")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 14, height: 14)
                                    .background(
                                        Circle()
                                            .fill(.white.opacity(0.7))
                                    )
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Duration and Status
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatDuration(song.duration))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    if isCurrentSong {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.white)
                                .frame(width: 4, height: 4)
                                .scaleEffect(isPlaying ? 1.0 : 0.6)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPlaying)
                            
                            Text(isPlaying ? "Playing" : "Paused")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrentSong ? .white.opacity(0.05) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(isCurrentSong ? 0.1 : 0), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(MinimalButtonStyle())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    VStack(spacing: 8) {
        SongRow(
            song: Song(
                title: "Neon Lights",
                artist: "Luna Beats",
                duration: 205,
                isExplicit: false
            )
        )
        
        SongRow(
            song: Song(
                title: "Electric Dreams",
                artist: "Luna Beats",
                duration: 241,
                isExplicit: true
            )
        )
    }
    .padding()
    .background(Color.black)
}
