//
//  ModernCreateButton.swift
//  MusicPreview
//
//  Created by Jan Lehmacher on 09.07.25.
//


//
//  ModernCreateButton.swift
//  MusicPreview
//
//  Created by Jan on 08.07.25.
//

import SwiftUI

struct ModernCreateButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var sparkleOffset: CGFloat = -100
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Animated background with sparkle effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.8),
                                Color(red: 0.98, green: 0.26, blue: 0.40).opacity(0.8),
                                Color(red: 0.00, green: 0.67, blue: 0.93).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // Sparkle animation
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.3),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .rotationEffect(.degrees(45))
                        .offset(x: sparkleOffset)
                        .clipped()
                    )
                    .frame(height: 80)
                
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .onTapGesture {
            // Sparkle animation on tap
            withAnimation(.easeInOut(duration: 0.8)) {
                sparkleOffset = 200
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                sparkleOffset = -100
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .padding(.horizontal, 20)
        .onAppear {
            // Einmalige Sparkle Animation nach 2 Sekunden
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    sparkleOffset = 200
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    sparkleOffset = -100
                }
            }
        }
    }
}
