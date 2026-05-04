import UIKit

protocol SettingsViewProtocol: AnyObject {
    var presenter: SettingsPresenterProtocol? { get set }
    func updateSoundEffects(enabled: Bool)
    func updateMusic(enabled: Bool)
    func updateVolume(_ value: Float)
}

final class SettingsView: UIViewController {

    var presenter: SettingsPresenterProtocol?

    private let backButton = Theme.makeCircleIconButton(systemName: "chevron.left")
    private let titleLabel = Theme.makeTitleLabel("НАСТРОЙКИ", size: 42)

    private lazy var sfxRow    = ToggleRowView(title: "ЗВУКОВЫЕ ЭФФЕКТЫ", subtitle: "МЯУ, ВЗРЫВ, ШОРОХ КАРТ")
    private lazy var musicRow  = ToggleRowView(title: "МУЗЫКА", subtitle: "ФОНОВАЯ КОТО-СОНАТА")
    private lazy var volumeRow = VolumeRowView()

    private let rulesButton = SettingsView.makeMiniButton(title: "ПРАВИЛА ИГРЫ")

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindActions()
        presenter?.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Theme.styleNavigationController(self)
    }

    private func setupUI() {
        Theme.installBackground(on: view)

        view.addSubview(backButton)
        view.addSubview(titleLabel)

        let topStack = UIStackView(arrangedSubviews: [sfxRow, musicRow, volumeRow])
        topStack.axis = .vertical
        topStack.spacing = 14
        topStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topStack)

        view.addSubview(rulesButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            topStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 50),
            topStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            topStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            rulesButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            rulesButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            rulesButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            rulesButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func bindActions() {
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        rulesButton.addTarget(self, action: #selector(rulesTapped), for: .touchUpInside)
        sfxRow.onChange   = { [weak self] v in self?.presenter?.soundEffectsToggled(v) }
        musicRow.onChange = { [weak self] v in self?.presenter?.musicToggled(v) }
        volumeRow.onChange = { [weak self] v in self?.presenter?.volumeChanged(Float(v) / 100.0) }
    }

    @objc private func backTapped()  { presenter?.closeButtonTapped() }
    @objc private func rulesTapped() { presenter?.rulesButtonTapped() }

    private static func makeMiniButton(title: String) -> UIButton {
        let b = UIButton(type: .custom)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = Theme.notable(11)
        b.setTitleColor(Theme.Palette.yellow, for: .normal)
        b.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        b.layer.cornerRadius = 12
        b.layer.borderColor = Theme.Palette.yellow.withAlphaComponent(0.4).cgColor
        b.layer.borderWidth = 1
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }
}

extension SettingsView: SettingsViewProtocol {
    func updateSoundEffects(enabled: Bool) { sfxRow.setOn(enabled) }
    func updateMusic(enabled: Bool)        { musicRow.setOn(enabled) }
    func updateVolume(_ value: Float)      { volumeRow.setValue(Int(value * 100)) }
}



final class ToggleRowView: UIView {
    var onChange: ((Bool) -> Void)?

    private let titleLabel: UILabel
    private let subtitleLabel: UILabel
    private let toggle: UISwitch = {
        let s = UISwitch()
        s.onTintColor = Theme.Palette.yellow
        s.thumbTintColor = .white
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    init(title: String, subtitle: String) {
        let attr = NSAttributedString(string: title,
                                      attributes: [.kern: 1, .font: Theme.notable(13),
                                                   .foregroundColor: Theme.Palette.yellow])
        let titleL = UILabel()
        titleL.attributedText = attr

        let subL = UILabel()
        subL.text = subtitle
        subL.font = Theme.mono(9)
        subL.textColor = UIColor.white.withAlphaComponent(0.55)

        self.titleLabel = titleL
        self.subtitleLabel = subL
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black.withAlphaComponent(0.55)
        layer.cornerRadius = 18
        layer.borderColor = Theme.Palette.yellow.cgColor
        layer.borderWidth = 2

        let stack = UIStackView(arrangedSubviews: [titleL, subL])
        stack.axis = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        addSubview(toggle)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -8),

            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 64)
        ])

        toggle.addTarget(self, action: #selector(switched), for: .valueChanged)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setOn(_ on: Bool) { toggle.setOn(on, animated: false) }

    @objc private func switched() { onChange?(toggle.isOn) }
}


final class VolumeRowView: UIView {
    var onChange: ((Int) -> Void)?

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.attributedText = NSAttributedString(string: "ГРОМКОСТЬ",
            attributes: [.kern: 1, .font: Theme.notable(13), .foregroundColor: Theme.Palette.yellow])
        return l
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.notable(18)
        l.textColor = Theme.Palette.yellow
        l.text = "60%"
        return l
    }()

    private let slider: UISlider = {
        let s = UISlider()
        s.minimumValue = 0
        s.maximumValue = 100
        s.value = 60
        s.minimumTrackTintColor = Theme.Palette.yellow
        s.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.2)
        s.thumbTintColor = Theme.Palette.yellow
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let ticks: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.distribution = .equalSpacing
        for v in [0, 25, 50, 75, 100] {
            let l = Theme.makeMonoLabel("\(v)", size: 9, color: UIColor.white.withAlphaComponent(0.45))
            s.addArrangedSubview(l)
        }
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black.withAlphaComponent(0.55)
        layer.cornerRadius = 18
        layer.borderColor = Theme.Palette.yellow.cgColor
        layer.borderWidth = 2

        let topRow = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        topRow.axis = .horizontal
        topRow.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [topRow, slider, ticks])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18)
        ])

        slider.addTarget(self, action: #selector(changed), for: .valueChanged)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setValue(_ v: Int) {
        slider.value = Float(v)
        valueLabel.text = "\(v)%"
    }

    @objc private func changed() {
        let v = Int(slider.value)
        valueLabel.text = "\(v)%"
        onChange?(v)
    }
}
