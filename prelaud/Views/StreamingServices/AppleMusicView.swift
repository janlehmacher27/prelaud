//
//  AppleMusicView.swift - MIT MINIMALEM BACK BUTTON & ADAPTIVE MINI PLAYER
//  MusicPreview
//
//  Enhanced with minimal back navigation and adaptive player
//

import SwiftUI

struct AppleMusicAlbumView: View {
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
            
            // MINIMALER BACK BUTTON (für helles Theme angepasst)
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
        }
        .overlay(
            // ADAPTIVE Mini Player Overlay
            VStack {
                Spacer()
                
                if audioPlayer.isPlaying && audioPlayer.currentSong != nil {
                    AdaptiveMiniPlayer(service: .appleMusic)
                        .padding(.bottom, 100)
                }
            }
        )
    }
}
