import Foundation

// MARK: - Content Preset Models

struct PresetTopic {
    let id: String
    let nynorskTitle: String
    let translations: [String: String]
    let emoji: String
    let difficulty: String
    let color: String
    let words: [PresetWord]
}

struct PresetWord {
    let nynorsk: String
    let translations: [String: String]
    let gender: GrammaticalGender
    let context: String
    let contextTrans: [String: String]
}
