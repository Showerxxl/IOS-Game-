import Foundation

struct Card: Equatable, Identifiable {
    let id: UUID
    let serverID: String
    let type: CardType

    init(type: CardType) {
        let uuid = UUID()
        self.id = uuid
        self.serverID = uuid.uuidString
        self.type = type
    }

    init(serverID: String, type: CardType) {
        self.serverID = serverID
        self.id = UUID(uuidString: serverID) ?? UUID()
        self.type = type
    }

    static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.id == rhs.id
    }
}
