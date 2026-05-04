import UIKit

final class NameInputOverlay: UIView {

    // MARK: - State
    private let onSubmit: (String) -> Void
    private let onCancel: () -> Void

    // MARK: - UI
    private let backdrop = UIView()
    private let panel = UIView()
    private let textField = UITextField()

    // MARK: - Init

    init(onSubmit: @escaping (String) -> Void,
         onCancel: @escaping () -> Void = {}) {
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func present(in container: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: container.topAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leadingAnchor.constraint(equalTo: container.leadingAnchor),
            trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        alpha = 0
        panel.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(withDuration: 0.22,
                       delay: 0,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.4,
                       options: [],
                       animations: {
            self.alpha = 1
            self.panel.transform = .identity
        }, completion: { _ in
            self.textField.becomeFirstResponder()
        })
    }

    // MARK: - Setup

    private func setupUI() {
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)

        panel.backgroundColor = Theme.Palette.ink
        panel.layer.cornerRadius = 22
        panel.layer.borderColor = Theme.Palette.yellow.cgColor
        panel.layer.borderWidth = 2
        panel.layer.shadowColor = UIColor.black.cgColor
        panel.layer.shadowOpacity = 0.6
        panel.layer.shadowRadius = 16
        panel.layer.shadowOffset = CGSize(width: 0, height: 8)
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)

        let title = Theme.makeTitleLabel("ВАШЕ ИМЯ", size: 26)
        title.textAlignment = .center

        let subtitle = Theme.makeAccentLabel("ПРЕДСТАВЬТЕСЬ ДРУГИМ ИГРОКАМ")
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        textField.attributedPlaceholder = NSAttributedString(
            string: "Введите никнейм",
            attributes: [
                .font: Theme.mono(14),
                .foregroundColor: UIColor.white.withAlphaComponent(0.35)
            ])
        textField.font = Theme.notable(18)
        textField.textColor = Theme.Palette.yellow
        textField.textAlignment = .center
        textField.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        textField.layer.cornerRadius = 12
        textField.layer.borderColor = Theme.Palette.yellow.withAlphaComponent(0.5).cgColor
        textField.layer.borderWidth = 2
        textField.autocapitalizationType = .words
        textField.autocorrectionType = .no
        textField.returnKeyType = .done
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(equalToConstant: 50).isActive = true

        textField.leftView  = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        textField.leftViewMode  = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        textField.rightViewMode = .always

        let submitButton = Theme.makePrimaryButton(title: "ГОТОВО", width: 200)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

        let cancelButton = UIButton(type: .system)
        cancelButton.setAttributedTitle(NSAttributedString(
            string: "ОТМЕНА",
            attributes: [.font: Theme.notable(11),
                         .foregroundColor: Theme.Palette.pink,
                         .kern: 2,
                         .underlineStyle: NSUnderlineStyle.single.rawValue]
        ), for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, subtitle, textField, submitButton, cancelButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.setCustomSpacing(8, after: title)
        stack.setCustomSpacing(20, after: subtitle)
        stack.setCustomSpacing(20, after: textField)
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),

            panel.centerXAnchor.constraint(equalTo: centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            panel.widthAnchor.constraint(equalToConstant: 300),

            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -22),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -20),

            textField.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(backdropTapped))
        backdrop.addGestureRecognizer(tap)
    }

    // MARK: - Actions

    @objc private func submitTapped() {
        let raw = textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let name = raw.isEmpty ? "Игрок" : raw
        dismiss { self.onSubmit(name) }
    }

    @objc private func cancelTapped() {
        dismiss { self.onCancel() }
    }

    @objc private func backdropTapped() {
        textField.resignFirstResponder()
    }

    private func dismiss(completion: @escaping () -> Void) {
        textField.resignFirstResponder()
        UIView.animate(withDuration: 0.18, animations: {
            self.alpha = 0
            self.panel.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }, completion: { _ in
            self.removeFromSuperview()
            completion()
        })
    }
}

// MARK: - UITextFieldDelegate

extension NameInputOverlay: UITextFieldDelegate {

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let current = textField.text ?? ""
        guard let r = Range(range, in: current) else { return true }
        let updated = current.replacingCharacters(in: r, with: string)
        return updated.count <= 24
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitTapped()
        return true
    }
}
