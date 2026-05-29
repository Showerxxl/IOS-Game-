import Foundation
import CoreML

/// Запись одного хода игрока для анализа коучем.
struct CoachMoveRecord {
    let feature: [Float]        // 39 = obs(31) + action_onehot(8)
    let humanAction: BotAction  // что сыграл игрок
    let oracleAction: BotAction // что советовал DQN-оракул
    let turnNumber: Int
    let danger: Float
    var isMistake: Bool { humanAction != oracleAction }
}

/// Найденная ошибка с рекомендацией.
struct CoachMistake {
    let turnNumber: Int
    let played: BotAction
    let suggested: BotAction
    let winProbDrop: Float
    let advice: String
}

/// Итоговый отчёт коуча.
struct CoachReport {
    let winProb: [Float]            // P(победа) на каждом ходу (от LSTM)
    let mistakes: [CoachMistake]    // ключевые ошибки
    let styleTitle: String          // стиль игры
    let styleDescription: String
    let accuracy: Float             // доля «оптимальных» ходов (совпали с DQN)
    let didWin: Bool
    let totalMoves: Int
}

/// Сервис «личного коуча»: LSTM строит кривую вероятности победы,
/// DQN-оракул находит ошибки, по частотам действий определяется стиль игры.
final class CoachService {

    private let lstm: MLModel?

    init() {
        self.lstm = CoachService.loadModel(named: "KotozryvCoach")
    }

    private static func loadModel(named name: String) -> MLModel? {
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
            Bundle.main.url(forResource: name, withExtension: "mlpackage")
        ].compactMap { $0 }
        guard let url = candidates.first else {
            print("[Coach] Модель \(name) не найдена — кривая win-prob будет приблизительной.")
            return nil
        }
        return try? MLModel(contentsOf: url, configuration: MLModelConfiguration())
    }

    // MARK: - Анализ

    func analyze(records: [CoachMoveRecord], didWin: Bool) -> CoachReport {
        let winProb = computeWinProb(records: records, didWin: didWin)
        let mistakes = findMistakes(records: records, winProb: winProb)
        let (styleTitle, styleDesc) = detectStyle(records: records)
        let good = records.filter { !$0.isMistake }.count
        let accuracy = records.isEmpty ? 0 : Float(good) / Float(records.count)

        return CoachReport(
            winProb: winProb,
            mistakes: mistakes,
            styleTitle: styleTitle,
            styleDescription: styleDesc,
            accuracy: accuracy,
            didWin: didWin,
            totalMoves: records.count
        )
    }

    // MARK: - LSTM win-prob

    private func computeWinProb(records: [CoachMoveRecord], didWin: Bool) -> [Float] {
        guard let lstm = lstm, !records.isEmpty else {
            // fallback: грубая оценка по danger, если модель недоступна
            return records.map { max(0, min(1, 0.5 - ($0.danger - 0.1))) }
        }
        let T = records.count
        let feat = records[0].feature.count   // 39
        guard let arr = try? MLMultiArray(shape: [1, NSNumber(value: T), NSNumber(value: feat)],
                                          dataType: .float32) else {
            return records.map { _ in 0.5 }
        }
        var idx = 0
        for r in records {
            for v in r.feature { arr[idx] = NSNumber(value: v); idx += 1 }
        }
        guard let input = try? MLDictionaryFeatureProvider(dictionary: ["moves": arr]),
              let out = try? lstm.prediction(from: input),
              let probs = out.featureValue(for: "win_prob")?.multiArrayValue else {
            return records.map { _ in 0.5 }
        }
        var result = [Float](repeating: 0, count: probs.count)
        for i in 0..<probs.count { result[i] = probs[i].floatValue }
        return result
    }

    // MARK: - Поиск ошибок

    private func findMistakes(records: [CoachMoveRecord], winProb: [Float]) -> [CoachMistake] {
        var mistakes: [CoachMistake] = []
        for (i, r) in records.enumerated() where r.isMistake {
            // падение вероятности победы после этого хода
            let drop: Float
            if i + 1 < winProb.count {
                drop = max(0, winProb[i] - winProb[i + 1])
            } else {
                drop = 0
            }
            mistakes.append(CoachMistake(
                turnNumber: r.turnNumber,
                played: r.humanAction,
                suggested: r.oracleAction,
                winProbDrop: drop,
                advice: Self.advice(for: r)
            ))
        }
        // топ-3 самых дорогих ошибки (по падению вероятности; при равенстве — по порядку)
        return Array(mistakes.sorted { $0.winProbDrop > $1.winProbDrop }.prefix(3))
    }

    private static func advice(for r: CoachMoveRecord) -> String {
        let played = actionName(r.humanAction)
        let better = actionName(r.oracleAction)
        let dangerPct = Int((r.danger * 100).rounded())

        switch r.oracleAction {
        case .skip:
            return "Ход \(r.turnNumber): вместо «\(played)» стоило сыграть «Слиняй» — шанс взрыва был ~\(dangerPct)%."
        case .attack:
            return "Ход \(r.turnNumber): лучше было «Нападай» (\(better)) — передать опасный ход сопернику."
        case .shuffle:
            return "Ход \(r.turnNumber): стоило «Затасовать» колоду — риск взрыва был ~\(dangerPct)%."
        case .seeFuture:
            return "Ход \(r.turnNumber): сначала загляни в будущее («\(better)») — потом решай, брать ли карту."
        case .draw:
            return "Ход \(r.turnNumber): можно было спокойно взять карту — риск был низким (~\(dangerPct)%), а ты потратил «\(played)»."
        case .catPair, .catTrio:
            return "Ход \(r.turnNumber): выгоднее украсть карту котами («\(better)»), пока колода безопасна."
        case .favor:
            return "Ход \(r.turnNumber): стоило «Подлизаться» и забрать карту у соперника."
        }
    }

    // MARK: - Стиль игры

    private func detectStyle(records: [CoachMoveRecord]) -> (String, String) {
        guard !records.isEmpty else { return ("НОВИЧОК", "Сыграй больше ходов для анализа стиля.") }
        var aggressive = 0, cautious = 0, manipulative = 0
        for r in records {
            switch r.humanAction {
            case .attack, .skip:           aggressive += 1
            case .seeFuture, .shuffle:     cautious += 1
            case .favor, .catPair, .catTrio: manipulative += 1
            case .draw: break
            }
        }
        let maxVal = max(aggressive, max(cautious, manipulative))
        if maxVal == 0 {
            return ("ВЫЖИВАЛЬЩИК", "Ты в основном берёшь карты и ждёшь удачи. Активнее используй карты действий!")
        }
        if maxVal == aggressive {
            return ("АГРЕССОР", "Ты давишь соперников картами «Нападай» и «Слиняй». Не забывай про защиту!")
        }
        if maxVal == cautious {
            return ("СТРАТЕГ", "Ты осторожен: смотришь будущее и тасуешь колоду. Грамотный контроль риска.")
        }
        return ("МАНИПУЛЯТОР", "Ты любишь воровать карты у соперников. Отличный контроль ресурсов!")
    }

    // MARK: - Имена действий

    static func actionName(_ a: BotAction) -> String {
        switch a {
        case .draw:      return "Взять карту"
        case .attack:    return "Нападай"
        case .skip:      return "Слиняй"
        case .favor:     return "Подлижись"
        case .shuffle:   return "Затасуй"
        case .seeFuture: return "Подсмотри грядущее"
        case .catPair:   return "Пара котов"
        case .catTrio:   return "Трио котов"
        }
    }
}
