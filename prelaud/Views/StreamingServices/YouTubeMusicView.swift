//
//  YouTubeMusicView.swift - MIT MINIMALEM BACK BUTTON & ADAPTIVE MINI PLAYER
//  MusicPreview
//
//  Enhanced with minimal back navigation and adaptive player
//

import SwiftUI

struct YouTubeMusicAlbumView: View {
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
        }
        .overlay(
            // ADAPTIVE Mini Player Overlay
            VStack {
                Spacer()
                
                if audioPlayer.isPlaying && audioPlayer.currentSong != nil {
                    AdaptiveMiniPlayer(service: .youtubeMusic)
                        .padding(.bottom, 100)
                }
            }
        )
    }
}
