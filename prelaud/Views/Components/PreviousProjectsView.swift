//
//  PreviousProjectsView.swift
//  MusicPreview
//
//  Created by Jan on 08.07.25.
//

import SwiftUI

struct PreviousProjectsView: View {
    let albums: [Album]
    let onSelectAlbum: (Album) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Ersetzter Background (war ModernUploadBackground)
            ModernBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("Previous Projects")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible button for balance
                    Button("") { }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.clear)
                        .disabled(true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Content
                if albums.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "folder")
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("No Previous Projects")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Your uploaded projects will appear here")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(albums, id: \.id) { album in
                                ProjectCard(
                                    album: album,
                                    onSelect: { onSelectAlbum(album) }
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Modern Background (ersetzt ModernUploadBackground)
struct ModernBackground: View {
    @State private var gradientRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Base dark background
            Color.black
            
            // Subtle animated gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1).opacity(0.8),
                    Color(red: 0.02, green: 0.02, blue: 0.05).opacity(0.9),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .hueRotation(.degrees(gradientRotation))
            .animation(.linear(duration: 30).repeatForever(autoreverses: false), value: gradientRotation)
            
            // Subtle floating elements
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(0.02))
                    .frame(width: 200, height: 200)
                    .position(
                        x: index == 0 ? 100 : 300,
                        y: index == 0 ? 200 : 400
                    )
                    .blur(radius: 50)
            }
        }
        .onAppear {
            gradientRotation = 360
        }
    }
}

#Preview {
    PreviousProjectsView(albums: [], onSelectAlbum: { _ in })
}
