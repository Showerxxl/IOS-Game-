//
//  SettingsView.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import UIKit

protocol SettingsViewProtocol: AnyObject {
    var presenter: SettingsPresenterProtocol? { get set }
    func updateSoundEffects(enabled: Bool)
    func updateMusic(enabled: Bool)
    func updateVolume(_ value: Float)
}

class SettingsView: UIViewController {
    
    // MARK: - Properties
    var presenter: SettingsPresenterProtocol?
    
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Настройки"
        label.font = UIFont.boldSystemFont(ofSize: 28)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let soundEffectsLabel: UILabel = {
        let label = UILabel()
        label.text = "Звуковые эффекты"
        label.font = UIFont.systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let soundEffectsSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        return toggle
    }()
    
    private let musicLabel: UILabel = {
        let label = UILabel()
        label.text = "Музыкальное сопровождение"
        label.font = UIFont.systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let musicSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        return toggle
    }()
    
    private let volumeLabel: UILabel = {
        let label = UILabel()
        label.text = "Громкость"
        label.font = UIFont.systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let volumeSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0.5
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    private let volumeValueLabel: UILabel = {
        let label = UILabel()
        label.text = "50%"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Закрыть", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
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
        
        view.addSubview(titleLabel)
        view.addSubview(soundEffectsLabel)
        view.addSubview(soundEffectsSwitch)
        view.addSubview(musicLabel)
        view.addSubview(musicSwitch)
        view.addSubview(volumeLabel)
        view.addSubview(volumeSlider)
        view.addSubview(volumeValueLabel)
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            
            soundEffectsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            soundEffectsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 60),
            
            soundEffectsSwitch.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            soundEffectsSwitch.centerYAnchor.constraint(equalTo: soundEffectsLabel.centerYAnchor),
            
            musicLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            musicLabel.topAnchor.constraint(equalTo: soundEffectsLabel.bottomAnchor, constant: 30),
            
            musicSwitch.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            musicSwitch.centerYAnchor.constraint(equalTo: musicLabel.centerYAnchor),
            
            volumeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            volumeLabel.topAnchor.constraint(equalTo: musicLabel.bottomAnchor, constant: 30),
            
            volumeValueLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            volumeValueLabel.centerYAnchor.constraint(equalTo: volumeLabel.centerYAnchor),
            volumeValueLabel.widthAnchor.constraint(equalToConstant: 50),
            
            volumeSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            volumeSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            volumeSlider.topAnchor.constraint(equalTo: volumeLabel.bottomAnchor, constant: 15),
            
            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            closeButton.widthAnchor.constraint(equalToConstant: 200),
            closeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupActions() {
        soundEffectsSwitch.addTarget(self, action: #selector(soundEffectsSwitchChanged), for: .valueChanged)
        musicSwitch.addTarget(self, action: #selector(musicSwitchChanged), for: .valueChanged)
        volumeSlider.addTarget(self, action: #selector(volumeSliderChanged), for: .valueChanged)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func soundEffectsSwitchChanged() {
        presenter?.soundEffectsToggled(soundEffectsSwitch.isOn)
    }
    
    @objc private func musicSwitchChanged() {
        presenter?.musicToggled(musicSwitch.isOn)
    }
    
    @objc private func volumeSliderChanged() {
        let value = volumeSlider.value
        volumeValueLabel.text = "\(Int(value * 100))%"
        presenter?.volumeChanged(value)
    }
    
    @objc private func closeButtonTapped() {
        presenter?.closeButtonTapped()
    }
}

// MARK: - SettingsViewProtocol
extension SettingsView: SettingsViewProtocol {
    func updateSoundEffects(enabled: Bool) {
        soundEffectsSwitch.isOn = enabled
    }
    
    func updateMusic(enabled: Bool) {
        musicSwitch.isOn = enabled
    }
    
    func updateVolume(_ value: Float) {
        volumeSlider.value = value
        volumeValueLabel.text = "\(Int(value * 100))%"
    }
}
