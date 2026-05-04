import UIKit

enum Theme {

    // MARK: - Palette
    enum Palette {
        static let yellow    = UIColor(red: 243/255, green: 224/255, blue:  81/255, alpha: 1) // #F3E051
        static let yellowDim = UIColor(red: 196/255, green: 180/255, blue:  60/255, alpha: 1)
        static let black     = UIColor(red:   9/255, green:   8/255, blue:   8/255, alpha: 1)
        static let red       = UIColor(red: 155/255, green:  28/255, blue:  28/255, alpha: 1)
        static let redDeep   = UIColor(red:  95/255, green:  12/255, blue:  12/255, alpha: 1)
        static let pink      = UIColor(red: 255/255, green: 156/255, blue: 156/255, alpha: 1) // #FF9C9C
        static let ink       = UIColor(red:  36/255, green:  33/255, blue:  12/255, alpha: 1) // #24210C

        static let dark       = ink
        static let buttonFill = yellow
        static let outline    = ink
        static let accentRed  = red
    }

    // MARK: - Metrics
    enum Metric {
        static let horizontalInset: CGFloat   = 24
        static let buttonHeight: CGFloat      = 60
        static let pillRadius: CGFloat        = 999
        static let cornerRadius: CGFloat      = 22
        static let cardCornerRadius: CGFloat  = 12
        static let strokeWidth: CGFloat       = 2
    }

    enum FontSize {
        static let title: CGFloat    = 42
        static let subtitle: CGFloat = 22
        static let body: CGFloat     = 14
        static let caption: CGFloat  = 11
    }

    // MARK: - Fonts
    static func notable(_ size: CGFloat) -> UIFont {
        UIFont(name: "Notable-Regular", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .heavy)
    }

    static func mono(_ size: CGFloat) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    // MARK: - Background
    @discardableResult
    static func installBackground(on view: UIView) -> UIView {
        view.backgroundColor = UIColor(red: 26/255, green: 6/255, blue: 6/255, alpha: 1)

        let iv = UIImageView(image: UIImage(named: "background"))
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(iv, at: 0)
        NSLayoutConstraint.activate([
            iv.topAnchor.constraint(equalTo: view.topAnchor),
            iv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            iv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let vignette = UIView()
        vignette.translatesAutoresizingMaskIntoConstraints = false
        vignette.isUserInteractionEnabled = false
        view.insertSubview(vignette, aboveSubview: iv)
        NSLayoutConstraint.activate([
            vignette.topAnchor.constraint(equalTo: view.topAnchor),
            vignette.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            vignette.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vignette.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        DispatchQueue.main.async {
            let layer = CAGradientLayer()
            layer.frame = vignette.bounds
            layer.type  = .radial
            layer.colors = [UIColor.clear.cgColor,
                            UIColor.black.withAlphaComponent(0.55).cgColor]
            layer.locations = [0.4, 1.0]
            layer.startPoint = CGPoint(x: 0.5, y: 0.4)
            layer.endPoint   = CGPoint(x: 1.0, y: 1.0)
            vignette.layer.addSublayer(layer)
        }
        return iv
    }

    // MARK: - Buttons

    // Жёлтая pill-кнопка
    static func makePrimaryButton(title: String, width: CGFloat? = nil, height: CGFloat = 60) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = notable(14)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.6
        button.backgroundColor = Palette.yellow
        button.setTitleColor(Palette.black, for: .normal)
        button.setTitleColor(Palette.black.withAlphaComponent(0.4), for: .disabled)
        button.layer.cornerRadius = height / 2
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.25
        button.layer.shadowRadius = 8
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: height).isActive = true
        if let width = width {
            button.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        return button
    }

    // Прозрачная pill-кнопка с жёлтой обводкой
    static func makeGhostButton(title: String, height: CGFloat = 54) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = notable(14)
        button.backgroundColor = .clear
        button.setTitleColor(Palette.yellow, for: .normal)
        button.layer.cornerRadius = height / 2
        button.layer.borderColor = Palette.yellow.cgColor
        button.layer.borderWidth = 2
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: height).isActive = true
        return button
    }

    // Круглая иконочная кнопка
    static func makeCircleIconButton(systemName: String, size: CGFloat = 44, weight: UIImage.SymbolWeight = .semibold) -> UIButton {
        let button = UIButton(type: .custom)
        let cfg = UIImage.SymbolConfiguration(pointSize: size * 0.42, weight: weight)
        button.setImage(UIImage(systemName: systemName, withConfiguration: cfg), for: .normal)
        button.tintColor = Palette.yellow
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = size / 2
        button.layer.borderColor = Palette.yellow.cgColor
        button.layer.borderWidth = 2
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: size).isActive = true
        button.heightAnchor.constraint(equalToConstant: size).isActive = true
        return button
    }

    // Кнопка-картинка
    static func makeImageButton(imageName: String, size: CGFloat = 44) -> UIButton {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: imageName), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: size).isActive = true
        button.heightAnchor.constraint(equalToConstant: size).isActive = true
        return button
    }

    static func makeIconButton(systemName: String) -> UIButton {
        makeCircleIconButton(systemName: systemName)
    }

    // MARK: - Labels

    // Жёлтый Notable заголовок с тенью
    static func makeTitleLabel(_ text: String, size: CGFloat = FontSize.title) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = notable(size)
        label.textColor = Palette.yellow
        label.textAlignment = .center
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.55
        label.layer.shadowOffset = CGSize(width: 0, height: 4)
        label.layer.shadowRadius = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }


    static func makeBodyLabel(_ text: String, size: CGFloat = 16) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = notable(size)
        label.textColor = Palette.yellow
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    // Розовая мелкая надпись-подсказка
    static func makeAccentLabel(_ text: String, size: CGFloat = 11, kerning: CGFloat = 3) -> UILabel {
        let label = UILabel()
        let attr = NSAttributedString(string: text.uppercased(),
                                      attributes: [
                                        .font: notable(size),
                                        .foregroundColor: Palette.pink,
                                        .kern: kerning
                                      ])
        label.attributedText = attr
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func makeMonoLabel(_ text: String, size: CGFloat = 11, color: UIColor? = nil) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = mono(size)
        label.textColor = color ?? UIColor.white.withAlphaComponent(0.65)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    // MARK: - Panels

    // Чёрная плашка с жёлтой обводкой
    static func makePanel(borderAlpha: CGFloat = 1.0) -> UIView {
        let panel = UIView()
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        panel.layer.cornerRadius = Metric.cornerRadius
        panel.layer.borderColor  = Palette.yellow.withAlphaComponent(borderAlpha).cgColor
        panel.layer.borderWidth  = 2
        panel.translatesAutoresizingMaskIntoConstraints = false
        return panel
    }

    // Текстовое поле
    static func makeTextField(placeholder: String) -> UITextField {
        let field = UITextField()
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: Palette.yellow.withAlphaComponent(0.4),
                         .font: notable(14)]
        )
        field.font = notable(14)
        field.textColor = Palette.yellow
        field.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        field.layer.cornerRadius = 14
        field.layer.borderColor = Palette.yellow.withAlphaComponent(0.4).cgColor
        field.layer.borderWidth = 2
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 48).isActive = true
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    static func makeLogoImageView() -> UIImageView {
        let iv = UIImageView(image: UIImage(named: "name"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.layer.shadowColor = UIColor.black.cgColor
        iv.layer.shadowOpacity = 0.6
        iv.layer.shadowOffset = CGSize(width: 0, height: 6)
        iv.layer.shadowRadius = 0
        return iv
    }

    static func styleNavigationController(_ vc: UIViewController) {
        vc.navigationController?.setNavigationBarHidden(true, animated: false)
    }

    static func roundCorner(_ view: UIView, radius: CGFloat) {
        view.layer.cornerRadius = radius
        view.layer.masksToBounds = true
    }
}
