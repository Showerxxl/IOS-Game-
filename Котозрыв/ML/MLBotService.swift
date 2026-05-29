import Foundation
import CoreML

/// Действия бота — порядок и индексы строго как в ML/game/engine.py.
enum BotAction: Int, CaseIterable {
    case draw       = 0   // взять карту (завершает ход)
    case attack     = 1
    case skip       = 2
    case favor      = 3
    case shuffle    = 4
    case seeFuture  = 5
    case catPair    = 6
    case catTrio    = 7
}

/// Уровни сложности = разные чекпойнты обучения.
enum BotDifficulty: String {
    case easy   = "KotozryvBotEasy"
    case medium = "KotozryvBotMedium"
    case hard   = "KotozryvBotHard"
}

/// Сервис принятия решений ML-ботом на базе обученной DQN-модели (Core ML).
///
/// Использование:
///   let bot = MLBotService(difficulty: .hard)
///   let action = bot.decide(gameState: state, player: aiPlayer, knownTop: known)
///
/// Маскирование нелегальных действий и argmax делаются здесь, модель отдаёт
/// только Q-значения. Если модель не загрузилась — fallback на простую эвристику,
/// чтобы игра не падала.
final class MLBotService {

    private let model: MLModel?
    let difficulty: BotDifficulty

    init(difficulty: BotDifficulty) {
        self.difficulty = difficulty
        self.model = MLBotService.loadModel(named: difficulty.rawValue)
    }

    private static func loadModel(named name: String) -> MLModel? {
        // .mlpackage компилируется Xcode в .mlmodelc внутри бандла.
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
            Bundle.main.url(forResource: name, withExtension: "mlpackage")
        ].compactMap { $0 }
        guard let url = candidates.first else {
            print("[MLBot] Модель \(name) не найдена в бандле — fallback на эвристику.")
            return nil
        }
        do {
            let cfg = MLModelConfiguration()
            return try MLModel(contentsOf: url, configuration: cfg)
        } catch {
            print("[MLBot] Ошибка загрузки модели \(name): \(error)")
            return nil
        }
    }

    // MARK: - Принятие решения

    /// Главный метод: вернуть действие бота для текущего состояния.
    func decide(gameState: GameState, player: Player, knownTop: [CardType]) -> BotAction {
        let mask = Self.legalMask(gameState: gameState, player: player)

        guard let model = model else {
            return Self.heuristicFallback(gameState: gameState, player: player,
                                          knownTop: knownTop, mask: mask)
        }

        let obs = BotObservation.encode(gameState: gameState, player: player, knownTop: knownTop)
        guard let q = runInference(model: model, observation: obs) else {
            return Self.heuristicFallback(gameState: gameState, player: player,
                                          knownTop: knownTop, mask: mask)
        }

        // masked argmax
        var bestAction = BotAction.draw
        var bestValue = -Float.greatestFiniteMagnitude
        for action in BotAction.allCases {
            guard mask[action.rawValue] else { continue }
            if q[action.rawValue] > bestValue {
                bestValue = q[action.rawValue]
                bestAction = action
            }
        }
        return bestAction
    }

    private func runInference(model: MLModel, observation: [Float]) -> [Float]? {
        guard let arr = try? MLMultiArray(shape: [1, NSNumber(value: BotObservation.dim)],
                                          dataType: .float32) else { return nil }
        for (i, v) in observation.enumerated() {
            arr[i] = NSNumber(value: v)
        }
        let input = try? MLDictionaryFeatureProvider(dictionary: ["observation": arr])
        guard let input = input,
              let out = try? model.prediction(from: input),
              let qArr = out.featureValue(for: "q_values")?.multiArrayValue else {
            return nil
        }
        var q = [Float](repeating: 0, count: qArr.count)
        for i in 0..<qArr.count { q[i] = qArr[i].floatValue }
        return q
    }

    // MARK: - Легальная маска (зеркало engine.legal_actions)

    static func legalMask(gameState: GameState, player: Player) -> [Bool] {
        var mask = [Bool](repeating: false, count: BotAction.allCases.count)
        mask[BotAction.draw.rawValue] = true   // взять карту можно всегда

        let opponentsWithCards = gameState.players.contains {
            $0.id != player.id && $0.isAlive && !$0.hand.isEmpty
        }

        if player.hasCard(ofType: .attack)      { mask[BotAction.attack.rawValue] = true }
        if player.hasCard(ofType: .skip)         { mask[BotAction.skip.rawValue] = true }
        if player.hasCard(ofType: .favor) && opponentsWithCards {
            mask[BotAction.favor.rawValue] = true
        }
        if player.hasCard(ofType: .shuffle)      { mask[BotAction.shuffle.rawValue] = true }
        if player.hasCard(ofType: .seeTheFuture) { mask[BotAction.seeFuture.rawValue] = true }

        if opponentsWithCards {
            if bestCatGroup(player: player, size: 2) != nil {
                mask[BotAction.catPair.rawValue] = true
            }
            if bestCatGroup(player: player, size: 3) != nil {
                mask[BotAction.catTrio.rawValue] = true
            }
        }
        return mask
    }

    /// Тип кота, которого у игрока >= size штук (для комбо).
    static func bestCatGroup(player: Player, size: Int) -> CardType? {
        let catTypes: [CardType] = [.catBeard, .catTaco, .catWatermelon, .catPotato]
        for cat in catTypes where player.getCards(ofType: cat).count >= size {
            return cat
        }
        return nil
    }

    // MARK: - Fallback-эвристика (если модель не загрузилась)

    private static func heuristicFallback(gameState: GameState, player: Player,
                                          knownTop: [CardType], mask: [Bool]) -> BotAction {
        let danger = gameState.deck.isEmpty ? 0
            : Double(gameState.deck.filter { $0.type == .explodingKitten }.count) / Double(gameState.deck.count)
        let explosionOnTop = knownTop.first == .explodingKitten

        func pick(_ actions: [BotAction]) -> BotAction? {
            actions.first { mask[$0.rawValue] }
        }

        if explosionOnTop {
            if let a = pick([.skip, .attack, .shuffle, .catTrio, .catPair, .favor]) { return a }
            return .draw
        }
        if danger >= 0.25, let a = pick([.shuffle, .skip, .attack]) { return a }
        if danger >= 0.10 && knownTop.isEmpty, let a = pick([.seeFuture]) { return a }
        if danger < 0.10, let a = pick([.catTrio, .catPair]) { return a }
        if let a = pick([.favor]) { return a }
        return .draw
    }
}
