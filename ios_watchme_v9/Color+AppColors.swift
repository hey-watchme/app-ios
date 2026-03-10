//
//  Color+AppColors.swift
//  ios_watchme_v9
//
//  Centralized color management - Dark theme (redesign/dashboard branch)
//

import SwiftUI

extension Color {
    // MARK: - Dark Theme Base Palette

    static let darkBase = Color(red: 0.05, green: 0.05, blue: 0.07)       // #0D0D12
    static let darkSurface = Color(red: 0.10, green: 0.10, blue: 0.13)    // #1A1A21
    static let darkElevated = Color(red: 0.14, green: 0.14, blue: 0.18)   // #24242E
    static let darkCard = Color(red: 0.11, green: 0.11, blue: 0.14)       // #1C1C24

    static let accentTeal = Color(red: 0.0, green: 0.83, blue: 0.67)      // #00D4AB
    static let accentAmber = Color(red: 0.91, green: 0.66, blue: 0.22)    // #E8A838
    static let accentCoral = Color(red: 1.0, green: 0.42, blue: 0.42)     // #FF6B6B
    static let accentEmerald = Color(red: 0.20, green: 0.78, blue: 0.35)  // #34C759

    // MARK: - Ambient Glow & Redesign Specific Colors
    static let auraTealGlow = Color.accentTeal.opacity(0.15)
    static let stressAmberGlow = Color.accentAmber.opacity(0.15)
    static let neutralGlow = Color(white: 0.5).opacity(0.1)

    // MARK: - Chart Colors

    static let graphLineColor = Color("GraphLineColor")
    static let vibeChangeIndicatorColor = Color("VibeChangeIndicatorColor")
    static let scorePositiveColor = Color("ScorePositiveColor")
    static let scoreNormalColor = Color("ScoreNormalColor")
    static let scoreNeutralColor = Color("ScoreNeutralColor")
    static let scoreNegativeColor = Color("ScoreNegativeColor")
    static let scoreVeryNegativeColor = Color("ScoreVeryNegativeColor")
    static let chartBackgroundColor = Color("ChartBackgroundColor")
    static let zeroLineColor = Color("ZeroLineColor")

    // MARK: - UI Colors

    static let primaryActionColor = Color("PrimaryActionColor")
    static let secondaryActionColor = Color("SecondaryActionColor")
    static let infoColor = Color("InfoColor")
    static let appAccentColor = Color("AppAccentColor")

    // MARK: - Border & Separator Colors

    static let separatorColor = Color("SeparatorColor")

    // MARK: - Accent Colors

    static let accentPurple = Color.accentTeal

    // MARK: - Fallback Colors (Dark Theme)

    static func fallbackColor(for name: String) -> Color {
        switch name {

        // Chart Colors
        case "GraphLineColor":
            return accentTeal
        case "VibeChangeIndicatorColor":
            return accentTeal
        case "ScorePositiveColor":
            return accentEmerald
        case "ScoreNormalColor":
            return accentTeal
        case "ScoreNeutralColor":
            return Color(white: 0.45)
        case "ScoreNegativeColor":
            return accentAmber
        case "ScoreVeryNegativeColor":
            return accentCoral
        case "ChartBackgroundColor":
            return darkSurface
        case "ZeroLineColor":
            return Color.white.opacity(0.15)

        // Text Colors (Dark Theme)
        case "BehaviorTextPrimary":
            return Color.white
        case "BehaviorTextSecondary":
            return Color(white: 0.56)
        case "BehaviorTextTertiary":
            return Color(white: 0.36)

        // Background Colors (Dark Theme)
        case "BehaviorBackgroundPrimary":
            return darkBase
        case "BehaviorBackgroundSecondary":
            return darkSurface

        // Medal Colors
        case "BehaviorGoldMedal":
            return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "BehaviorSilverMedal":
            return Color(red: 0.65, green: 0.65, blue: 0.70)
        case "BehaviorBronzeMedal":
            return Color(red: 0.80, green: 0.52, blue: 0.25)

        // Emotion Colors (Tuned for dark bg)
        case "EmotionJoy":
            return Color(red: 1.0, green: 0.84, blue: 0.04)
        case "EmotionTrust":
            return accentEmerald
        case "EmotionFear":
            return Color(red: 0.70, green: 0.40, blue: 1.0)
        case "EmotionSurprise":
            return Color(red: 0.30, green: 0.85, blue: 1.0)
        case "EmotionSadness":
            return Color(red: 0.40, green: 0.60, blue: 1.0)
        case "EmotionDisgust":
            return Color(red: 0.65, green: 0.45, blue: 0.30)
        case "EmotionAnger":
            return accentCoral
        case "EmotionAnticipation":
            return accentAmber
        case "EmotionNeutral":
            return Color(white: 0.50)

        // UI Colors
        case "PrimaryActionColor":
            return accentTeal
        case "SecondaryActionColor":
            return Color(white: 0.30)
        case "WarningColor":
            return accentAmber
        case "SuccessColor":
            return accentEmerald
        case "ErrorColor":
            return accentCoral
        case "InfoColor":
            return Color(red: 0.35, green: 0.68, blue: 1.0)
        case "AppAccentColor":
            return accentTeal

        // Background Colors
        case "PrimaryBackground":
            return darkBase
        case "SecondaryBackground":
            return darkSurface
        case "TertiaryBackground":
            return darkElevated
        case "CardBackground":
            return darkCard

        // Text Colors
        case "PrimaryText":
            return Color.white
        case "SecondaryText":
            return Color(white: 0.56)
        case "TertiaryText":
            return Color(white: 0.36)
        case "PlaceholderText":
            return Color(white: 0.28)

        // Recording & Status Colors
        case "RecordingActive":
            return accentCoral
        case "RecordingInactive":
            return Color(white: 0.30)
        case "UploadActive":
            return accentTeal
        case "StatusNormal":
            return accentEmerald

        // Border & Separator Colors
        case "BorderLight":
            return Color.white.opacity(0.08)
        case "BorderMedium":
            return Color.white.opacity(0.15)
        case "SeparatorColor":
            return Color.white.opacity(0.10)

        // Timeline Indicator Colors
        case "TimelineIndicator":
            return accentTeal
        case "TimelineActive":
            return Color(red: 0.30, green: 0.85, blue: 1.0)

        default:
            return Color(white: 0.36)
        }
    }

    // MARK: - Safe Color Initializer (Dark Theme Override)

    static func safeColor(_ name: String) -> Color {
        // Dark theme redesign: always use fallback palette
        return fallbackColor(for: name)
    }
}

// MARK: - Vibe Score Color

extension Color {
    static func vibeScoreColor(for score: Double) -> Color {
        switch score {
        case 60...:
            return accentEmerald
        case 20..<60:
            return accentTeal
        case -20..<20:
            return Color(white: 0.50)
        case -60..<(-20):
            return accentAmber
        default:
            return accentCoral
        }
    }
}
