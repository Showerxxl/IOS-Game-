"""
Конвертация обученной Q-сети (PyTorch) в Core ML (.mlpackage) для on-device
инференса в iOS-приложении.

Модель принимает вектор состояния длиной OBS_DIM (31) и возвращает 8 Q-значений
(по одному на действие). Маскирование нелегальных действий и argmax делаются
уже в Swift (MLBotService), чтобы модель оставалась максимально простой.

Запуск:
    cd ML && source .venv/bin/activate
    python3 convert_to_coreml.py --ckpt checkpoints/dqn_hard.pt --name KotozryvBotHard

Создаёт ML/coreml/<name>.mlpackage
"""
from __future__ import annotations

import argparse
import os

import numpy as np
import torch

from model import QNetwork
from game.env import OBS_DIM
from game.engine import NUM_ACTIONS

OUT_DIR = os.path.join(os.path.dirname(__file__), "coreml")
os.makedirs(OUT_DIR, exist_ok=True)


def convert(ckpt_path: str, name: str):
    import coremltools as ct

    net = QNetwork()
    net.load_state_dict(torch.load(ckpt_path, map_location="cpu"))
    net.eval()

    example = torch.zeros(1, OBS_DIM, dtype=torch.float32)
    traced = torch.jit.trace(net, example)

    # ВАЖНО: "state" — зарезервированное имя в Core ML ML Program, используем "observation".
    mlmodel = ct.convert(
        traced,
        inputs=[ct.TensorType(name="observation", shape=(1, OBS_DIM), dtype=np.float32)],
        outputs=[ct.TensorType(name="q_values", dtype=np.float32)],
        minimum_deployment_target=ct.target.iOS15,
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT32,  # точное соответствие PyTorch
    )

    mlmodel.short_description = (
        "Котозрыв DQN-бот: вход — вектор состояния (31), "
        "выход — Q-значения 8 действий (DRAW, ATTACK, SKIP, FAVOR, "
        "SHUFFLE, SEE_FUTURE, CAT_PAIR, CAT_TRIO)."
    )
    mlmodel.author = "Kotozryv ML"

    out_path = os.path.join(OUT_DIR, f"{name}.mlpackage")
    mlmodel.save(out_path)

    # Проверка: сравним выход Core ML и PyTorch на случайном входе.
    rng = np.random.default_rng(0)
    x = rng.standard_normal((1, OBS_DIM)).astype(np.float32)
    with torch.no_grad():
        torch_out = net(torch.from_numpy(x)).numpy()[0]
    cm_out = mlmodel.predict({"observation": x})["q_values"][0]
    max_diff = float(np.max(np.abs(torch_out - cm_out)))

    print(f"Сохранено: {out_path}")
    print(f"Размер действий: {NUM_ACTIONS}, входной вектор: {OBS_DIM}")
    print(f"Макс. расхождение PyTorch vs CoreML: {max_diff:.6f}")
    print("PyTorch argmax:", int(np.argmax(torch_out)),
          " CoreML argmax:", int(np.argmax(cm_out)))
    if max_diff < 1e-3:
        print("OK: конвертация точная.")
    else:
        print("ВНИМАНИЕ: расхождение великовато, проверь версии torch/coremltools.")


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", default="checkpoints/dqn_hard.pt")
    ap.add_argument("--name", default="KotozryvBotHard")
    return ap.parse_args()


if __name__ == "__main__":
    args = parse_args()
    convert(args.ckpt, args.name)
