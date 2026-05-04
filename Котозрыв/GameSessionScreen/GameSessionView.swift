import UIKit

protocol GameSessionViewProtocol: AnyObject {
    var presenter: GameSessionPresenterProtocol? { get set }
    func updateAIPlayersCount(_ count: Int)
}

final class GameSessionView: UIViewController {

    var presenter: GameSessionPresenterProtocol?

    private var selectedAICount = 2
    private let minAI = 1
    private let maxAI = 5

    private let backButton  = Theme.makeCircleIconButton(systemName: "chevron.left")
    private let titleLabel  = Theme.makeTitleLabel("ЛОББИ", size: 44)
    private let subtitleLbl = Theme.makeAccentLabel("ОДИН ПРОТИВ ИИ")

    private let modePanel    = Theme.makePanel()
    private let modeKicker   = Theme.makeAccentLabel("РЕЖИМ")
    private let modeTitle    = Theme.makeBodyLabel("ОДИНОЧНАЯ", size: 22)
    private let modeSubtitle = Theme.makeMonoLabel("1 человек · до 5 ИИ-противников", size: 11)

    private let stepperPanel  = Theme.makePanel()
    private let stepperKicker = Theme.makeAccentLabel("ПРОТИВНИКИ ИИ")
    private let minusButton   = GameSessionView.makeStepperBtn(symbol: "−")
    private let plusButton    = GameSessionView.makeStepperBtn(symbol: "+")
    private let aiCountValue: UILabel = {
        let l = UILabel()
        l.font = Theme.notable(64)
        l.textColor = Theme.Palette.yellow
        l.textAlignment = .center
        l.text = "2"
        l.layer.shadowColor = UIColor.black.cgColor
        l.layer.shadowOpacity = 0.6
        l.layer.shadowOffset = CGSize(width: 0, height: 4)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var avatarDots: [UIView] = []
    private let bounds = Theme.makeMonoLabel("МИН 1 · МАКС 5", size: 10, color: UIColor.white.withAlphaComponent(0.55))

    private let startButton = Theme.makePrimaryButton(title: "Играть", width: 228)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindActions()
        updateValueLabel()
        presenter?.viewDidLoad()
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
        titleStack.spacing = 6
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleStack)

        view.addSubview(modePanel)
        let modeStack = UIStackView(arrangedSubviews: [modeKicker, modeTitle, modeSubtitle])
        modeStack.axis = .vertical
        modeStack.alignment = .leading
        modeStack.spacing = 6
        modeStack.translatesAutoresizingMaskIntoConstraints = false
        modePanel.addSubview(modeStack)
        modeKicker.textAlignment = .left

        view.addSubview(stepperPanel)

        let stepperRow = UIStackView(arrangedSubviews: [minusButton, aiCountValue, plusButton])
        stepperRow.axis = .horizontal
        stepperRow.alignment = .center
        stepperRow.distribution = .equalSpacing
        stepperRow.translatesAutoresizingMaskIntoConstraints = false

        let dotsRow = UIStackView()
        dotsRow.axis = .horizontal
        dotsRow.spacing = 8
        dotsRow.alignment = .center
        dotsRow.distribution = .equalCentering
        dotsRow.translatesAutoresizingMaskIntoConstraints = false
        for _ in 1...maxAI {
            let dot = makeAvatarDot()
            avatarDots.append(dot)
            dotsRow.addArrangedSubview(dot)
        }

        let stepperStack = UIStackView(arrangedSubviews: [stepperKicker, stepperRow, dotsRow, bounds])
        stepperStack.axis = .vertical
        stepperStack.spacing = 14
        stepperStack.alignment = .fill
        stepperStack.translatesAutoresizingMaskIntoConstraints = false
        stepperPanel.addSubview(stepperStack)
        stepperKicker.textAlignment = .left
        bounds.textAlignment = .center

        view.addSubview(startButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            titleStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            modePanel.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 36),
            modePanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            modePanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            modeStack.topAnchor.constraint(equalTo: modePanel.topAnchor, constant: 18),
            modeStack.leadingAnchor.constraint(equalTo: modePanel.leadingAnchor, constant: 22),
            modeStack.trailingAnchor.constraint(equalTo: modePanel.trailingAnchor, constant: -22),
            modeStack.bottomAnchor.constraint(equalTo: modePanel.bottomAnchor, constant: -18),

            stepperPanel.topAnchor.constraint(equalTo: modePanel.bottomAnchor, constant: 22),
            stepperPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stepperPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            stepperStack.topAnchor.constraint(equalTo: stepperPanel.topAnchor, constant: 18),
            stepperStack.leadingAnchor.constraint(equalTo: stepperPanel.leadingAnchor, constant: 22),
            stepperStack.trailingAnchor.constraint(equalTo: stepperPanel.trailingAnchor, constant: -22),
            stepperStack.bottomAnchor.constraint(equalTo: stepperPanel.bottomAnchor, constant: -18),

            aiCountValue.heightAnchor.constraint(equalToConstant: 70),

            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func bindActions() {
        backButton.addTarget(self,  action: #selector(backTapped),  for: .touchUpInside)
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        minusButton.addTarget(self, action: #selector(minusTapped), for: .touchUpInside)
        plusButton.addTarget(self,  action: #selector(plusTapped),  for: .touchUpInside)
    }

    @objc private func backTapped()  { presenter?.backButtonTapped() }
    @objc private func startTapped() { presenter?.startGameTapped(aiCount: selectedAICount) }
    @objc private func minusTapped() {
        guard selectedAICount > minAI else { return }
        selectedAICount -= 1
        updateValueLabel()
        presenter?.aiCountChanged(selectedAICount)
    }
    @objc private func plusTapped() {
        guard selectedAICount < maxAI else { return }
        selectedAICount += 1
        updateValueLabel()
        presenter?.aiCountChanged(selectedAICount)
    }

    private func updateValueLabel() {
        aiCountValue.text = "\(selectedAICount)"
        styleStepperBtn(minusButton, enabled: selectedAICount > minAI)
        styleStepperBtn(plusButton,  enabled: selectedAICount < maxAI)
        for (i, dot) in avatarDots.enumerated() {
            let on = (i + 1) <= selectedAICount
            dot.backgroundColor = on ? Theme.Palette.yellow : .clear
        }
    }

    private static func makeStepperBtn(symbol: String) -> UIButton {
        let b = UIButton(type: .custom)
        b.setTitle(symbol, for: .normal)
        b.titleLabel?.font = Theme.notable(22)
        b.setTitleColor(Theme.Palette.yellow, for: .normal)
        b.backgroundColor = .clear
        b.layer.cornerRadius = 24
        b.layer.borderColor = Theme.Palette.yellow.cgColor
        b.layer.borderWidth = 2
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 48).isActive = true
        b.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return b
    }

    private func styleStepperBtn(_ b: UIButton, enabled: Bool) {
        b.isEnabled = enabled
        b.layer.borderColor = enabled
            ? Theme.Palette.yellow.cgColor
            : Theme.Palette.yellow.withAlphaComponent(0.3).cgColor
    }

    private func makeAvatarDot() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.Palette.yellow
        v.layer.cornerRadius = 11
        v.layer.borderColor = Theme.Palette.yellow.cgColor
        v.layer.borderWidth = 2
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 22).isActive = true
        v.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return v
    }
}

extension GameSessionView: GameSessionViewProtocol {
    func updateAIPlayersCount(_ count: Int) {
        selectedAICount = max(minAI, min(maxAI, count))
        updateValueLabel()
    }
}
