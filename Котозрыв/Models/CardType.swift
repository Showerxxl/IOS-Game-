//
//  CardType.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

enum CardType: String, CaseIterable {
    case explodingKitten = "Взрывной котёнок"
    case defuse = "Обезвредь"
    case nope = "Неть"
    case attack = "Нападай"
    case skip = "Слиняй"
    case favor = "Подлижись"
    case shuffle = "Затасуй"
    case seeTheFuture = "Подсмотри грядущее"
    
    // Кошкокарты
    case catCard1 = "Котокарта 1"
    case catCard2 = "Котокарта 2"
    case catCard3 = "Котокарта 3"
    case catCard4 = "Котокарта 4"
    case catCard5 = "Котокарта 5"
    
    var description: String {
        switch self {
        case .explodingKitten:
            return "Взорвись и проиграй"
        case .defuse:
            return "Обезвредь взрывного котёнка"
        case .nope:
            return "Отмени действие карты"
        case .attack:
            return "Следующий игрок ходит дважды"
        case .skip:
            return "Завершить ход без взятия карты"
        case .favor:
            return "Укради карту у другого игрока"
        case .shuffle:
            return "Перемешай колоду"
        case .seeTheFuture:
            return "Посмотри 3 верхние карты"
        default:
            return "Кошкокарта"
        }
    }
    
    var isPlayable: Bool {
        switch self {
        case .explodingKitten:
            return false
        default:
            return true
        }
    }
}
