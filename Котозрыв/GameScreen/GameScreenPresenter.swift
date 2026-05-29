import Foundation

protocol GameScreenPresenterProtocol: AnyObject {
    var view: GameScreenViewProtocol? { get set }
    var interactor: GameScreenInteractorProtocol? { get set }
    var router: GameScreenRouterProtocol? { get set }
    
    var players: [Player] { get }
    var currentPlayer: Player? { get }
    var currentPlayerHand: [Card] { get }
    var deckCount: Int { get }
    var topDiscardCard: Card? { get }
    var humanPlayer: Player? { get }
    var humanHand: [Card] { get }
    
    func viewDidLoad()
    func playCard(at index: Int)
    func playCards(at indices: [Int])
    func drawCard()
    func endTurn()
    func settingsButtonTapped()
    func placeExplodingKitten(at position: Int)
}

class GameScreenPresenter {
    weak var view: GameScreenViewProtocol?
    var interactor: GameScreenInteractorProtocol?
    var router: GameScreenRouterProtocol?
    
    private var gameState: GameState

    private var aiTopCardsKnowledge: [CardType] = []

    // MARK: - ML-бот
    /// Сложность бота (выбирает обученный чекпойнт DQN). По умолчанию — максимальная.
    private let botDifficulty: BotDifficulty
    private lazy var mlBot = MLBotService(difficulty: botDifficulty)
    /// Приватное знание верхних карт колоды для каждого AI (после See the Future).
    private var aiKnownTop: [UUID: [CardType]] = [:]
    /// Счётчик «не завершающих» действий в текущем ходу бота (защита от зацикливания).
    private var mlChainCount = 0
    private let mlMaxChain = 6

    // MARK: - Личный коуч (LSTM)
    private let coachService = CoachService()
    private var coachRecords: [CoachMoveRecord] = []
    private var humanTurnCounter = 0

    /// Блокировка повторного ввода человека, пока его текущее действие не завершилось
    /// (защита от «протапывания» нескольких карт за один ход).
    private var isHumanBusy = false

    init(gameState: GameState, botDifficulty: BotDifficulty = .hard) {
        self.gameState = gameState
        self.botDifficulty = botDifficulty
    }
    
    var players: [Player] {
        return gameState.players
    }
    
    var currentPlayer: Player? {
        return gameState.currentPlayer
    }
    
    var currentPlayerHand: [Card] {
        return gameState.currentPlayer?.hand ?? []
    }
    
    var deckCount: Int {
        return gameState.deck.count
    }

    var topDiscardCard: Card? {
        return gameState.discardPile.last
    }

    var humanPlayer: Player? {
        return gameState.players.first(where: { $0.type == .human })
    }

    var humanHand: [Card] {
        return humanPlayer?.hand ?? []
    }
    
    private func processAITurn() {
        guard let aiPlayer = gameState.currentPlayer, aiPlayer.type == .ai else { return }

        view?.showMessage("\(aiPlayer.name) думает...")
        mlChainCount = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            guard self.gameState.currentPlayer?.id == aiPlayer.id, aiPlayer.isAlive else { return }
            self.performMLBotAction(for: aiPlayer)
        }
    }

    /// Запросить у DQN-модели действие и выполнить его, переиспользуя
    /// существующие методы анимации/логики (playAICard / playAICatCombo / draw).
    private func performMLBotAction(for aiPlayer: Player) {
        guard gameState.currentPlayer?.id == aiPlayer.id, aiPlayer.isAlive else { return }

        let known = aiKnownTop[aiPlayer.id] ?? []
        let action = mlBot.decide(gameState: gameState, player: aiPlayer, knownTop: known)

        switch action {
        case .draw:
            performDrawCard()

        case .attack:
            playSingleAICard(.attack, by: aiPlayer)
        case .skip:
            playSingleAICard(.skip, by: aiPlayer)
        case .favor:
            playSingleAICard(.favor, by: aiPlayer)
        case .shuffle:
            playSingleAICard(.shuffle, by: aiPlayer)
        case .seeFuture:
            playSingleAICard(.seeTheFuture, by: aiPlayer)

        case .catPair:
            if let cat = MLBotService.bestCatGroup(player: aiPlayer, size: 2) {
                playAICatCombo(Array(aiPlayer.getCards(ofType: cat).prefix(2)), by: aiPlayer)
            } else {
                performDrawCard()
            }
        case .catTrio:
            if let cat = MLBotService.bestCatGroup(player: aiPlayer, size: 3) {
                playAICatCombo(Array(aiPlayer.getCards(ofType: cat).prefix(3)), by: aiPlayer)
            } else {
                performDrawCard()
            }
        }
    }

    /// Записать ход игрока-человека для последующего разбора коучем.
    /// Вызывается ДО изменения состояния игры (чтобы зафиксировать позицию).
    private func recordHumanDecision(_ action: BotAction, by player: Player) {
        guard player.type == .human else { return }
        let known = aiKnownTop[player.id] ?? []
        let obs = BotObservation.encode(gameState: gameState, player: player, knownTop: known)
        // признак шага = obs(31) + one-hot действия(8)
        var feature = obs
        var onehot = [Float](repeating: 0, count: BotAction.allCases.count)
        onehot[action.rawValue] = 1
        feature.append(contentsOf: onehot)
        // оракул: что сходил бы обученный DQN в этой позиции
        let oracle = mlBot.decide(gameState: gameState, player: player, knownTop: known)
        let danger = gameState.deck.isEmpty ? 0
            : Float(gameState.deck.filter { $0.type == .explodingKitten }.count) / Float(gameState.deck.count)
        humanTurnCounter += 1
        coachRecords.append(CoachMoveRecord(
            feature: feature,
            humanAction: action,
            oracleAction: oracle,
            turnNumber: humanTurnCounter,
            danger: danger))
    }

    /// Сопоставить тип карты действию бота (для записи ходов человека).
    private func botAction(forSingle cardType: CardType) -> BotAction? {
        switch cardType {
        case .attack:       return .attack
        case .skip:         return .skip
        case .favor:        return .favor
        case .shuffle:      return .shuffle
        case .seeTheFuture: return .seeFuture
        default:            return nil   // одиночный кот / прочее не входит в action space
        }
    }

    /// Сдвинуть знание верхних карт игрока после того, как он взял карту.
    private func popKnownTop(for player: Player) {
        guard var known = aiKnownTop[player.id], !known.isEmpty else { return }
        known.removeFirst()
        aiKnownTop[player.id] = known
    }

    private func playSingleAICard(_ type: CardType, by aiPlayer: Player) {
        if let card = aiPlayer.getCards(ofType: type).first {
            playAICard(card, by: aiPlayer)
        } else {
            performDrawCard()
        }
    }

    /// Продолжить ход бота после «не завершающего» действия (favor/shuffle/see/коты):
    /// бот может сходить ещё раз (цепочка), пока не возьмёт карту или не сыграет skip/attack.
    private func continueMLBotTurn(for aiPlayer: Player) {
        guard gameState.currentPlayer?.id == aiPlayer.id, aiPlayer.isAlive else {
            triggerAITurnIfNeeded()
            return
        }
        mlChainCount += 1
        if mlChainCount > mlMaxChain {
            performDrawCard()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.performMLBotAction(for: aiPlayer)
        }
    }
    
    private func chooseBestCardForAI(_ aiPlayer: Player) -> Card? {
        let playableCards = aiPlayer.hand.filter { card in
            card.type.isPlayable && card.type != .defuse && !isCatCard(card.type) && card.type != .nope
        }

        guard !playableCards.isEmpty else { return nil }

        let dangerScore = deckDangerScore()

        if aiTopCardsKnowledge.first == .explodingKitten {
            aiTopCardsKnowledge = []
            return firstCard(in: playableCards, of: .skip)
                ?? firstCard(in: playableCards, of: .attack)
                ?? firstCard(in: playableCards, of: .shuffle)
        }

        if dangerScore >= 0.25 {
            return firstCard(in: playableCards, of: .shuffle)
                ?? firstCard(in: playableCards, of: .skip)
                ?? firstCard(in: playableCards, of: .attack)
        }

        if dangerScore >= 0.10 && aiTopCardsKnowledge.isEmpty {
            if let seeCard = firstCard(in: playableCards, of: .seeTheFuture) {
                return seeCard
            }
        }

        if let favorCard = firstCard(in: playableCards, of: .favor) {
            return favorCard
        }

        return nil
    }


    private func chooseCatComboForAI(_ aiPlayer: Player) -> [Card]? {
        guard deckDangerScore() < 0.10,
              aiTopCardsKnowledge.first != .explodingKitten else { return nil }

        let opponents = gameState.players.filter {
            $0.id != aiPlayer.id && $0.isAlive && !$0.hand.isEmpty
        }
        guard !opponents.isEmpty else { return nil }

        let catTypes: [CardType] = [.catBeard, .catTaco, .catWatermelon, .catPotato]
        for catType in catTypes {
            let matching = aiPlayer.hand.filter { $0.type == catType }
            if matching.count >= 3 { return Array(matching.prefix(3)) }
        }
        return nil
    }

    private func playAICatCombo(_ cards: [Card], by aiPlayer: Player) {
        for card in cards {
            _ = aiPlayer.removeCard(card)
            gameState.discardPile.append(card)
        }
        view?.updateUI()

        guard let sample = cards.first else { return }
        let comboCount = cards.count

        view?.animateCardPlay(card: sample, by: aiPlayer) { [weak self] in
            guard let self = self else { return }

            let opponents = self.gameState.players
                .filter { $0.id != aiPlayer.id && $0.isAlive && !$0.hand.isEmpty }
            guard let target = opponents.max(by: { $0.hand.count < $1.hand.count }) else {
                self.continueMLBotTurn(for: aiPlayer)
                return
            }

            let stolen: Card?
            if comboCount >= 3 {
                stolen = self.aiSelectCardToSteal(from: target)
                    .flatMap { target.removeCard($0) }
            } else {
                stolen = target.hand.randomElement().flatMap { target.removeCard($0) }
            }

            if let card = stolen {
                aiPlayer.addCard(card)
                self.cardStolen(card: card, from: target, to: aiPlayer)
            } else {
                self.view?.updateUI()
            }

            self.continueMLBotTurn(for: aiPlayer)
        }
    }

    private func aiSelectCardToSteal(from player: Player) -> Card? {
        let priority: [CardType] = [.defuse, .attack, .skip, .shuffle, .favor, .seeTheFuture, .nope]
        for cardType in priority {
            if let card = player.hand.first(where: { $0.type == cardType }) {
                return card
            }
        }
        return player.hand.first
    }
    
    private func playAICard(_ card: Card, by player: Player) {
        _ = player.removeCard(card)
        gameState.discardPile.append(card)
        view?.updateUI()
        view?.animateCardPlay(card: card, by: player) { [weak self] in
            guard let self = self else { return }
            self.checkNopeForCard(card, playedBy: player) { [weak self] wasNoped in
                guard let self = self else { return }
                if !wasNoped {
                    self.handleCardPlay(card: card, player: player)
                    self.view?.showCardEffect(card.type)
                } else {
                    self.view?.showMessage("\(player.name)'s action was cancelled by Nope!")
                }
                self.view?.updateUI()
                self.resolveAITurnAfterPlaying(card.type, aiPlayer: player, wasNoped: wasNoped)
            }
        }
    }

    private func resolveAITurnAfterPlaying(_ cardType: CardType, aiPlayer: Player, wasNoped: Bool) {
        if wasNoped {
            // Действие отменили — карта потрачена, бот принимает решение заново.
            continueMLBotTurn(for: aiPlayer)
            return
        }
        switch cardType {
        case .skip:
            endTurn()

        case .attack:
            triggerAITurnIfNeeded()

        default:
            // favor / shuffle / seeTheFuture не завершают ход — бот ходит дальше (цепочка).
            continueMLBotTurn(for: aiPlayer)
        }
    }
    
    // MARK: - Nope Handling

    private func checkNopeForCard(_ card: Card, playedBy player: Player, completion: @escaping (Bool) -> Void) {
        guard card.type.canBeNoped else {
            completion(false)
            return
        }
        nopeRound(originalCard: card, lastActor: player, nopeCount: 0, completion: completion)
    }

    private func nopeRound(originalCard: Card, lastActor: Player, nopeCount: Int,
                           completion: @escaping (Bool) -> Void) {
        guard nopeCount < 8 else {
            completion(nopeCount % 2 == 1)
            return
        }

        if lastActor.type == .human {
            if let nopeAI = aiDecidesToNope(card: originalCard, exceptPlayer: lastActor) {
                var nopeCardForAnim: Card? = nil
                if let nopeCard = nopeAI.getCards(ofType: .nope).first {
                    _ = nopeAI.removeCard(nopeCard)
                    gameState.discardPile.append(nopeCard)
                    nopeCardForAnim = nopeCard
                }
                view?.showMessage("\(nopeAI.name) сыграл Неть!")
                view?.updateUI()

                let animCard = nopeCardForAnim ?? Card(type: .nope)
                view?.animateCardPlay(card: animCard, by: nopeAI) { [weak self] in
                    self?.nopeRound(originalCard: originalCard, lastActor: nopeAI,
                                    nopeCount: nopeCount + 1, completion: completion)
                }
            } else {
                completion(nopeCount % 2 == 1)
            }
        } else {
            guard let human = humanPlayer, human.isAlive else {
                completion(nopeCount % 2 == 1)
                return
            }

            let hasNope = human.hasCard(ofType: .nope)
            view?.showNopeWindow(canPlayNope: hasNope) { [weak self] decision in
                guard let self = self else { return }
                switch decision {
                case .played:
                    guard let nope = self.humanPlayer?.getCards(ofType: .nope).first,
                          let removed = self.humanPlayer?.removeCard(nope) else {
                        completion(nopeCount % 2 == 1)
                        return
                    }
                    self.gameState.discardPile.append(removed)
                    self.view?.showMessage("Вы сыграли Неть!")
                    self.view?.updateUI()
                    self.view?.animateCardPlay(card: removed, by: human) { [weak self] in
                        self?.nopeRound(originalCard: originalCard, lastActor: human,
                                        nopeCount: nopeCount + 1, completion: completion)
                    }
                case .declined, .timedOut:
                    completion(nopeCount % 2 == 1)
                }
            }
        }
    }

    private func aiDecidesToNope(card: Card, exceptPlayer: Player? = nil) -> Player? {
        guard let current = gameState.currentPlayer else { return nil }
        let aiCandidates = gameState.players.filter {
            $0.type == .ai && $0.isAlive && $0.hasCard(ofType: .nope) && $0.id != exceptPlayer?.id
        }
        guard !aiCandidates.isEmpty else { return nil }

        switch card.type {
        case .attack:
            guard let next = nextAlivePlayer(after: current),
                  next.type == .ai,
                  let candidate = aiCandidates.first(where: { $0.id == next.id }) else { return nil }
            let threshold = candidate.hand.count <= 3 ? 4 : (candidate.hand.count <= 5 ? 2 : 0)
            return Int.random(in: 0..<5) < threshold ? candidate : nil

        case .favor:
            guard let weakest = aiCandidates.min(by: { $0.hand.count < $1.hand.count }) else { return nil }
            let threshold = weakest.hand.count <= 3 ? 3 : (weakest.hand.count <= 5 ? 1 : 0)
            return Int.random(in: 0..<5) < threshold ? weakest : nil

        case .shuffle:
            guard !aiTopCardsKnowledge.isEmpty,
                  !aiTopCardsKnowledge.contains(.explodingKitten) else { return nil }
            return aiCandidates.first

        default:
            return nil
        }
    }

    private func deckDangerScore() -> Double {
        guard !gameState.deck.isEmpty else { return 0 }
        let explodingCardsCount = gameState.deck.filter { $0.type == .explodingKitten }.count
        return Double(explodingCardsCount) / Double(gameState.deck.count)
    }
    
    private func shouldPressureNextPlayer(_ aiPlayer: Player) -> Bool {
        guard let nextPlayer = nextAlivePlayer(after: aiPlayer) else { return false }
        return nextPlayer.type == .human || nextPlayer.hand.count <= aiPlayer.hand.count
    }
    
    private func shouldStealCard(_ aiPlayer: Player) -> Bool {
        let opponents = gameState.players.filter {
            $0.id != aiPlayer.id && $0.isAlive && !$0.hand.isEmpty
        }
        
        guard let strongestOpponent = opponents.max(by: { $0.hand.count < $1.hand.count }) else {
            return false
        }
        
        return aiPlayer.hand.count <= 4 || strongestOpponent.hand.count >= aiPlayer.hand.count + 2
    }
    
    private func nextAlivePlayer(after player: Player) -> Player? {
        guard let playerIndex = gameState.players.firstIndex(where: { $0.id == player.id }) else {
            return nil
        }
        
        var index = (playerIndex + 1) % gameState.players.count
        while index != playerIndex {
            let candidate = gameState.players[index]
            if candidate.isAlive {
                return candidate
            }
            index = (index + 1) % gameState.players.count
        }
        
        return nil
    }
    
    private func firstCard(in cards: [Card], of type: CardType) -> Card? {
        return cards.first { $0.type == type }
    }
    
    private func isCatCard(_ type: CardType) -> Bool {
        switch type {
        case .catBeard, .catTaco, .catWatermelon, .catPotato:
            return true
        default:
            return false
        }
    }
    
    private func chooseExplodingKittenPositionForAI() -> Int {
        return gameState.deck.count
    }
    
    private func handleCardPlay(card: Card, player: Player) {
        interactor?.playCard(card: card, by: player, gameState: gameState)
    }
    
    private func performDrawCard() {
        guard let player = gameState.currentPlayer else { return }
        
        interactor?.drawCard(for: player, gameState: gameState)
    }
    
    private func checkGameOver() {
        let alivePlayers = gameState.alivePlayers()
        if alivePlayers.count == 1 {
            gameState.isGameOver = true
            gameState.winner = alivePlayers.first
            if let winner = gameState.winner {
                // Если играл человек и есть записанные ходы — показываем разбор коуча,
                // иначе сразу экран финала.
                if let human = humanPlayer, !coachRecords.isEmpty {
                    let didWin = winner.id == human.id
                    let report = coachService.analyze(records: coachRecords, didWin: didWin)
                    view?.showCoachAnalysis(report: report, winner: winner)
                } else {
                    view?.navigateToGameOver(winner: winner)
                }
            }
        }
    }
}

// MARK: - GameScreenPresenterProtocol
extension GameScreenPresenter: GameScreenPresenterProtocol {
    func viewDidLoad() {
        interactor?.setupGame(gameState: gameState)
        view?.updateUI()
        
        if gameState.currentPlayer?.type == .ai {
            processAITurn()
        }
    }
    
    func playCard(at index: Int) {
        guard let player = gameState.currentPlayer,
              player.type == .human,
              index < player.hand.count else { return }

        let card = player.hand[index]

        guard card.type.isPlayable else {
            view?.showMessage("This card cannot be played")
            return
        }
        guard !isHumanBusy else { return }
        isHumanBusy = true

        // запись хода для коуча (до изменения состояния)
        if let action = botAction(forSingle: card.type) {
            recordHumanDecision(action, by: player)
        }

        _ = player.removeCard(card)
        gameState.discardPile.append(card)
        view?.updateUI()

        view?.animateCardPlay(card: card, by: player) { [weak self] in
            guard let self = self else { return }
            self.checkNopeForCard(card, playedBy: player) { [weak self] wasNoped in
                guard let self = self else { return }
                if !wasNoped {
                    self.handleCardPlay(card: card, player: player)
                    self.view?.showCardEffect(card.type)
                    self.handlePostHumanPlay(card: card, player: player)
                    // skip/attack завершают ход (разблокирует endTurn / возврат от ИИ);
                    // favor/shuffle/see — ход продолжается, разблокируем здесь.
                    if card.type != .skip && card.type != .attack {
                        self.isHumanBusy = false
                    }
                } else {
                    self.view?.showMessage("Action cancelled by Nope!")
                    self.isHumanBusy = false   // карта отменена — ход продолжается
                }
                self.view?.updateUI()
            }
        }
    }

    private func handlePostHumanPlay(card: Card, player: Player) {
        switch card.type {
        case .skip:
            endTurn()
        case .attack:
            triggerAITurnIfNeeded()
        default:
            break
        }
    }

    private func triggerAITurnIfNeeded() {
        guard gameState.currentPlayer?.type == .ai else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.processAITurn()
        }
    }
    
    func drawCard() {
        guard let player = gameState.currentPlayer,
              player.type == .human else { return }
        guard !isHumanBusy else { return }   // ход уже обрабатывается — игнорируем повторный тап
        isHumanBusy = true

        recordHumanDecision(.draw, by: player)
        performDrawCard()
    }

    func playCards(at indices: [Int]) {
        guard let player = gameState.currentPlayer, player.type == .human else { return }
        let sortedIndices = indices.sorted()
        let cards = sortedIndices.compactMap {
            player.hand.indices.contains($0) ? player.hand[$0] : nil
        }
        guard !cards.isEmpty else { return }

        if cards.count == 1 {
            if let realIndex = player.hand.firstIndex(where: { $0.id == cards[0].id }) {
                playCard(at: realIndex)
            }
            return
        }

        guard let firstType = cards.first?.type,
              cards.allSatisfy({ $0.type == firstType }) else {
            view?.showMessage("Карты должны быть одного типа")
            return
        }

        guard cards.count == 2 || cards.count == 3 else {
            view?.showMessage("Можно играть 1, 2 или 3 карты")
            return
        }
        guard !isHumanBusy else { return }
        isHumanBusy = true

        // запись комбо для коуча (до изменения состояния)
        recordHumanDecision(cards.count == 2 ? .catPair : .catTrio, by: player)

        for c in cards {
            _ = player.removeCard(c)
            gameState.discardPile.append(c)
        }
        view?.updateUI()

        if cards.count == 2 {
            playComboPair(of: firstType, by: player, sample: cards[0])
        } else {
            playComboTrio(of: firstType, by: player, sample: cards[0])
        }
    }

    private func playComboPair(of type: CardType, by player: Player, sample: Card) {
        view?.animateCardPlay(card: sample, by: player) { [weak self] in
            guard let self = self else { return }
            self.view?.showMessage("Особая комбинация: пара \(type.rawValue)!")

            let opponents = self.gameState.players
                .filter { $0.id != player.id && $0.isAlive && !$0.hand.isEmpty }
            guard !opponents.isEmpty else {
                self.view?.showMessage("Нет соперников с картами")
                self.view?.updateUI()
                self.isHumanBusy = false   // комбо не завершает ход
                return
            }
            self.view?.promptSelectPlayer(players: opponents) { [weak self] target in
                guard let self = self else { return }
                if let randomCard = target.hand.randomElement(),
                   let removed = target.removeCard(randomCard) {
                    player.addCard(removed)
                    self.cardStolen(card: removed, from: target, to: player)
                } else {
                    self.view?.updateUI()
                }
                self.isHumanBusy = false   // комбо не завершает ход — игрок ходит дальше
            }
        }
    }

    private func playComboTrio(of type: CardType, by player: Player, sample: Card) {
        view?.animateCardPlay(card: sample, by: player) { [weak self] in
            guard let self = self else { return }
            self.view?.showMessage("Особая комбинация: трио \(type.rawValue)!")

            let opponents = self.gameState.players
                .filter { $0.id != player.id && $0.isAlive }
            guard !opponents.isEmpty else {
                self.view?.updateUI()
                self.isHumanBusy = false   // комбо не завершает ход
                return
            }
            self.view?.promptSelectPlayer(players: opponents) { [weak self] target in
                guard let self = self else { return }
                self.view?.promptSelectCardType { [weak self] requested in
                    guard let self = self else { return }
                    guard let requested = requested else {
                        self.view?.updateUI()
                        self.isHumanBusy = false   // выбор отменён — ход продолжается
                        return
                    }
                    if let card = target.hand.first(where: { $0.type == requested }),
                       let removed = target.removeCard(card) {
                        player.addCard(removed)
                        self.cardStolen(card: removed, from: target, to: player)
                    } else {
                        self.view?.showMessage("У \(target.name) нет карты «\(requested.displayName)»")
                        self.view?.updateUI()
                    }
                    self.isHumanBusy = false   // комбо не завершает ход — игрок ходит дальше
                }
            }
        }
    }
    
    func endTurn() {
        guard let player = gameState.currentPlayer else { return }

        if !player.isAlive {
            player.turnsRemaining = 1
            gameState.nextPlayer()
        } else {
            if player.turnsRemaining > 0 {
                player.turnsRemaining -= 1
            }
            if player.turnsRemaining == 0 {
                player.turnsRemaining = 1
                gameState.nextPlayer()
            }
        }

        view?.updateUI()
        // ход вернулся к человеку — снимаем блокировку ввода
        if gameState.currentPlayer?.type == .human {
            isHumanBusy = false
        }
        triggerAITurnIfNeeded()
    }

    func settingsButtonTapped() {
        router?.navigateToSettings()
    }
    
    func placeExplodingKitten(at position: Int) {
        interactor?.placeExplodingKittenInDeck(at: position, gameState: gameState)
        endTurn()
    }
}

// MARK: - GameScreenInteractorOutputProtocol
extension GameScreenPresenter: GameScreenInteractorOutputProtocol {
    func cardDrawn(card: Card, by player: Player) {
        popKnownTop(for: player)
        let isHuman = player.type == .human
        view?.showMessage(isHuman
            ? "\(player.name) drew: \(card.type.rawValue)"
            : "\(player.name) берёт карту.")

        view?.animateCardDraw(card: card, by: player, revealFace: isHuman) { [weak self] in
            guard let self = self else { return }
            self.view?.updateUI()

            if card.type != .explodingKitten {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.endTurn()
                }
            }
        }
    }
    
    func playerExploded(_ player: Player, hasDefuse: Bool) {
        popKnownTop(for: player)
        if hasDefuse {
            if player.type == .ai {
                view?.showMessage("\(player.name) defused the Exploding Kitten")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self = self else { return }
                    self.placeExplodingKitten(at: self.chooseExplodingKittenPositionForAI())
                }
            } else {
                view?.showMessage("\(player.name) drew the Exploding Kitten! Use Defuse")
                view?.showDefuseOptions()
            }
        } else {
            player.isAlive = false
            view?.showExplosion(playerName: player.name)
            view?.updateUI()
            checkGameOver()

            if !gameState.isGameOver {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.endTurn()
                }
            }
        }
    }
    
    func showSeeTheFutureCards(_ cards: [Card]) {
        if let cur = gameState.currentPlayer, cur.type == .ai {
            aiTopCardsKnowledge = cards.map { $0.type }
            aiKnownTop[cur.id] = cards.map { $0.type }   // приватное знание для ML-бота
        } else {
            if let human = humanPlayer {
                aiKnownTop[human.id] = cards.map { $0.type }  // для obs коуча
            }
            view?.showSeeTheFutureCards(cards)
        }
    }
    
    func promptPlayerSelection(availablePlayers: [Player], completion: @escaping (Player) -> Void) {
        view?.promptSelectPlayer(players: availablePlayers, completion: completion)
    }
    
    func promptCardSelection(from player: Player, completion: @escaping (CardType?) -> Void) {
        view?.promptSelectCard(from: player, completion: completion)
    }
    
    func cardEffectApplied(message: String) {
        if message == "Deck shuffled" {
            aiTopCardsKnowledge = []
            aiKnownTop.removeAll()   // перемешивание обнуляет знание верхних карт
        }
        view?.showMessage(message)
        view?.updateUI()
    }

    func promptCardFromHand(of target: Player, requesterName: String, completion: @escaping (Card?) -> Void) {
        view?.promptComboRequest(requesterName: requesterName, cards: target.hand, completion: completion)
    }

    func cardStolen(card: Card, from sender: Player, to receiver: Player) {
        let revealFace = receiver.type == .human
        view?.animateCardTransfer(card: card, from: sender, to: receiver, revealFace: revealFace) { [weak self] in
            let msg: String
            if receiver.type == .human {
                msg = "Вы получили: \(card.type.displayName)"
            } else if sender.type == .human {
                msg = "У вас украли: \(card.type.displayName)"
            } else {
                msg = "\(receiver.name) забрал карту у \(sender.name)"
            }
            self?.view?.showMessage(msg)
            self?.view?.updateUI()
        }
    }
}
