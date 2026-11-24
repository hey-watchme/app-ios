//
//  BehaviorEventType.swift
//  ios_watchme_v9
//
//  Japanese names of the sound labels in the old sound classifier's timeline
//  (spot_features.behavior_extractor_result). Only recordings from before 2026-11-19
//  and the demo rows still have that timeline.
//

import Foundation

// MARK: - Behavior Event Type (AST v2.1)
enum BehaviorEventType: String {
    // Common events (frequently detected)
    case speech = "Speech"
    case music = "Music"
    case laughter = "Laughter"
    case crying = "Crying"
    case dog = "Dog"
    case cat = "Cat"
    case water = "Water"
    case cutleryKitchenware = "Cutlery and kitchenware"
    case childSpeech = "Child speech"
    case vehicle = "Vehicle"
    case engine = "Engine"
    case machine = "Machine"
    case tickTock = "Tick-tock"

    // Body sounds
    case cough = "Cough"
    case sneeze = "Sneeze"
    case snoring = "Snoring"
    case breathing = "Breathing"

    // Actions
    case walkFootsteps = "Walk, footsteps"
    case clapping = "Clapping"

    // Other
    case silence = "Silence"
    case door = "Door"

    var displayName: String {
        switch self {
        case .speech: return "会話"
        case .music: return "音楽"
        case .laughter: return "笑い声"
        case .crying: return "泣き声"
        case .dog: return "犬"
        case .cat: return "猫"
        case .water: return "水の音"
        case .cutleryKitchenware: return "食器・調理音"
        case .childSpeech: return "子供の声"
        case .vehicle: return "車両"
        case .engine: return "エンジン音"
        case .machine: return "機械音"
        case .tickTock: return "時計の音"
        case .cough: return "咳"
        case .sneeze: return "くしゃみ"
        case .snoring: return "いびき"
        case .breathing: return "呼吸音"
        case .walkFootsteps: return "足音"
        case .clapping: return "拍手"
        case .silence: return "静寂"
        case .door: return "ドア"
        }
    }
}
