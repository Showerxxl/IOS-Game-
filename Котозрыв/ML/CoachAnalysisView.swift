import UIKit

final class CoachAnalysisView: UIViewController {

    private let report: CoachReport
    private let onContinue: () -> Void

    init(report: CoachReport, onContinue: @escaping () -> Void) {
        self.report = report
        self.onContinue = onContinue
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Theme.styleNavigationController(self)
    }

    private func setupUI() {
        Theme.installBackground(on: view)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        view.addSubview(scroll)

        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 18
        content.alignment = .fill
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        // Заголовок
        let title = Theme.makeTitleLabel("ЛИЧНЫЙ КОУЧ", size: 34)
        title.textAlignment = .center
        let subtitle = Theme.makeAccentLabel(report.didWin ? "РАЗБОР ПОБЕДЫ" : "РАЗБОР ПАРТИИ")
        subtitle.textAlignment = .center

        let header = UIStackView(arrangedSubviews: [title, subtitle])
        header.axis = .vertical
        header.spacing = 6
        header.alignment = .center

        content.addArrangedSubview(header)
        content.addArrangedSubview(makeStatsRow())
        content.addArrangedSubview(makeSectionTitle("ВЕРОЯТНОСТЬ ПОБЕДЫ ПО ХОДАМ"))
        content.addArrangedSubview(makeChartCard())
        content.addArrangedSubview(makeStyleCard())
        content.addArrangedSubview(makeSectionTitle("КЛЮЧЕВЫЕ МОМЕНТЫ"))
        content.addArrangedSubview(makeMistakesCard())

        let menuButton = Theme.makePrimaryButton(title: "ПРОДОЛЖИТЬ", width: 244)
        menuButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        let btnWrap = UIStackView(arrangedSubviews: [menuButton])
        btnWrap.alignment = .center
        content.addArrangedSubview(btnWrap)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            content.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 24),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -40),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            content.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48),
        ])
    }

    // MARK: - Карточки

    private func makeStatsRow() -> UIView {
        let accuracy = Int((report.accuracy * 100).rounded())
        let acc = makeStatBox(value: "\(accuracy)%", caption: "ТОЧНОСТЬ ХОДОВ")
        let moves = makeStatBox(value: "\(report.totalMoves)", caption: "ХОДОВ")
        let result = makeStatBox(value: report.didWin ? "🏆" : "💥",
                                 caption: report.didWin ? "ПОБЕДА" : "ПОРАЖЕНИЕ")
        let row = UIStackView(arrangedSubviews: [acc, moves, result])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 10
        return row
    }

    private func makeStatBox(value: String, caption: String) -> UIView {
        let box = UIView()
        box.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        box.layer.cornerRadius = 14
        box.layer.borderColor = Theme.Palette.yellow.withAlphaComponent(0.3).cgColor
        box.layer.borderWidth = 1
        box.translatesAutoresizingMaskIntoConstraints = false

        let v = UILabel()
        v.attributedText = NSAttributedString(string: value,
            attributes: [.font: Theme.notable(22), .foregroundColor: Theme.Palette.yellow])
        v.textAlignment = .center

        let c = Theme.makeMonoLabel(caption, size: 8, color: UIColor.white.withAlphaComponent(0.6))
        c.textAlignment = .center
        c.numberOfLines = 2

        let s = UIStackView(arrangedSubviews: [v, c])
        s.axis = .vertical; s.spacing = 4; s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(s)
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: 72),
            s.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            s.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            s.leadingAnchor.constraint(greaterThanOrEqualTo: box.leadingAnchor, constant: 4),
            s.trailingAnchor.constraint(lessThanOrEqualTo: box.trailingAnchor, constant: -4),
        ])
        return box
    }

    private func makeChartCard() -> UIView {
        let card = makePanel()
        let chart = WinProbChartView(values: report.winProb)
        chart.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(chart)
        NSLayoutConstraint.activate([
            chart.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            chart.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            chart.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            chart.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            chart.heightAnchor.constraint(equalToConstant: 150),
        ])
        return card
    }

    private func makeStyleCard() -> UIView {
        let card = makePanel()
        let kicker = Theme.makeAccentLabel("ТВОЙ СТИЛЬ")
        kicker.textAlignment = .left
        let title = UILabel()
        title.attributedText = NSAttributedString(string: report.styleTitle,
            attributes: [.font: Theme.notable(22), .foregroundColor: Theme.Palette.yellow, .kern: 1])
        let desc = Theme.makeMonoLabel(report.styleDescription, size: 11,
                                       color: UIColor.white.withAlphaComponent(0.75))
        desc.numberOfLines = 0

        let s = UIStackView(arrangedSubviews: [kicker, title, desc])
        s.axis = .vertical; s.spacing = 6; s.alignment = .leading
        s.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(s)
        NSLayoutConstraint.activate([
            s.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            s.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            s.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            s.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        return card
    }

    private func makeMistakesCard() -> UIView {
        let card = makePanel()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        if report.mistakes.isEmpty {
            let l = Theme.makeMonoLabel("Отличная игра! Грубых ошибок не найдено — ты играл близко к оптимуму ИИ.",
                                        size: 12, color: Theme.Palette.yellow)
            l.numberOfLines = 0
            stack.addArrangedSubview(l)
        } else {
            for m in report.mistakes {
                stack.addArrangedSubview(makeMistakeRow(m))
            }
        }

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        return card
    }

    private func makeMistakeRow(_ m: CoachMistake) -> UIView {
        let row = UIView()

        let dot = UILabel()
        dot.text = "⚠️"
        dot.font = .systemFont(ofSize: 16)
        dot.translatesAutoresizingMaskIntoConstraints = false

        let text = Theme.makeMonoLabel(m.advice, size: 11, color: UIColor.white.withAlphaComponent(0.85))
        text.numberOfLines = 0
        text.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(dot)
        row.addSubview(text)
        NSLayoutConstraint.activate([
            dot.topAnchor.constraint(equalTo: row.topAnchor),
            dot.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            text.topAnchor.constraint(equalTo: row.topAnchor),
            text.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            text.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            text.trailingAnchor.constraint(equalTo: row.trailingAnchor),
        ])
        return row
    }

    // MARK: - Helpers

    private func makeSectionTitle(_ s: String) -> UILabel {
        let l = UILabel()
        l.attributedText = NSAttributedString(string: s,
            attributes: [.kern: 2, .font: Theme.notable(11), .foregroundColor: Theme.Palette.pink])
        return l
    }

    private func makePanel() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        v.layer.cornerRadius = 16
        v.layer.borderColor = Theme.Palette.yellow.withAlphaComponent(0.3).cgColor
        v.layer.borderWidth = 1
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    @objc private func continueTapped() {
        dismiss(animated: true) { [weak self] in self?.onContinue() }
    }
}

/// Простой линейный график вероятности победы (0..1) по ходам.
final class WinProbChartView: UIView {
    private let values: [Float]
    init(values: [Float]) {
        self.values = values
        super.init(frame: .zero)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), values.count > 0 else { return }
        let w = rect.width, h = rect.height

        // линия 50%
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [4, 4])
        ctx.move(to: CGPoint(x: 0, y: h * 0.5))
        ctx.addLine(to: CGPoint(x: w, y: h * 0.5))
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        // точки
        let n = values.count
        func point(_ i: Int) -> CGPoint {
            let x = n == 1 ? w * 0.5 : w * CGFloat(i) / CGFloat(n - 1)
            let y = h * (1 - CGFloat(max(0, min(1, values[i]))))
            return CGPoint(x: x, y: y)
        }

        // заливка под кривой
        let fill = UIBezierPath()
        fill.move(to: CGPoint(x: point(0).x, y: h))
        for i in 0..<n { fill.addLine(to: point(i)) }
        fill.addLine(to: CGPoint(x: point(n - 1).x, y: h))
        fill.close()
        Theme.Palette.yellow.withAlphaComponent(0.15).setFill()
        fill.fill()

        // кривая
        let line = UIBezierPath()
        line.move(to: point(0))
        for i in 1..<max(1, n) { line.addLine(to: point(i)) }
        Theme.Palette.yellow.setStroke()
        line.lineWidth = 2.5
        line.lineJoinStyle = .round
        line.stroke()

        // маркеры
        for i in 0..<n {
            let p = point(i)
            let dot = UIBezierPath(ovalIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
            (values[i] >= 0.5 ? Theme.Palette.yellow : Theme.Palette.pink).setFill()
            dot.fill()
        }
    }
}
