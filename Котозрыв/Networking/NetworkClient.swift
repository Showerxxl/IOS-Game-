import Foundation

// MARK: - Response models

struct RoomResponse: Decodable {
    let room_id: String
    let status: String
    let max_players: Int
    let player_count: Int
    let players: [RoomPlayerInfo]
}

struct RoomPlayerInfo: Decodable {
    let player_id: String
    let name: String
}

struct JoinResponse: Decodable {
    let player_id: String
    let room: RoomResponse
}

enum NetworkError: Error {
    case invalidResponse
    case serverError(String)
}

// MARK: - NetworkClient

final class NetworkClient {

    static let shared = NetworkClient()
    private init() {}

    var baseURL    = "http://127.0.0.1:8080"
    var wsBaseURL  = "ws://127.0.0.1:8080"

    private var wsTask: URLSessionWebSocketTask?
    var onEvent: ((String, [String: Any]) -> Void)?

    // MARK: - HTTP helpers

    private func post(_ path: String, body: [String: Any]?,
                      completion: @escaping (Data?, Error?) -> Void) {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        URLSession.shared.dataTask(with: req) { d, _, e in completion(d, e) }.resume()
    }

    private func get(_ path: String, completion: @escaping (Data?, Error?) -> Void) {
        let req = URLRequest(url: URL(string: baseURL + path)!)
        URLSession.shared.dataTask(with: req) { d, _, e in completion(d, e) }.resume()
    }

    // MARK: - Room API

    func createRoom(maxPlayers: Int = 5,
                    completion: @escaping (Result<RoomResponse, Error>) -> Void) {
        post("/rooms", body: ["max_players": maxPlayers]) { data, error in
            self.decode(data: data, error: error, completion: completion)
        }
    }

    func joinRoom(roomId: String, name: String,
                  completion: @escaping (Result<JoinResponse, Error>) -> Void) {
        post("/rooms/\(roomId)/join", body: ["name": name]) { data, error in
            self.decode(data: data, error: error, completion: completion)
        }
    }

    func startGame(roomId: String, playerId: String,
                   completion: @escaping (Result<Void, Error>) -> Void) {
        post("/rooms/\(roomId)/start", body: ["player_id": playerId]) { _, error in
            DispatchQueue.main.async {
                if let error = error { completion(.failure(error)) }
                else { completion(.success(())) }
            }
        }
    }

    func getRoomInfo(roomId: String,
                     completion: @escaping (Result<RoomResponse, Error>) -> Void) {
        get("/rooms/\(roomId)") { data, error in
            self.decode(data: data, error: error, completion: completion)
        }
    }

    // MARK: - WebSocket

    func connectWebSocket(playerId: String, roomId: String) {
        wsTask?.cancel(with: .normalClosure, reason: nil)
        let url = URL(string: "\(wsBaseURL)/ws?player_id=\(playerId)&room_id=\(roomId)")!
        wsTask = URLSession.shared.webSocketTask(with: url)
        wsTask?.resume()
        listenLoop()
    }

    func sendAction(_ action: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: action),
              let str  = String(data: data, encoding: .utf8) else { return }
        wsTask?.send(.string(str)) { _ in }
    }

    func disconnect() {
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
        onEvent = nil
    }

    // MARK: - Private

    private func listenLoop() {
        wsTask?.receive { [weak self] result in
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self?.parseMessage(text) }
                self?.listenLoop()
            case .failure:
                break
            }
        }
    }

    private func parseMessage(_ text: String) {
        guard
            let data  = text.data(using: .utf8),
            let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let event = json["event"] as? String
        else { return }
        let eventData = json["data"] as? [String: Any] ?? [:]
        DispatchQueue.main.async { self.onEvent?(event, eventData) }
    }

    private func decode<T: Decodable>(data: Data?, error: Error?,
                                       completion: @escaping (Result<T, Error>) -> Void) {
        DispatchQueue.main.async {
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NetworkError.invalidResponse)); return
            }
            if let result = try? JSONDecoder().decode(T.self, from: data) {
                completion(.success(result))
            } else {
                let msg = String(data: data, encoding: .utf8) ?? "Неизвестная ошибка"
                completion(.failure(NetworkError.serverError(msg)))
            }
        }
    }
}
