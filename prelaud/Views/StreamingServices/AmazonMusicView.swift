//
//  AmazonMusicView.swift - MIT MINIMALEM BACK BUTTON & ADAPTIVE MINI PLAYER
//  MusicPreview
//
//  Enhanced with minimal back navigation and adaptive player
//

import SwiftUI

struct AmazonMusicAlbumView: View {
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
            
            // MINIMALER BACK BUTTON
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
        }
        .overlay(
            // ADAPTIVE Mini Player Overlay
            VStack {
                Spacer()
                
                if audioPlayer.isPlaying && audioPlayer.currentSong != nil {
                    AdaptiveMiniPlayer(service: .amazonMusic)
                        .padding(.bottom, 100)
                }
            }
        )
    }
}
