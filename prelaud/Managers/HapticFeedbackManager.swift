//
//  HapticFeedbackManager.swift
//  MusicPreview
//
//  Zentrales Haptic Feedback System
//

import UIKit

class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {
        // Prepare generators for better performance
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    // MARK: - Impact Feedback
    func lightImpact() {
        lightImpactGenerator.impactOccurred()
        lightImpactGenerator.prepare() // Prepare for next use
    }
    
    func mediumImpact() {
        mediumImpactGenerator.impactOccurred()
        mediumImpactGenerator.prepare()
    }
    
    func heavyImpact() {
        heavyImpactGenerator.impactOccurred()
        heavyImpactGenerator.prepare()
    }
    
    // MARK: - Selection Feedback
    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
    
    // MARK: - Notification Feedback
    func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
    
    func warning() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }
    
    func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
    
    // MARK: - Context-Specific Feedback
    func buttonTap() {
        lightImpact()
    }
    
    func cardTap() {
        mediumImpact()
    }
    
    func navigationBack() {
        lightImpact()
    }
    
    func playPause() {
        mediumImpact()
    }
    
    func uploadComplete() {
        success()
    }
    
    func uploadFailed() {
        error()
    }
    
    func songSelected() {
        selection()
    }
    
    func pageTransition() {
        lightImpact()
    }
}
