import UIKit

final class JoinRoomView: UIViewController {

    private let backButton = Theme.makeCircleIconButton(systemName: "chevron.left")
    private let titleLabel = Theme.makeTitleLabel("ВВЕДИТЕ КОД", size: 36)
    private let subtitleLbl = Theme.makeAccentLabel("6 СИМВОЛОВ ОТ ХОЗЯИНА КОМНАТЫ", size: 10)

    private var codeFields: [UITextField] = []
    private let joinButton = Theme.makePrimaryButton(title: "ВОЙТИ В КОМНАТУ", width: 244)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindActions()
        updateJoinButton()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Theme.styleNavigationController(self)
    }

    private func setupUI() {
        Theme.installBackground(on: view)

        view.addSubview(backButton)

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLbl])
        titleStack.axis = .vertical
        titleStack.alignment = .center
        titleStack.spacing = 8
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleStack)

        let codeStack = UIStackView()
        codeStack.axis = .horizontal
        codeStack.spacing = 8
        codeStack.distribution = .fillEqually
        codeStack.translatesAutoresizingMaskIntoConstraints = false

        for i in 0..<6 {
            let f = makeDigitField(tag: i)
            codeFields.append(f)
            codeStack.addArrangedSubview(f)
        }
        view.addSubview(codeStack)

        let recentPanel = makeRecentPanel()
        view.addSubview(recentPanel)

        view.addSubview(joinButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            titleStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            codeStack.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 50),
            codeStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            codeStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            codeStack.heightAnchor.constraint(equalToConstant: 56),

            recentPanel.topAnchor.constraint(equalTo: codeStack.bottomAnchor, constant: 40),
            recentPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            recentPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            joinButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            joinButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func bindActions() {
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        joinButton.addTarget(self, action: #selector(joinTapped), for: .touchUpInside)
    }

    @objc private func backTapped() { navigationController?.popViewController(animated: true) }

    @objc private func joinTapped() {
        let code = codeFields.compactMap { $0.text }.joined().uppercased()
        guard code.count == 6 else { return }
        view.endEditing(true)

        askForName { [weak self] name in
            guard let self = self else { return }
            self.joinButton.isEnabled = false
            self.showLoading(true)
            print("[JOIN] Trying to join room \(code) as \(name)…")

            NetworkClient.shared.joinRoom(roomId: code, name: name) { [weak self] result in
                guard let self = self else { return }
                self.showLoading(false)
                self.joinButton.isEnabled = true
                switch result {
                case .failure(let e):
                    print("[JOIN] failed: \(e.localizedDescription)")
                    let msg = "\(e.localizedDescription)\n\nПроверьте:\n• сервер запущен и доступен по IP \(NetworkClient.serverHost):\(NetworkClient.serverPort)\n• оба устройства в одной Wi-Fi\n• код комнаты введён верно"
                    let alert = UIAlertController(title: "Не удалось войти", message: msg,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                case .success(let join):
                    print("[JOIN] success, player_id=\(join.player_id)")
                    NetworkClient.shared.connectWebSocket(
                        playerId: join.player_id, roomId: code)
                    let lobby = RoomLobbyView(roomId: code, myPlayerId: join.player_id, isHost: false)
                    self.navigationController?.pushViewController(lobby, animated: true)
                }
            }
        }
    }

    private func showLoading(_ show: Bool) {
        let tag = 7777
        if show {
            let overlay = UIView()
            overlay.tag = tag
            overlay.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            overlay.translatesAutoresizingMaskIntoConstraints = false
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = Theme.Palette.yellow
            spinner.startAnimating()
            spinner.translatesAutoresizingMaskIntoConstraints = false
            overlay.addSubview(spinner)
            view.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: view.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            ])
        } else {
            view.viewWithTag(tag)?.removeFromSuperview()
        }
    }

    private func askForName(completion: @escaping (String) -> Void) {
        let overlay = NameInputOverlay(onSubmit: { name in
            completion(name)
        })
        overlay.present(in: view)
    }

    private func makeDigitField(tag: Int) -> UITextField {
        let f = UITextField()
        f.tag = tag
        f.textAlignment = .center
        f.font = Theme.notable(26)
        f.textColor = Theme.Palette.yellow
        f.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        f.layer.cornerRadius = 12
        f.layer.borderColor = Theme.Palette.yellow.withAlphaComponent(0.4).cgColor
        f.layer.borderWidth = 2
        f.autocapitalizationType = .allCharacters
        f.autocorrectionType = .no
        f.returnKeyType = .done
        f.delegate = self
        f.addTarget(self, action: #selector(fieldChanged(_:)), for: .editingChanged)
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    @objc private func fieldChanged(_ field: UITextField) {
        if let text = field.text, text.count > 1 {
            field.text = String(text.last!).uppercased()
        }
        let hasText = !(field.text ?? "").isEmpty
        field.layer.borderColor = (hasText ? Theme.Palette.yellow : Theme.Palette.yellow.withAlphaComponent(0.4)).cgColor
        if hasText, field.tag < codeFields.count - 1 {
            codeFields[field.tag + 1].becomeFirstResponder()
        }
        updateJoinButton()
    }

    private func updateJoinButton() {
        let filled = codeFields.allSatisfy { !($0.text ?? "").isEmpty }
        joinButton.isEnabled = filled
        joinButton.alpha = filled ? 1.0 : 0.4
    }

    private func makeRecentPanel() -> UIView {
        let panel = UIView()
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        panel.layer.cornerRadius = 14
        panel.layer.borderColor = Theme.Palette.yellow.withAlphaComponent(0.3).cgColor
        panel.layer.borderWidth = 1
        panel.translatesAutoresizingMaskIntoConstraints = false

        let header = UILabel()
        header.attributedText = NSAttributedString(string: "НЕДАВНИЕ КОМНАТЫ",
            attributes: [.kern: 2, .font: Theme.notable(10), .foregroundColor: Theme.Palette.pink])
        header.translatesAutoresizingMaskIntoConstraints = false

        let row1 = makeRecentRow(code: "KOT9X2", host: "Дима", players: "3/5")
        let row2 = makeRecentRow(code: "MEOW77", host: "Аня",  players: "2/4")

        let stack = UIStackView(arrangedSubviews: [header, row1, row2])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14)
        ])
        return panel
    }

    private func makeRecentRow(code: String, host: String, players: String) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false

        let codeLabel = UILabel()
        codeLabel.attributedText = NSAttributedString(string: code,
            attributes: [.kern: 1.5, .font: Theme.notable(13), .foregroundColor: Theme.Palette.yellow])

        let metaLabel = UILabel()
        metaLabel.text = "\(host) · \(players)"
        metaLabel.font = Theme.mono(10)
        metaLabel.textColor = UIColor.white.withAlphaComponent(0.6)

        let row = UIStackView(arrangedSubviews: [codeLabel, UIView(), metaLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: v.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -6),
            row.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: v.trailingAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(recentTapped(_:)))
        v.addGestureRecognizer(tap)
        v.accessibilityLabel = code
        return v
    }

    @objc private func recentTapped(_ gr: UITapGestureRecognizer) {
        guard let code = gr.view?.accessibilityLabel else { return }
        for (i, ch) in code.enumerated() where i < codeFields.count {
            codeFields[i].text = String(ch)
        }
        updateJoinButton()
    }
}

extension JoinRoomView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty {
            textField.text = ""
            textField.layer.borderColor = Theme.Palette.yellow.withAlphaComponent(0.4).cgColor
            updateJoinButton()
            if textField.tag > 0 {
                codeFields[textField.tag - 1].becomeFirstResponder()
            }
            return false
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
