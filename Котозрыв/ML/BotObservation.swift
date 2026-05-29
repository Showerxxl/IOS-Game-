import Foundation

/// Кодирование состояния игры в вектор признаков для DQN-бота.
///
/// ВАЖНО: раскладка вектора (31 значение) обязана ТОЧЬ-В-ТОЧЬ совпадать
/// с Python-кодировщиком ML/game/env.py (encode_observation), иначе модель,
/// обученная в симуляторе, будет получать «не тот» вход на устройстве.
///
/// Раскладка (см. env.py):
///   [0..11]  hand_counts      — кол-во карт каждого из 12 типов в руке (/4)
///   [12]     has_defuse       — есть ли defuse (0/1)
///   [13]     hand_total       — размер руки (/15)
///   [14]     deck_size        — размер колоды (/40)
///   [15]     exploding_known  — взрывных котят в колоде (/4)
///   [16]     danger_score     — exploding / deck_size
///   [17]     stf_valid        — актуально ли знание верхних карт (0/1)
///   [18..20] stf_top_explode  — для топ-1/2/3: это взрывной котёнок? (0/1)
///   [21]     turns_remaining  — сколько ходов осталось текущему (/3)
///   [22]     alive_count      — живых игроков (/5)
///   [23..26] opp_hand_sizes   — размеры рук соперников (до 4, убыв., /15)
///   [27..30] opp_alive        — флаги «слот соперника занят» (0/1)
enum BotObservation {

    static let dim = 31
    static let maxOpponents = 4

    /// Индекс типа карты в векторе (соответствует cards.py).
    static func cardIndex(_ type: CardType) -> Int {
        switch type {
        case .explodingKitten: return 0
        case .defuse:          return 1
        case .nope:            return 2
        case .attack:          return 3
        case .skip:            return 4
        case .favor:           return 5
        case .shuffle:         return 6
        case .seeTheFuture:    return 7
        case .catBeard:        return 8
        case .catTaco:         return 9
        case .catWatermelon:   return 10
        case .catPotato:       return 11
        }
    }

    /// Построить вектор наблюдения с точки зрения игрока `player`.
    /// `knownTop` — приватное знание верхних карт колоды (после See the Future).
    static func encode(gameState: GameState,
                       player: Player,
                       knownTop: [CardType]) -> [Float] {
        var obs = [Float](repeating: 0, count: dim)

        // [0..11] счётчики карт в руке
        for card in player.hand {
            obs[cardIndex(card.type)] += 1
        }
        for i in 0..<12 { obs[i] /= 4.0 }

        // [12] есть defuse
        obs[12] = player.hasCard(ofType: .defuse) ? 1 : 0
        // [13] размер руки
        obs[13] = Float(min(player.hand.count, 15)) / 15.0
        // [14] размер колоды
        obs[14] = Float(min(gameState.deck.count, 40)) / 40.0
        // [15] взрывных котят в колоде
        let exploding = gameState.deck.filter { $0.type == .explodingKitten }.count
        obs[15] = Float(min(exploding, 4)) / 4.0
        // [16] danger score
        obs[16] = gameState.deck.isEmpty ? 0 : Float(exploding) / Float(gameState.deck.count)

        // [17..20] знание верхних карт
        if !knownTop.isEmpty {
            obs[17] = 1
            for i in 0..<min(3, knownTop.count) {
                obs[18 + i] = (knownTop[i] == .explodingKitten) ? 1 : 0
            }
        }

        // [21] ходов осталось
        obs[21] = Float(min(player.turnsRemaining, 3)) / 3.0
        // [22] живых игроков
        obs[22] = Float(gameState.alivePlayers().count) / 5.0

        // [23..30] соперники (размеры рук, отсортированы по убыванию)
        let oppSizes = gameState.players
            .filter { $0.id != player.id && $0.isAlive }
            .map { $0.hand.count }
            .sorted(by: >)
        for i in 0..<min(maxOpponents, oppSizes.count) {
            obs[23 + i] = Float(min(oppSizes[i], 15)) / 15.0
            obs[27 + i] = 1
        }

        return obs
    }
}
