"""
LSTM-модель «личного коуча»: трекер вероятности победы.

Вход:  последовательность ходов игрока (T, 39) = obs(31) + action_onehot(8).
Выход: на КАЖДОМ шаге вероятность того, что игрок в итоге победит.

Это аналог «eval-bar» в шахматах: модель уточняет оценку по мере партии.
Резкие падения вероятности = места, где игрок ошибся (там коуч сравнивает
ход с рекомендацией DQN-оракула и объясняет ошибку).
"""
from __future__ import annotations

import torch
import torch.nn as nn

FEAT_DIM = 39  # OBS_DIM(31) + NUM_ACTIONS(8)


class CoachLSTM(nn.Module):
    def __init__(self, feat_dim: int = FEAT_DIM, hidden: int = 128, layers: int = 2):
        super().__init__()
        self.lstm = nn.LSTM(feat_dim, hidden, num_layers=layers, batch_first=True)
        self.head = nn.Sequential(
            nn.Linear(hidden, 64),
            nn.ReLU(),
            nn.Linear(64, 1),
        )

    def forward(self, x, h=None):
        # x: (B, T, FEAT_DIM)
        out, h = self.lstm(x, h)
        logits = self.head(out).squeeze(-1)   # (B, T) — логиты win-prob на каждом шаге
        return logits, h
