//
//  GameSessionView.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import UIKit

protocol GameSessionViewProtocol: AnyObject {
    var presenter: GameSessionPresenterProtocol? { get set }
    func updateAIPlayersCount(_ count: Int)
}

class GameSessionView: UIViewController {
    
    // MARK: - Properties
    var presenter: GameSessionPresenterProtocol?
    private var selectedAICount: Int = 1
    
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Настройка игры"
        label.font = UIFont.boldSystemFont(ofSize: 28)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let gameModeLabel: UILabel = {
        let label = UILabel()
        label.text = "Режим игры: Одиночная против ИИ"
        label.font = UIFont.systemFont(ofSize: 18)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let aiCountLabel: UILabel = {
        let label = UILabel()
        label.text = "Количество ИИ противников:"
        label.font = UIFont.systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let aiCountValueLabel: UILabel = {
        let label = UILabel()
        label.text = "1"
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let aiCountStepper: UIStepper = {
        let stepper = UIStepper()
        stepper.minimumValue = 1
        stepper.maximumValue = 5
        stepper.value = 1
        stepper.stepValue = 1
        stepper.translatesAutoresizingMaskIntoConstraints = false
        return stepper
    }()
    
    private let startGameButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Начать игру", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Назад", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        presenter?.viewDidLoad()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationItem.hidesBackButton = true
        
        view.addSubview(titleLabel)
        view.addSubview(gameModeLabel)
        view.addSubview(aiCountLabel)
        view.addSubview(aiCountValueLabel)
        view.addSubview(aiCountStepper)
        view.addSubview(startGameButton)
        view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            
            gameModeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gameModeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 60),
            
            aiCountLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            aiCountLabel.topAnchor.constraint(equalTo: gameModeLabel.bottomAnchor, constant: 60),
            
            aiCountValueLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            aiCountValueLabel.topAnchor.constraint(equalTo: aiCountLabel.bottomAnchor, constant: 20),
            
            aiCountStepper.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            aiCountStepper.topAnchor.constraint(equalTo: aiCountValueLabel.bottomAnchor, constant: 10),
            
            startGameButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startGameButton.topAnchor.constraint(equalTo: aiCountStepper.bottomAnchor, constant: 80),
            startGameButton.widthAnchor.constraint(equalToConstant: 250),
            startGameButton.heightAnchor.constraint(equalToConstant: 50),
            
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10)
        ])
    }
    
    private func setupActions() {
        aiCountStepper.addTarget(self, action: #selector(aiCountChanged), for: .valueChanged)
        startGameButton.addTarget(self, action: #selector(startGameTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func aiCountChanged() {
        selectedAICount = Int(aiCountStepper.value)
        aiCountValueLabel.text = "\(selectedAICount)"
        presenter?.aiCountChanged(selectedAICount)
    }
    
    @objc private func startGameTapped() {
        presenter?.startGameTapped(aiCount: selectedAICount)
    }
    
    @objc private func backTapped() {
        presenter?.backButtonTapped()
    }
}

// MARK: - GameSessionViewProtocol
extension GameSessionView: GameSessionViewProtocol {
    func updateAIPlayersCount(_ count: Int) {
        selectedAICount = count
        aiCountValueLabel.text = "\(count)"
        aiCountStepper.value = Double(count)
    }
}
