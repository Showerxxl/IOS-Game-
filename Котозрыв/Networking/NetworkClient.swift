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

    // MARK: - Server endpoint
    //
    // Варианты подключения (выбери ОДИН блок и раскомментируй):
    //
    // 1) Локальная сеть (LAN) — оба устройства в одной Wi-Fi:
    //    static let serverHost = "192.168.2.61"
    //    static let serverPort = 8080
    //    static let useTLS     = false
    //
    // 2) ngrok-туннель (играть с любых сетей через интернет):
    //    Подставь URL из вывода `ngrok http 8080`, БЕЗ "https://" и без слэша.
    //    Пример: "abcd-1234.ngrok-free.app"
    static let serverHost = "abcd-1234.ngrok-free.app"   // ← замени на свой ngrok-URL
    static let serverPort = 443
    static let useTLS     = true

    var baseURL: String   = {
        let scheme = NetworkClient.useTLS ? "https" : "http"
        if NetworkClient.useTLS && NetworkClient.serverPort == 443 {
            return "\(scheme)://\(NetworkClient.serverHost)"
        }
        return "\(scheme)://\(NetworkClient.serverHost):\(NetworkClient.serverPort)"
    }()
    var wsBaseURL: String = {
        let scheme = NetworkClient.useTLS ? "wss" : "ws"
        if NetworkClient.useTLS && NetworkClient.serverPort == 443 {
            return "\(scheme)://\(NetworkClient.serverHost)"
        }
        return "\(scheme)://\(NetworkClient.serverHost):\(NetworkClient.serverPort)"
    }()

    private var wsTask: URLSessionWebSocketTask?
    var onEvent: ((String, [String: Any]) -> Void)?

    // 10-секундный таймаут, чтобы кнопки не «висели» при отсутствии сети.
    private lazy var httpSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 10
        cfg.timeoutIntervalForResource = 15
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()

    // MARK: - HTTP helpers

    private func post(_ path: String, body: [String: Any]?,
                      completion: @escaping (Data?, Error?) -> Void) {
        let url = URL(string: baseURL + path)!
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        print("[NET] POST \(url.absoluteString) body=\(body ?? [:])")
        httpSession.dataTask(with: req) { d, resp, e in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if let e = e {
                print("[NET] POST \(path) error: \(e.localizedDescription)")
            } else {
                let preview = d.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
                print("[NET] POST \(path) status=\(status) body=\(preview.prefix(200))")
            }
            completion(d, e)
        }.resume()
    }

    private func get(_ path: String, completion: @escaping (Data?, Error?) -> Void) {
        let url = URL(string: baseURL + path)!
        let req = URLRequest(url: url, timeoutInterval: 10)
        httpSession.dataTask(with: req) { d, _, e in completion(d, e) }.resume()
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
