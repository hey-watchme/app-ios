//
//  HapticManager.swift
//  ios_watchme_v9
//
//  Haptic Feedback管理（サウンドは削除）
//

import SwiftUI

class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    // Haptic Feedback
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    init() {
        // Haptic準備
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Event Haptics
    
    func playEventBurst() {
        // イベント到達時の軽い振動
        lightImpact.impactOccurred(intensity: 0.6)
    }
    
    // MARK: - Selection Haptic
    
    func playSelectionHaptic() {
        selectionFeedback.selectionChanged()
    }
    
    // MARK: - General Impact
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - Light Impact (for drag interactions)
    
    func playLightImpact() {
        lightImpact.impactOccurred()
    }
}