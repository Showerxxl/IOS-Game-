"""
Конвертация LSTM-коуча в Core ML (.mlpackage) с гибкой длиной последовательности.

Модель принимает последовательность ходов (1, T, 39) и возвращает на каждом
шаге вероятность победы (1, T). Длина T переменная (RangeDim), т.к. партии
разной длины. Инференс выполняется один раз после партии.

Запуск:
    cd ML && source .venv/bin/activate
    python3 convert_lstm_coreml.py
Создаёт ML/coreml/KotozryvCoach.mlpackage
"""
from __future__ import annotations

import os
import numpy as np
import torch
import torch.nn as nn

from coach.lstm_model import CoachLSTM, FEAT_DIM

CKPT = os.path.join(os.path.dirname(__file__), "coach", "coach_lstm.pt")
OUT_DIR = os.path.join(os.path.dirname(__file__), "coreml")
os.makedirs(OUT_DIR, exist_ok=True)


class CoachExport(nn.Module):
    """Обёртка: на выходе сразу вероятности (sigmoid), без hidden state."""
    def __init__(self, core: CoachLSTM):
        super().__init__()
        self.core = core

    def forward(self, x):
        logits, _ = self.core(x)
        return torch.sigmoid(logits)   # (1, T) — P(победа) на каждом шаге


def convert(name: str = "KotozryvCoach"):
    import coremltools as ct

    core = CoachLSTM()
    core.load_state_dict(torch.load(CKPT, map_location="cpu"))
    core.eval()
    model = CoachExport(core).eval()

    example = torch.zeros(1, 10, FEAT_DIM, dtype=torch.float32)
    traced = torch.jit.trace(model, example)

    seq_len = ct.RangeDim(lower_bound=1, upper_bound=200, default=10)
    mlmodel = ct.convert(
        traced,
        inputs=[ct.TensorType(name="moves",
                              shape=(1, seq_len, FEAT_DIM),
                              dtype=np.float32)],
        outputs=[ct.TensorType(name="win_prob", dtype=np.float32)],
        minimum_deployment_target=ct.target.iOS16,
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT32,
    )
    mlmodel.short_description = (
        "Котозрыв LSTM-коуч: вход — последовательность ходов (T x 39), "
        "выход — вероятность победы P(win) на каждом шаге партии."
    )
    mlmodel.author = "Kotozryv ML"

    out_path = os.path.join(OUT_DIR, f"{name}.mlpackage")
    mlmodel.save(out_path)

    # проверка соответствия
    rng = np.random.default_rng(0)
    x = rng.standard_normal((1, 17, FEAT_DIM)).astype(np.float32)
    with torch.no_grad():
        torch_out = model(torch.from_numpy(x)).numpy()[0]
    cm_out = mlmodel.predict({"moves": x})["win_prob"][0]
    max_diff = float(np.max(np.abs(torch_out - cm_out)))
    print(f"Сохранено: {out_path}")
    print(f"Макс. расхождение PyTorch vs CoreML: {max_diff:.6f}")
    print("OK" if max_diff < 1e-2 else "ВНИМАНИЕ: расхождение великовато")


if __name__ == "__main__":
    convert()
