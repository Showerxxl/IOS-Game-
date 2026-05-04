import Foundation

final class MultiplayerGamePresenter {

    weak var view: GameScreenViewProtocol?
    var interactor: GameScreenInteractorProtocol?
    var router: GameScreenRouterProtocol?

    private let network: NetworkClient
    private let myPlayerId: String
    private let roomId: String

    private var localPlayers: [Player] = []
    private var localDeckCount: Int = 0
    private var localCurrentPlayerId: String = ""
    private var lastDiscardCard: Card?


    private var myHand: [Card] = []

    private var pendingBombId: String?

    private var pendingFavorCardId: String?

    init(network: NetworkClient = .shared, myPlayerId: String, roomId: String) {
        self.network    = network
        self.myPlayerId = myPlayerId
        self.roomId     = roomId
        network.onEvent = { [weak self] event, data in
            self?.handleServerEvent(event, data: data)
        }
    }

    // MARK: - Private helpers

    private func player(forNetworkId nid: String) -> Player? {
        localPlayers.first { $0.networkID == nid }
    }

    private var isMyTurn: Bool { localCurrentPlayerId == myPlayerId }

    private func syncState(from data: [String: Any]) {
        localDeckCount       = data["deck_size"] as? Int ?? localDeckCount
        localCurrentPlayerId = data["current_player_id"] as? String ?? localCurrentPlayerId

        if let topRaw = data["top_discard_card"] as? [String: Any],
           let cid    = topRaw["id"]   as? String,
           let tstr   = topRaw["type"] as? String,
           let type   = CardType(serverType: tstr) {
            lastDiscardCard = Card(serverID: cid, type: type)
        }

        guard let playersRaw = data["players"] as? [[String: Any]] else { return }

        for raw in playersRaw {
            guard let pid  = raw["player_id"] as? String,
                  let name = raw["name"] as? String else { continue }

            if player(forNetworkId: pid) == nil {
                let type: PlayerType = (pid == myPlayerId) ? .human : .ai
                localPlayers.append(Player(name: name, type: type, networkID: pid))
            }
        }

        for raw in playersRaw {
            guard let pid = raw["player_id"] as? String,
                  let p   = player(forNetworkId: pid) else { continue }

            p.isAlive        = raw["alive"]           as? Bool ?? p.isAlive
            p.turnsRemaining = raw["turns_remaining"] as? Int  ?? p.turnsRemaining

            if pid != myPlayerId {
                let count = raw["card_count"] as? Int ?? 0

                if p.hand.count != count {
                    p.hand = (0..<count).map { _ in Card(type: .nope) }
                }
            }

     
            if pid == myPlayerId, let handRaw = raw["hand"] as? [[String: Any]] {
                var newHand: [Card] = []
                for cardRaw in handRaw {
                    guard let cid  = cardRaw["id"]   as? String,
                          let ctype = cardRaw["type"] as? String,
                          let type  = CardType(serverType: ctype) else { continue }
 
                    if let existing = myHand.first(where: { $0.serverID == cid }) {
                        newHand.append(existing)
                    } else {
                        newHand.append(Card(serverID: cid, type: type))
                    }
                }
                myHand = newHand
                if let me = player(forNetworkId: myPlayerId) {
                    me.hand = myHand
                }
            }
        }
    }

    // MARK: - Server event router

    private func handleServerEvent(_ event: String, data: [String: Any]) {
        switch event {

        case "stateUpdate":
            syncState(from: data)
            view?.updateUI()

        case "gameStarted":
            view?.showMessage("Игра началась!")

        case "cardPlayed":
            let playerName = playerName(for: data["player_id"] as? String)
            if let cardData = data["card"] as? [String: Any],
               let typeStr  = cardData["type"] as? String,
               let cardName = cardData["name"] as? String,
               let type     = CardType(serverType: typeStr),
               let cid      = cardData["id"] as? String {
                let card = Card(serverID: cid, type: type)
                lastDiscardCard = card
                let source = player(forNetworkId: data["player_id"] as? String ?? "")
                    ?? Player(name: playerName, type: .ai)
                view?.animateCardPlay(card: card, by: source) { [weak self] in
                    self?.view?.showMessage("\(playerName) сыграл: \(cardName)")
                    self?.view?.updateUI()
                }
            }

        case "cardDrawn":
            let playerName = playerName(for: data["player_id"] as? String)
            view?.showMessage("\(playerName) берёт карту из колоды")

        case "cardReceived":
            if let cardData = data["card"] as? [String: Any],
               let typeStr  = cardData["type"] as? String,
               let type     = CardType(serverType: typeStr),
               let cid      = cardData["id"] as? String {
                let card = Card(serverID: cid, type: type)
                if let me = player(forNetworkId: myPlayerId) {
                    view?.animateCardDraw(card: card, by: me, revealFace: true) { [weak self] in
                        self?.view?.updateUI()
                    }
                }
            }

        case "turnEnded":
            view?.updateUI()

        case "deckShuffled":
            view?.showMessage("Колода перемешана!")
            view?.updateUI()

        case "seeTheFuture":
            if let cardsRaw = data["cards"] as? [[String: Any]] {
                let cards = cardsRaw.compactMap { raw -> Card? in
                    guard let cid  = raw["id"]   as? String,
                          let tstr = raw["type"] as? String,
                          let type = CardType(serverType: tstr) else { return nil }
                    return Card(serverID: cid, type: type)
                }
                view?.showSeeTheFutureCards(cards)
            }

        case "favorRequest":
            let requesterName = data["requester_name"] as? String ?? "Игрок"
            let handRaw = data["your_hand"] as? [[String: Any]] ?? []
            let cards = handRaw.compactMap { raw -> Card? in
                guard let cid  = raw["id"]   as? String,
                      let tstr = raw["type"] as? String,
                      let type = CardType(serverType: tstr) else { return nil }
                return Card(serverID: cid, type: type)
            }
            guard !cards.isEmpty else { break }
            view?.promptComboRequest(requesterName: requesterName, cards: cards) { [weak self] chosen in
                guard let self = self, let card = chosen else { return }
                self.network.sendAction(["action": "favorResponse", "card_id": card.serverID])
            }

        case "favorReceived":
            if let cardData = data["card"] as? [String: Any],
               let cid    = cardData["id"]   as? String,
               let tstr   = cardData["type"] as? String,
               let type   = CardType(serverType: tstr),
               let me     = player(forNetworkId: myPlayerId) {
                let card = Card(serverID: cid, type: type)
                let fromId = data["from_player_id"] as? String ?? ""
                let sender = player(forNetworkId: fromId)
                    ?? Player(name: playerName(for: fromId), type: .ai)
                view?.animateCardTransfer(card: card, from: sender, to: me, revealFace: true) { [weak self] in
                    self?.view?.showMessage("Вы получили: \(card.type.displayName)")
                    self?.view?.updateUI()
                }
            }

        case "favorLost":
            if let cardName = data["card_name"] as? String,
               let me = player(forNetworkId: myPlayerId) {
                let toId = data["to_player_id"] as? String ?? ""
                let receiver = player(forNetworkId: toId)
                    ?? Player(name: playerName(for: toId), type: .ai)
                let placeholder = Card(type: .nope)
                view?.animateCardTransfer(card: placeholder, from: me, to: receiver, revealFace: false) { [weak self] in
                    self?.view?.showMessage("Вы отдали: \(cardName)")
                    self?.view?.updateUI()
                }
            }

        case "explodingKittenDrawn":
            let name = playerName(for: data["player_id"] as? String)
            view?.showMessage("💥 \(name) вытащил Взрывного котёнка!")

        case "defuseUsed":
            let name = playerName(for: data["player_id"] as? String)
            view?.showMessage("\(name) обезвредил котёнка!")

        case "defuseRequested":
            pendingBombId = data["bomb_card_id"] as? String
            view?.showDefuseOptions()

        case "explodingKittenPlaced":
            let name = playerName(for: data["player_id"] as? String)
            view?.showMessage("\(name) вернул котёнка в колоду")

        case "playerEliminated":
            let name = playerName(for: data["player_id"] as? String)
            view?.showExplosion(playerName: name)
            view?.updateUI()

        case "actionPending":
            let originatorId = data["player_id"] as? String ?? ""
            let lastActorId  = data["last_actor_id"] as? String ?? originatorId
            let nopeCount    = data["nope_count"] as? Int ?? 0
            guard lastActorId != myPlayerId else { break }
            guard player(forNetworkId: myPlayerId)?.isAlive == true else { break }

            let cardName    = (data["card"] as? [String: Any])?["name"] as? String ?? "карту"
            let isCombo     = data["is_combo"] as? Bool ?? false
            let actorName   = playerName(for: lastActorId)
            let originName  = playerName(for: originatorId)

            let msg: String
            if nopeCount == 0 {
                msg = isCombo
                    ? "\(originName) играет комбо! 5 сек на НЕТЬ"
                    : "\(originName) сыграл: \(cardName). 5 сек на НЕТЬ"
            } else {
                msg = "\(actorName) ответил НЕТЬ! Можно перебить — 5 сек"
            }
            view?.showMessage(msg)

            let hasNope = myHand.contains { $0.type == .nope }
            view?.showNopeWindow(canPlayNope: hasNope) { [weak self] decision in
                guard let self = self else { return }
                switch decision {
                case .played:
                    if let nopeCard = self.myHand.first(where: { $0.type == .nope }) {
                        self.myHand.removeAll(where: { $0.serverID == nopeCard.serverID })
                        if let me = self.player(forNetworkId: self.myPlayerId) {
                            me.hand = self.myHand
                        }
                        self.view?.updateUI()
                        self.network.sendAction(["action": "playNope", "card_id": nopeCard.serverID])
                    }
                case .declined:
                    self.network.sendAction(["action": "declineNope"])
                case .timedOut:
                    break
                }
            }

        case "actionNoped":
            let noperId   = data["nope_player_id"] as? String ?? ""
            let nopeName  = playerName(for: noperId)
            let noper     = player(forNetworkId: noperId)
                ?? Player(name: nopeName, type: noperId == myPlayerId ? .human : .ai)
            let nopeCard  = Card(type: .nope)
            lastDiscardCard = nopeCard
            view?.animateCardPlay(card: nopeCard, by: noper) { [weak self] in
                self?.view?.showMessage("\(nopeName) сыграл Неть!")
                self?.view?.updateUI()
            }

        case "actionResolved":
            view?.dismissNopeWindow()
            let applied = data["applied"] as? Bool ?? true
            view?.showMessage(applied ? "Действие применилось" : "Действие отменено")
            view?.updateUI()

        case "comboRequest":
            let requesterName = data["requester_name"] as? String ?? "Игрок"
            let handRaw = data["your_hand"] as? [[String: Any]] ?? []
            let cards = handRaw.compactMap { raw -> Card? in
                guard let cid  = raw["id"]   as? String,
                      let tstr = raw["type"] as? String,
                      let type = CardType(serverType: tstr) else { return nil }
                return Card(serverID: cid, type: type)
            }
            guard !cards.isEmpty else { break }
            view?.promptComboRequest(requesterName: requesterName, cards: cards) { [weak self] chosen in
                guard let self = self, let card = chosen else { return }
                self.network.sendAction(["action": "comboResponse", "card_id": card.serverID])
            }

        case "nopeUsed":
            let name = playerName(for: data["player_id"] as? String)
            view?.showMessage("\(name) сыграл Неть!")

        case "comboStolen":
            if let cardData = data["card"] as? [String: Any],
               let cid  = cardData["id"]   as? String,
               let tstr = cardData["type"] as? String,
               let type = CardType(serverType: tstr),
               let me   = player(forNetworkId: myPlayerId) {
                let card = Card(serverID: cid, type: type)
                let fromId = data["from_player_id"] as? String ?? ""
                let sender = player(forNetworkId: fromId)
                    ?? Player(name: playerName(for: fromId), type: .ai)
                view?.animateCardTransfer(card: card, from: sender, to: me, revealFace: true) { [weak self] in
                    self?.view?.showMessage("Вы украли: \(card.type.displayName)")
                    self?.view?.updateUI()
                }
            }

        case "comboLost":
            if let cardName = (data["card"] as? [String: Any])?["name"] as? String,
               let me = player(forNetworkId: myPlayerId) {
                let toId = data["to_player_id"] as? String ?? ""
                let receiver = player(forNetworkId: toId)
                    ?? Player(name: playerName(for: toId), type: .ai)
                let placeholder = Card(type: .nope)
                view?.animateCardTransfer(card: placeholder, from: me, to: receiver, revealFace: false) { [weak self] in
                    self?.view?.showMessage("У вас украли: \(cardName)")
                    self?.view?.updateUI()
                }
            }

        case "comboMiss":
            view?.showMessage("Комбо не сработало — у соперника нет нужной карты")

        case "comboResult":
            view?.updateUI()

        case "catCardPlayed":
            let name = playerName(for: data["player_id"] as? String)
            view?.showMessage("\(name) сыграл кошкокарту")

        case "gameFinished":
            let winnerId   = data["winner_id"] as? String ?? ""
            let winnerName = data["winner_name"] as? String ?? "?"
            let winner = player(forNetworkId: winnerId)
                ?? Player(name: winnerName, type: winnerId == myPlayerId ? .human : .ai)
            view?.navigateToGameOver(winner: winner)

        case "playerLeft":
            let name = playerName(for: data["player_id"] as? String)
            view?.showMessage("\(name) покинул игру")
            view?.updateUI()

        case "error":
            view?.showMessage(data["message"] as? String ?? "Ошибка сервера")

        default:
            break
        }
    }

    private func playerName(for networkId: String?) -> String {
        guard let nid = networkId else { return "Игрок" }
        return player(forNetworkId: nid)?.name ?? (nid == myPlayerId ? "Вы" : "Игрок")
    }
}

// MARK: - GameScreenPresenterProtocol

extension MultiplayerGamePresenter: GameScreenPresenterProtocol {

    var players: [Player]          { localPlayers }
    var currentPlayerHand: [Card]  { myHand }
    var deckCount: Int             { localDeckCount }
    var topDiscardCard: Card?      { lastDiscardCard }
    var humanPlayer: Player?       { player(forNetworkId: myPlayerId) }
    var humanHand: [Card]          { myHand }

    var currentPlayer: Player? {
        player(forNetworkId: localCurrentPlayerId)
    }

    func viewDidLoad() {
    }

    func playCard(at index: Int) {
        playCards(at: [index])
    }

    func playCards(at indices: [Int]) {
        guard isMyTurn else { return }
        let sorted = indices.sorted()
        let cards  = sorted.compactMap { myHand.indices.contains($0) ? myHand[$0] : nil }
        guard let first = cards.first else { return }

        if cards.count == 1 {
            if first.type == .favor {
                let targets = localPlayers.filter { $0.networkID != myPlayerId && $0.isAlive && !$0.hand.isEmpty }
                pendingFavorCardId = first.serverID
                view?.promptSelectPlayer(players: targets) { [weak self] target in
                    guard let self = self, let tid = target.networkID else { return }
                    self.network.sendAction([
                        "action":           "playCard",
                        "card_id":          first.serverID,
                        "target_player_id": tid,
                    ])
                    self.pendingFavorCardId = nil
                }
            } else {
                network.sendAction(["action": "playCard", "card_id": first.serverID])
            }
        } else {
            guard cards.count == 2 || cards.count == 3 else { return }
            let allSameType = cards.allSatisfy { $0.type == first.type }
            let forbiddenForCombo: [CardType] = [.explodingKitten, .defuse]
            guard allSameType, !forbiddenForCombo.contains(first.type) else {
                view?.showMessage("Комбо: нужно 2 или 3 одинаковые карты")
                return
            }
            let cardIds = cards.map { $0.serverID }
            let comboCount = cards.count
            let targets = localPlayers.filter { $0.networkID != myPlayerId && $0.isAlive }
            view?.promptSelectPlayer(players: targets) { [weak self] target in
                guard let self = self, let tid = target.networkID else { return }
                if comboCount == 2 {
                    self.network.sendAction([
                        "action":           "playCard",
                        "card_ids":         cardIds,
                        "target_player_id": tid,
                        "combo_count":      2,
                    ])
                } else {
                    self.view?.promptSelectCardType { [weak self] cardType in
                        guard let self = self, let ct = cardType else { return }
                        self.network.sendAction([
                            "action":               "playCard",
                            "card_ids":             cardIds,
                            "target_player_id":     tid,
                            "combo_count":          3,
                            "requested_card_type":  ct.serverTypeString,
                        ])
                    }
                }
            }
        }
    }

    func drawCard() {
        guard isMyTurn else { return }
        network.sendAction(["action": "drawCard"])
    }

    func endTurn() {
    }

    func settingsButtonTapped() {
        router?.navigateToSettings()
    }

    func placeExplodingKitten(at position: Int) {
        let pos: String
        if position == 0            { pos = "top"    }
        else if position >= localDeckCount { pos = "bottom" }
        else                        { pos = "random" }
        network.sendAction(["action": "defusePlacement", "position": pos])
        pendingBombId = nil
    }
}
