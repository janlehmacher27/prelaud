//
//  CoverImageSelector.swift
//  MusicPreview
//
//  Created by Jan Lehmacher on 09.07.25.
//


//
//  CoverImageSelector.swift
//  MusicPreview
//
//  Created by Jan on 08.07.25.
//

import SwiftUI

struct CoverImageSelector: View {
    @Binding var selectedImage: UIImage?
    @Binding var showingImagePicker: Bool
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { showingImagePicker = true }) {
            ZStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(
                            // Edit overlay when hovering
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.black.opacity(0.6))
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                        Text("Change")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                )
                                .opacity(isHovered ? 1 : 0)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial.opacity(0.6))
                        .frame(width: 160, height: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.3),
                                            .white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                                )
                        )
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("Add Cover")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )
                }
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            isHovered = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isHovered = false
            }
        }
    }
}