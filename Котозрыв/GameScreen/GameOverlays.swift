import UIKit


extension GameScreenView {

    // MARK: - общий каркас оверлея
    @discardableResult
    func presentGameOverlay(panelWidth: CGFloat = 320,
                            tint: UIColor = Theme.Palette.yellow,
                            build: (_ panel: UIView, _ dismiss: @escaping () -> Void) -> Void)
        -> UIView {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let panel = UIView()
        panel.backgroundColor = Theme.Palette.ink
        panel.layer.cornerRadius = 22
        panel.layer.borderColor  = tint.cgColor
        panel.layer.borderWidth  = 2
        panel.layer.shadowColor  = UIColor.black.cgColor
        panel.layer.shadowOpacity = 0.6
        panel.layer.shadowRadius  = 16
        panel.layer.shadowOffset  = CGSize(width: 0, height: 8)
        panel.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(panel)

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: panelWidth),
            panel.topAnchor.constraint(greaterThanOrEqualTo: overlay.safeAreaLayoutGuide.topAnchor, constant: 24),
            panel.bottomAnchor.constraint(lessThanOrEqualTo: overlay.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])

        let dismiss = { [weak overlay] in
            UIView.animate(withDuration: 0.18, animations: { overlay?.alpha = 0 },
                           completion: { _ in overlay?.removeFromSuperview() })
        }
        build(panel, dismiss)

        overlay.alpha = 0
        UIView.animate(withDuration: 0.2) { overlay.alpha = 1 }
        return overlay
    }

    // MARK: - Взрыв игрока (кастомное оповещение)

    func showExplosionOverlay(playerName: String, duration: TimeInterval = 1.8) {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Красная вспышка
        let glow = UIView()
        glow.translatesAutoresizingMaskIntoConstraints = false
        glow.isUserInteractionEnabled = false
        overlay.addSubview(glow)
        NSLayoutConstraint.activate([
            glow.topAnchor.constraint(equalTo: overlay.topAnchor),
            glow.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),
            glow.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
            glow.trailingAnchor.constraint(equalTo: overlay.trailingAnchor)
        ])
        DispatchQueue.main.async { [weak glow] in
            guard let glow = glow else { return }
            let l = CAGradientLayer()
            l.frame = glow.bounds
            l.type = .radial
            l.colors = [Theme.Palette.red.withAlphaComponent(0.65).cgColor,
                        UIColor.black.withAlphaComponent(0.85).cgColor]
            l.locations = [0.0, 0.85]
            l.startPoint = CGPoint(x: 0.5, y: 0.4)
            l.endPoint   = CGPoint(x: 1.0, y: 1.0)
            glow.layer.addSublayer(l)
        }

        // Карта взрывного котёнка
        let cardView = UIImageView()
        cardView.contentMode = .scaleAspectFill
        cardView.clipsToBounds = true
        cardView.layer.cornerRadius = 14
        cardView.layer.borderColor = Theme.Palette.yellow.cgColor
        cardView.layer.borderWidth = 3
        cardView.layer.shadowColor = Theme.Palette.red.cgColor
        cardView.layer.shadowOpacity = 0.9
        cardView.layer.shadowRadius = 18
        cardView.layer.shadowOffset = .zero
        for n in CardType.explodingKitten.assetCatalogImageNames {
            if let img = UIImage(named: n) { cardView.image = img; break }
        }
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let title = Theme.makeTitleLabel("БУМ!", size: 56)
        title.textColor = Theme.Palette.yellow

        let nameLabel = UILabel()
        nameLabel.attributedText = NSAttributedString(
            string: "\(playerName.uppercased()) ВЗОРВАЛСЯ",
            attributes: [.font: Theme.notable(14), .foregroundColor: Theme.Palette.pink, .kern: 3])
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [cardView, title, nameLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(stack)
        NSLayoutConstraint.activate([
            cardView.widthAnchor.constraint(equalToConstant: 140),
            cardView.heightAnchor.constraint(equalToConstant: 184),
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])

        // Анимация появления + тряска карты
        overlay.alpha = 0
        UIView.animate(withDuration: 0.18) {
            overlay.alpha = 1
            overlay.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        }

        let shake = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        shake.values = [-0.06, 0.06, -0.05, 0.05, -0.03, 0.03, 0]
        shake.keyTimes = [0, 0.15, 0.3, 0.45, 0.6, 0.8, 1]
        shake.duration = 0.6
        shake.repeatCount = 2
        cardView.layer.add(shake, forKey: "shake")


        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak overlay] in
            UIView.animate(withDuration: 0.25, animations: {
                overlay?.alpha = 0
            }, completion: { _ in
                overlay?.removeFromSuperview()
            })
        }
    }

    // MARK: - Подсмотри грядущее

    func showSeeTheFutureCardsCustom(_ cards: [Card]) {
        presentGameOverlay(panelWidth: 340) { panel, dismiss in
            let title = Theme.makeTitleLabel("ГРЯДУЩЕЕ", size: 26)
            let subtitle = Theme.makeAccentLabel("ТРИ ВЕРХНИЕ КАРТЫ КОЛОДЫ", size: 10)
            subtitle.numberOfLines = 0
            subtitle.textAlignment = .center

            let cardsRow = UIStackView()
            cardsRow.axis = .horizontal
            cardsRow.alignment = .top
            cardsRow.distribution = .fillEqually
            cardsRow.spacing = 10
            cardsRow.translatesAutoresizingMaskIntoConstraints = false

      
            var padded = cards
            while padded.count < 3 { padded.append(Card(type: .nope)) }
            for (i, card) in padded.prefix(3).enumerated() {
                cardsRow.addArrangedSubview(makeFutureColumn(index: i, card: i < cards.count ? card : nil))
            }

            let warning = UILabel()
            if cards.contains(where: { $0.type == .explodingKitten }) {
                warning.numberOfLines = 0
                warning.textAlignment = .center
                warning.font = Theme.mono(10)
                warning.textColor = Theme.Palette.pink
                warning.text = "⚠️ ВПЕРЕДИ ВЗРЫВНОЙ КОТЁНОК. ИГРАЙ «СЛИНЯЙ» ИЛИ «ЗАТАСУЙ»!"
                warning.layer.borderColor = Theme.Palette.pink.cgColor
                warning.layer.borderWidth = 1.5
                warning.layer.cornerRadius = 12
                warning.backgroundColor = Theme.Palette.red.withAlphaComponent(0.35)
                warning.layer.masksToBounds = true
            }

            let okButton = Theme.makePrimaryButton(title: "ПОНЯТНО", width: 200)
            okButton.addAction(UIAction { _ in dismiss() }, for: .touchUpInside)

            let stack = UIStackView()
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 14
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(title)
            stack.addArrangedSubview(subtitle)
            stack.addArrangedSubview(cardsRow)
            if warning.text != nil {
                let pad = UIView()
                pad.translatesAutoresizingMaskIntoConstraints = false
                pad.addSubview(warning)
                warning.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    warning.topAnchor.constraint(equalTo: pad.topAnchor, constant: 6),
                    warning.bottomAnchor.constraint(equalTo: pad.bottomAnchor, constant: -6),
                    warning.leadingAnchor.constraint(equalTo: pad.leadingAnchor, constant: 12),
                    warning.trailingAnchor.constraint(equalTo: pad.trailingAnchor, constant: -12)
                ])
                stack.addArrangedSubview(pad)
            }
            stack.addArrangedSubview(okButton)
            panel.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 24),
                stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -24),
                stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
                stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
                cardsRow.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
                cardsRow.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
            ])
        }
    }

    private func makeFutureColumn(index: Int, card: Card?) -> UIView {
        let column = UIStackView()
        column.axis = .vertical
        column.alignment = .center
        column.spacing = 6

        let topLabel = UILabel()
        topLabel.attributedText = NSAttributedString(
            string: index == 0 ? "СЛЕДУЮЩАЯ" : (index == 1 ? "2-Я" : "3-Я"),
            attributes: [.font: Theme.notable(9),
                         .foregroundColor: index == 0 ? Theme.Palette.yellow : UIColor.white.withAlphaComponent(0.6),
                         .kern: 2])

        let cardView = UIView()
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = 8
        cardView.clipsToBounds = true
        cardView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        cardView.widthAnchor.constraint(equalToConstant: 76).isActive = true
        cardView.heightAnchor.constraint(equalToConstant: 100).isActive = true

        if let card = card {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.translatesAutoresizingMaskIntoConstraints = false
            for n in card.type.assetCatalogImageNames {
                if let img = UIImage(named: n) { iv.image = img; break }
            }
            cardView.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.topAnchor.constraint(equalTo: cardView.topAnchor),
                iv.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
                iv.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: cardView.trailingAnchor)
            ])
            if index == 0 {
                cardView.layer.borderColor = Theme.Palette.yellow.cgColor
                cardView.layer.borderWidth = 2
                cardView.layer.shadowColor = Theme.Palette.yellow.cgColor
                cardView.layer.shadowOpacity = 0.6
                cardView.layer.shadowRadius = 8
                cardView.layer.masksToBounds = false
            }
        }

        let nameLabel = UILabel()
        nameLabel.font = Theme.mono(9)
        nameLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        nameLabel.text = (card?.type.displayName.uppercased()) ?? "—"
        nameLabel.numberOfLines = 0
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        column.addArrangedSubview(topLabel)
        column.addArrangedSubview(cardView)
        column.addArrangedSubview(nameLabel)
        return column
    }

    // MARK: - Выбор игрока (Подлижись/комбо)

    func promptSelectPlayerCustom(players: [Player], completion: @escaping (Player) -> Void) {
        presentGameOverlay(panelWidth: 320) { panel, dismiss in
            let title = Theme.makeTitleLabel("ВЫБЕРИ ИГРОКА", size: 22)
            let subtitle = Theme.makeAccentLabel("У КОГО ЗАБРАТЬ КАРТУ", size: 10)

            let grid = UIStackView()
            grid.axis = .vertical
            grid.spacing = 8
            grid.translatesAutoresizingMaskIntoConstraints = false
            for p in players {
                grid.addArrangedSubview(self.makePlayerRow(player: p) { picked in
                    dismiss()
                    completion(picked)
                })
            }

            let cancel = UIButton(type: .custom)
            cancel.setAttributedTitle(NSAttributedString(string: "ОТМЕНА",
                attributes: [.font: Theme.notable(11), .foregroundColor: Theme.Palette.pink, .kern: 2]),
                for: .normal)
            cancel.addAction(UIAction { _ in dismiss() }, for: .touchUpInside)

            let stack = UIStackView(arrangedSubviews: [title, subtitle, grid, cancel])
            stack.axis = .vertical
            stack.spacing = 12
            stack.alignment = .fill
            stack.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 22),
                stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
                stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
                stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18)
            ])
        }
    }

    private func makePlayerRow(player: Player, onTap: @escaping (Player) -> Void) -> UIView {
        let row = UIControl()
        row.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        row.layer.cornerRadius = 14
        row.layer.borderColor  = Theme.Palette.yellow.withAlphaComponent(0.4).cgColor
        row.layer.borderWidth  = 1
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let avatar = UILabel()
        avatar.text = "🐱"
        avatar.font = .systemFont(ofSize: 24)
        avatar.backgroundColor = Theme.Palette.yellow
        avatar.textAlignment = .center
        avatar.layer.cornerRadius = 18
        avatar.layer.masksToBounds = true
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.widthAnchor.constraint(equalToConstant: 36).isActive = true
        avatar.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let nameLabel = UILabel()
        nameLabel.attributedText = NSAttributedString(string: player.name.uppercased(),
            attributes: [.font: Theme.notable(13), .foregroundColor: Theme.Palette.yellow, .kern: 1])

        let countLabel = UILabel()
        countLabel.font = Theme.mono(10)
        countLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        countLabel.text = "КАРТ В РУКЕ: \(player.hand.count)"

        let textStack = UIStackView(arrangedSubviews: [nameLabel, countLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = Theme.Palette.yellow.withAlphaComponent(0.7)
        chevron.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(avatar)
        row.addSubview(textStack)
        row.addSubview(chevron)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            avatar.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        row.addAction(UIAction { _ in onTap(player) }, for: .touchUpInside)
        return row
    }

    // MARK: - Размещение взрывного котёнка после Обезвредь
    func showDefusePlacementOverlay(deckCount: Int,
                                    completion: @escaping (_ position: Int) -> Void) {
        presentGameOverlay(panelWidth: 320, tint: Theme.Palette.pink) { panel, dismiss in
            let title = Theme.makeTitleLabel("ОБЕЗВРЕЖЕНО!", size: 24)
            title.textColor = Theme.Palette.pink
            title.textAlignment = .center

            let subtitle = Theme.makeAccentLabel("КУДА ВЕРНУТЬ КОТЁНКА?", size: 11)
            subtitle.textAlignment = .center
            subtitle.numberOfLines = 0

   
            let bombCard = UIImageView()
            bombCard.contentMode = .scaleAspectFill
            bombCard.clipsToBounds = true
            bombCard.layer.cornerRadius = 12
            bombCard.layer.borderColor = Theme.Palette.pink.cgColor
            bombCard.layer.borderWidth = 2
            for name in CardType.explodingKitten.assetCatalogImageNames {
                if let img = UIImage(named: name) { bombCard.image = img; break }
            }
            if bombCard.image == nil {
                bombCard.backgroundColor = Theme.Palette.pink.withAlphaComponent(0.3)
            }
            bombCard.translatesAutoresizingMaskIntoConstraints = false
            bombCard.widthAnchor.constraint(equalToConstant: 110).isActive = true
            bombCard.heightAnchor.constraint(equalToConstant: 144).isActive = true


            let topBtn    = self.makeDefuseChoiceButton(
                title: "НА ВЕРХ КОЛОДЫ",
                subtitle: "следующий игрок вытащит",
                icon: "arrow.up"
            ) { dismiss(); completion(0) }

            let randomBtn = self.makeDefuseChoiceButton(
                title: "СЛУЧАЙНО",
                subtitle: "случайная позиция",
                icon: "shuffle"
            ) {
                dismiss()
                let pos = Int.random(in: 0..<max(1, deckCount))
                completion(pos)
            }

            let bottomBtn = self.makeDefuseChoiceButton(
                title: "ВНИЗ КОЛОДЫ",
                subtitle: "максимально далеко",
                icon: "arrow.down"
            ) { dismiss(); completion(max(deckCount, 0)) }

            let stack = UIStackView(arrangedSubviews: [
                title, subtitle, bombCard, topBtn, randomBtn, bottomBtn
            ])
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 12
            stack.setCustomSpacing(6, after: title)
            stack.setCustomSpacing(18, after: subtitle)
            stack.setCustomSpacing(20, after: bombCard)
            stack.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 24),
                stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -22),
                stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
                stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),

                topBtn.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
                topBtn.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
                randomBtn.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
                randomBtn.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
                bottomBtn.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
                bottomBtn.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            ])
        }
    }

    private func makeDefuseChoiceButton(title: String,
                                        subtitle: String,
                                        icon: String,
                                        action: @escaping () -> Void) -> UIControl {
        let btn = UIControl()
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        btn.layer.cornerRadius = 14
        btn.layer.borderColor = Theme.Palette.yellow.withAlphaComponent(0.5).cgColor
        btn.layer.borderWidth = 2
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let iconView = UIImageView(image: UIImage(systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)))
        iconView.tintColor = Theme.Palette.yellow
        iconView.backgroundColor = Theme.Palette.black
        iconView.contentMode = .center
        iconView.layer.cornerRadius = 18
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 36).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let titleLabel = UILabel()
        titleLabel.attributedText = NSAttributedString(string: title,
            attributes: [.font: Theme.notable(13), .foregroundColor: Theme.Palette.yellow, .kern: 1])

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = Theme.mono(9)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.6)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(iconView)
        btn.addSubview(textStack)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: btn.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -14),
            textStack.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
        ])

        btn.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return btn
    }

    // MARK: - Выбор типа карты (трио комбо)

    func promptSelectCardTypeCustom(completion: @escaping (CardType?) -> Void) {
        let types: [CardType] = [
            .attack, .skip, .favor, .shuffle, .seeTheFuture, .nope, .defuse,
            .catBeard, .catTaco, .catWatermelon, .catPotato
        ]
        presentGameOverlay(panelWidth: 340) { panel, dismiss in
            let title = Theme.makeTitleLabel("НАЗОВИ КАРТУ", size: 22)
            let subtitle = Theme.makeAccentLabel("ЕСЛИ У СОПЕРНИКА ЕСТЬ — ОНА ТВОЯ", size: 10)
            subtitle.numberOfLines = 0
            subtitle.textAlignment = .center

            let grid = self.makeCardTypeGrid(types: types) { type in
                dismiss()
                completion(type)
            }

            let cancel = UIButton(type: .custom)
            cancel.setAttributedTitle(NSAttributedString(string: "ОТМЕНА",
                attributes: [.font: Theme.notable(11), .foregroundColor: Theme.Palette.pink, .kern: 2]),
                for: .normal)
            cancel.addAction(UIAction { _ in dismiss(); completion(nil) }, for: .touchUpInside)

            let stack = UIStackView(arrangedSubviews: [title, subtitle, grid, cancel])
            stack.axis = .vertical
            stack.spacing = 12
            stack.alignment = .fill
            stack.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 22),
                stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
                stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
                stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14)
            ])
        }
    }

    private func makeCardTypeGrid(types: [CardType], onPick: @escaping (CardType) -> Void) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        let perRow = 3
        var i = 0
        while i < types.count {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.distribution = .fillEqually
            for j in 0..<perRow {
                if i + j < types.count {
                    row.addArrangedSubview(makeCardTypeCell(type: types[i + j], onPick: onPick))
                } else {
                    let pad = UIView()
                    pad.translatesAutoresizingMaskIntoConstraints = false
                    row.addArrangedSubview(pad)
                }
            }
            container.addArrangedSubview(row)
            i += perRow
        }
        return container
    }

    private func makeCardTypeCell(type: CardType, onPick: @escaping (CardType) -> Void) -> UIView {
        let cell = UIControl()
        cell.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        cell.layer.cornerRadius = 12
        cell.layer.borderColor  = Theme.Palette.yellow.withAlphaComponent(0.3).cgColor
        cell.layer.borderWidth  = 2
        cell.translatesAutoresizingMaskIntoConstraints = false

        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.translatesAutoresizingMaskIntoConstraints = false
        for n in type.assetCatalogImageNames {
            if let img = UIImage(named: n) { iv.image = img; break }
        }

        let label = UILabel()
        label.attributedText = NSAttributedString(string: type.displayName.uppercased(),
            attributes: [.font: Theme.notable(8.5), .foregroundColor: Theme.Palette.yellow, .kern: 0.5])
        label.numberOfLines = 2
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(iv)
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            iv.topAnchor.constraint(equalTo: cell.topAnchor, constant: 8),
            iv.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            iv.widthAnchor.constraint(equalToConstant: 60),
            iv.heightAnchor.constraint(equalToConstant: 80),

            label.topAnchor.constraint(equalTo: iv.bottomAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            label.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -8)
        ])

        cell.addAction(UIAction { _ in onPick(type) }, for: .touchUpInside)
        return cell
    }

    // MARK: - Выбор типа карты у конкретного соперника (для трио)

    func promptSelectCardCustom(from player: Player, completion: @escaping (CardType?) -> Void) {
        let unique = Array(Set(player.hand.map { $0.type }))
        presentGameOverlay(panelWidth: 340) { panel, dismiss in
            let title = Theme.makeTitleLabel("ВЫБОР КАРТЫ", size: 22)
            let subtitle = Theme.makeAccentLabel("ВЫБЕРИТЕ КАРТУ У \(player.name.uppercased())", size: 10)
            subtitle.numberOfLines = 0
            subtitle.textAlignment = .center

            let grid = self.makeCardTypeGrid(types: unique) { t in
                dismiss(); completion(t)
            }

            let cancel = UIButton(type: .custom)
            cancel.setAttributedTitle(NSAttributedString(string: "ОТМЕНА",
                attributes: [.font: Theme.notable(11), .foregroundColor: Theme.Palette.pink, .kern: 2]),
                for: .normal)
            cancel.addAction(UIAction { _ in dismiss(); completion(nil) }, for: .touchUpInside)

            let stack = UIStackView(arrangedSubviews: [title, subtitle, grid, cancel])
            stack.axis = .vertical
            stack.spacing = 12
            stack.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 22),
                stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
                stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
                stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14)
            ])
        }
    }

    // MARK: - Запрос карты 

    func promptComboRequestCustom(requesterName: String, cards: [Card], completion: @escaping (Card?) -> Void) {
        presentGameOverlay(panelWidth: 340) { panel, dismiss in
            let title = Theme.makeTitleLabel("ОТДАЙ КАРТУ", size: 22)
            let subtitle = Theme.makeAccentLabel("\(requesterName.uppercased()) ХОЧЕТ КАРТУ — ВЫБЕРИ КАКУЮ", size: 10)
            subtitle.numberOfLines = 0
            subtitle.textAlignment = .center

            let grid = UIStackView()
            grid.axis = .vertical
            grid.spacing = 8
            grid.translatesAutoresizingMaskIntoConstraints = false

            let perRow = 3
            var i = 0
            while i < cards.count {
                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = 8
                row.distribution = .fillEqually
                for j in 0..<perRow {
                    if i + j < cards.count {
                        let card = cards[i + j]
                        row.addArrangedSubview(self.makeCardTypeCell(type: card.type) { _ in
                            dismiss(); completion(card)
                        })
                    } else {
                        let pad = UIView()
                        pad.translatesAutoresizingMaskIntoConstraints = false
                        row.addArrangedSubview(pad)
                    }
                }
                grid.addArrangedSubview(row)
                i += perRow
            }

            let cancel = UIButton(type: .custom)
            cancel.setAttributedTitle(NSAttributedString(string: "ОТМЕНА",
                attributes: [.font: Theme.notable(11), .foregroundColor: Theme.Palette.pink, .kern: 2]),
                for: .normal)
            cancel.addAction(UIAction { _ in dismiss(); completion(nil) }, for: .touchUpInside)

            let stack = UIStackView(arrangedSubviews: [title, subtitle, grid, cancel])
            stack.axis = .vertical
            stack.spacing = 12
            stack.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 22),
                stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
                stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
                stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14)
            ])
        }
    }
}
