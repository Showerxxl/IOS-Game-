import UIKit

final class RulesView: UIViewController {

    private let backButton    = Theme.makeCircleIconButton(systemName: "chevron.left")
    private let titleLabel    = Theme.makeTitleLabel("ПРАВИЛА", size: 32)
    private let subtitleLabel = Theme.makeAccentLabel("КАК ИГРАТЬ В КОТОЗРЫВ", size: 10)

    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.showsVerticalScrollIndicator = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 12
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        addSections()
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Theme.styleNavigationController(self)
    }

    @objc private func backTapped() { dismiss(animated: true) }

    private func setupUI() {
        Theme.installBackground(on: view)

        let header = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        header.axis = .vertical
        header.alignment = .center
        header.spacing = 4
        header.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(backButton)
        view.addSubview(header)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 70),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 22),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }


    private func addSections() {
        contentStack.addArrangedSubview(makeSection(num: "01", title: "ЦЕЛЬ ИГРЫ", text: """
        Не взорваться. Последний выживший кот побеждает. Все остальные — стали фейерверком.
        """))

        contentStack.addArrangedSubview(makeSection(num: "02", title: "ПОДГОТОВКА", text: """
        • Каждому игроку — 1 «Обезвредь» и 7 случайных карт.
        • В колоду добавляются «Взрывные котята»: на 1 меньше, чем игроков.
        • Оставшиеся «Обезвреди» тоже идут в колоду.
        • Колода тасуется. Партия начинается.
        """))

        contentStack.addArrangedSubview(makeSection(num: "03", title: "ХОД ИГРОКА", text: """
        В свой ход можно сыграть любое количество карт (или ни одной), а потом взять карту из колоды, чтобы завершить ход.

        Если вытянул «Взрывного котёнка» — нужна «Обезвредь», иначе ты выбываешь.
        """))

        contentStack.addArrangedSubview(makeSection(num: "04", title: "ВЗРЫВНОЙ КОТЁНОК", text: """
        Появляется в колоде. Если ты его вытянул:
        • Есть «Обезвредь» — играешь её и тайно возвращаешь котёнка в любое место колоды.
        • Нет «Обезвреди» — ты выбываешь, твои карты уходят в сброс.
        """))

        contentStack.addArrangedSubview(makeCardsSection())

        contentStack.addArrangedSubview(makeSection(num: "06", title: "КОМБИНАЦИИ", text: """
        • 2 одинаковые карты — соперник сам выбирает, какую отдать тебе.
        • 3 одинаковые карты — назови тип карты и забери её, если она есть.
        • Любые карты, кроме «Взрывного котёнка» и «Обезвреди», подходят для комбо.
        """))

        contentStack.addArrangedSubview(makeSection(num: "07", title: "ПОБЕДА", text: """
        Когда остаётся один живой кот — он чемпион Кото-сонаты. Партия закончена, можно начинать новую.
        """))

        let footer = Theme.makeMonoLabel("ИГРА СОЗДАНА ПО МОТИВАМ EXPLODING KITTENS.",
                                         size: 9, color: UIColor.white.withAlphaComponent(0.4))
        footer.numberOfLines = 0
        footer.textAlignment = .center
        contentStack.addArrangedSubview(footer)
    }

    private func makeSection(num: String, title: String, text: String) -> UIView {
        let panel = UIView()
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        panel.layer.cornerRadius = 16
        panel.layer.borderColor  = Theme.Palette.yellow.withAlphaComponent(0.35).cgColor
        panel.layer.borderWidth  = 1
        panel.translatesAutoresizingMaskIntoConstraints = false

        let numL = UILabel()
        numL.attributedText = NSAttributedString(string: num,
            attributes: [.font: Theme.notable(11), .foregroundColor: Theme.Palette.pink, .kern: 2])

        let titleL = UILabel()
        titleL.attributedText = NSAttributedString(string: title,
            attributes: [.font: Theme.notable(14), .foregroundColor: Theme.Palette.yellow, .kern: 1])

        let header = UIStackView(arrangedSubviews: [numL, titleL])
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .firstBaseline

        let body = UILabel()
        body.font = Theme.mono(11)
        body.textColor = UIColor.white.withAlphaComponent(0.85)
        body.numberOfLines = 0
        body.text = text

        let stack = UIStackView(arrangedSubviews: [header, body])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16)
        ])
        return panel
    }

    private func makeCardsSection() -> UIView {
        let panel = UIView()
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        panel.layer.cornerRadius = 16
        panel.layer.borderColor  = Theme.Palette.yellow.withAlphaComponent(0.35).cgColor
        panel.layer.borderWidth  = 1
        panel.translatesAutoresizingMaskIntoConstraints = false

        let numL = UILabel()
        numL.attributedText = NSAttributedString(string: "05",
            attributes: [.font: Theme.notable(11), .foregroundColor: Theme.Palette.pink, .kern: 2])
        let titleL = UILabel()
        titleL.attributedText = NSAttributedString(string: "КАРТЫ",
            attributes: [.font: Theme.notable(14), .foregroundColor: Theme.Palette.yellow, .kern: 1])
        let header = UIStackView(arrangedSubviews: [numL, titleL])
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .firstBaseline

        let entries: [(CardType, String)] = [
            (.defuse,         "Спасает от Взрывного котёнка. Верни котёнка тайно в колоду."),
            (.explodingKitten,"Не сыграть. Тянется из колоды — без «Обезвреди» ты выбываешь."),
            (.attack,         "Заверши ход без добора. Следующий игрок ходит за двоих."),
            (.skip,           "Пропусти свой ход — никаких карт брать не надо."),
            (.favor,          "Сопернник сам выбирает, какую карту отдать тебе."),
            (.shuffle,        "Перетасуй колоду — пусть котёнок окажется где-то ещё."),
            (.seeTheFuture,   "Посмотри 3 верхние карты колоды, никому не показывая."),
            (.nope,           "Отмени любое действие другого игрока в течение 5 секунд."),
            (.catBeard,       "Сама по себе ничего не делает, но можно играть в комбинациях."),
            (.catTaco,        "Сама по себе ничего не делает, но можно играть в комбинациях."),
            (.catWatermelon,  "Сама по себе ничего не делает, но можно играть в комбинациях."),
            (.catPotato,      "Сама по себе ничего не делает, но можно играть в комбинациях."),
        ]

        let rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = 0
        for entry in entries {
            rowsStack.addArrangedSubview(makeCardRow(type: entry.0, text: entry.1))
        }

        let stack = UIStackView(arrangedSubviews: [header, rowsStack])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16)
        ])
        return panel
    }

    private func makeCardRow(type: CardType, text: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let cardImage = UIImageView()
        cardImage.contentMode = .scaleAspectFill
        cardImage.clipsToBounds = true
        cardImage.layer.cornerRadius = 6
        for n in type.assetCatalogImageNames {
            if let img = UIImage(named: n) { cardImage.image = img; break }
        }
        cardImage.translatesAutoresizingMaskIntoConstraints = false

        let nameL = UILabel()
        nameL.attributedText = NSAttributedString(string: type.displayName.uppercased(),
            attributes: [.font: Theme.notable(12), .foregroundColor: Theme.Palette.yellow, .kern: 1])

        let descL = UILabel()
        descL.font = Theme.mono(10)
        descL.textColor = UIColor.white.withAlphaComponent(0.75)
        descL.numberOfLines = 0
        descL.text = text

        let textStack = UIStackView(arrangedSubviews: [nameL, descL])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let separator = UIView()
        separator.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        separator.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(cardImage)
        row.addSubview(textStack)
        row.addSubview(separator)
        NSLayoutConstraint.activate([
            cardImage.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            cardImage.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            cardImage.widthAnchor.constraint(equalToConstant: 48),
            cardImage.heightAnchor.constraint(equalToConstant: 64),

            textStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            textStack.leadingAnchor.constraint(equalTo: cardImage.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -10),

            separator.heightAnchor.constraint(equalToConstant: 1),
            separator.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 84)
        ])
        return row
    }
}
