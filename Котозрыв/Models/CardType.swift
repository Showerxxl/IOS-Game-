import Foundation

enum CardType: String, CaseIterable {
    case explodingKitten = "Exploding Kitten"
    case defuse          = "Defuse"
    case nope            = "Nope"
    case attack          = "Attack"
    case skip            = "Skip"
    case favor           = "Favor"
    case shuffle         = "Shuffle"
    case seeTheFuture    = "See the Future"

    case catBeard      = "Cat Beard"
    case catTaco       = "Cat Taco"
    case catWatermelon = "Cat Watermelon"
    case catPotato     = "Cat Potato"

    var description: String {
        switch self {
        case .explodingKitten: return "Explode and lose"
        case .defuse:          return "Defuse the exploding kitten"
        case .nope:            return "Cancel another card's action"
        case .attack:          return "Next player takes two turns"
        case .skip:            return "End your turn without drawing"
        case .favor:           return "Steal a card from another player"
        case .shuffle:         return "Shuffle the deck"
        case .seeTheFuture:    return "Look at the top 3 cards"
        default:               return "Cat Card"
        }
    }

    var isPlayable: Bool {
        self != .explodingKitten
    }

    init?(serverType: String) {
        switch serverType {
        case "exploding_kitten": self = .explodingKitten
        case "defuse":           self = .defuse
        case "nope":             self = .nope
        case "attack":           self = .attack
        case "skip":             self = .skip
        case "favor":            self = .favor
        case "shuffle":          self = .shuffle
        case "see_the_future":   self = .seeTheFuture
        case "cat_beard":        self = .catBeard
        case "cat_taco":         self = .catTaco
        case "cat_watermelon":   self = .catWatermelon
        case "cat_potato":       self = .catPotato
        default:                 return nil
        }
    }

    var serverTypeString: String {
        switch self {
        case .explodingKitten: return "exploding_kitten"
        case .defuse:          return "defuse"
        case .nope:            return "nope"
        case .attack:          return "attack"
        case .skip:            return "skip"
        case .favor:           return "favor"
        case .shuffle:         return "shuffle"
        case .seeTheFuture:    return "see_the_future"
        case .catBeard:        return "cat_beard"
        case .catTaco:         return "cat_taco"
        case .catWatermelon:   return "cat_watermelon"
        case .catPotato:       return "cat_potato"
        }
    }

    var displayName: String {
        switch self {
        case .explodingKitten: return "Взрывной котёнок"
        case .defuse:          return "Обезвредь"
        case .nope:            return "Неть"
        case .attack:          return "Нападай"
        case .skip:            return "Слиняй"
        case .favor:           return "Подлижись"
        case .shuffle:         return "Затасуй"
        case .seeTheFuture:    return "Подсмотри грядущее"
        case .catBeard:        return "Кот-Борода"
        case .catTaco:         return "Кот-Повар"
        case .catWatermelon:   return "Кот-Тако"
        case .catPotato:       return "Кот-Картошка"
        }
    }

    var canBeNoped: Bool {
        switch self {
        case .explodingKitten, .defuse:
            return false
        default:
            return true
        }
    }

    var assetCatalogImageNames: [String] {
        switch self {
        case .explodingKitten: return ["explode", "explode2", "explode2png"]
        case .defuse:          return ["defuse"]
        case .nope:            return ["nope"]
        case .attack:          return ["attack"]
        case .skip:            return ["runaway"]
        case .favor:           return ["borrow"]
        case .shuffle:         return ["shuffle"]
        case .seeTheFuture:    return ["future"]
        case .catBeard:        return ["beard"]
        case .catTaco:         return ["taco"]
        case .catWatermelon:   return ["taco2"]
        case .catPotato:       return ["potato"]
        }
    }
}
