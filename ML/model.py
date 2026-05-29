"""
Q-сеть для DQN-агента «Котозрыв».

Простая MLP: OBS_DIM -> 256 -> 128 -> NUM_ACTIONS.
Маленькая (несколько десятков КБ), что важно для on-device инференса в Core ML.
"""
from __future__ import annotations

import torch
import torch.nn as nn

from game.env import OBS_DIM
from game.engine import NUM_ACTIONS


class QNetwork(nn.Module):
    def __init__(self, obs_dim: int = OBS_DIM, n_actions: int = NUM_ACTIONS,
                 hidden1: int = 256, hidden2: int = 128):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(obs_dim, hidden1),
            nn.ReLU(),
            nn.Linear(hidden1, hidden2),
            nn.ReLU(),
            nn.Linear(hidden2, n_actions),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)
