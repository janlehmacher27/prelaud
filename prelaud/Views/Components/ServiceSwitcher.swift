//
//  ServiceSwitcher.swift
//  MusicPreview
//
//  Created by Jan on 08.07.25.
//

import SwiftUI

struct DynamicIslandServiceSwitcher: View {
    @Binding var selectedService: StreamingService
    let services: [StreamingService]
    @Binding var isAnimating: Bool
    
    @State private var dragOffset: CGFloat = 0
    @State private var currentIndex: Int = 0
    @State private var capsuleScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Gefärbter Glas-Hintergrund mit stärkerem Gradient
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            selectedService.primaryColor.opacity(0.4),
                            selectedService.primaryColor.opacity(0.25),
                            selectedService.primaryColor.opacity(0.15),
                            selectedService.primaryColor.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Glas-Effekt mit ultraThinMaterial
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                )
                .overlay(
                    // Subtiler weißer Rand für Glas-Effekt
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.1),
                                    .white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .frame(width: 160, height: 44)
                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                .scaleEffect(capsuleScale)
                .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: capsuleScale)
                .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: selectedService)
            
            // Service-Name ohne Farb-Indikator
            Text(selectedService.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .scaleEffect(isAnimating ? 0.9 : 1.0)
                .opacity(isAnimating ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isAnimating)
                .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: selectedService)
        }
        .offset(x: dragOffset * 0.1) // Subtile Bewegung während des Ziehens
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.9, blendDuration: 0), value: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                    
                    // Skalierungseffekt während des Ziehens
                    if capsuleScale == 1.0 {
                        capsuleScale = 1.05
                    }
                }
                .onEnded { value in
                    // Animation für das Zurücksetzen
                    dragOffset = 0
                    capsuleScale = 1.0
                    
                    // Wischrichtung bestimmen mit Cycle-Through
                    let threshold: CGFloat = 50
                    
                    if value.translation.width > threshold {
                        // Nach links wischen - vorheriger Service (mit Wrap-Around)
                        let newIndex = currentIndex > 0 ? currentIndex - 1 : services.count - 1
                        updateService(to: newIndex)
                    } else if value.translation.width < -threshold {
                        // Nach rechts wischen - nächster Service (mit Wrap-Around)
                        let newIndex = currentIndex < services.count - 1 ? currentIndex + 1 : 0
                        updateService(to: newIndex)
                    }
                }
        )
        .onAppear {
            currentIndex = services.firstIndex(of: selectedService) ?? 0
        }
    }
    
    private func updateService(to newIndex: Int) {
        currentIndex = newIndex
        isAnimating = true
        selectedService = services[currentIndex]
        
        // Animations-Flag zurücksetzen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }
    }
}
