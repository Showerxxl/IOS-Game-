"""
Обучение LSTM-коуча (трекер вероятности победы).

Цель: на каждом шаге партии предсказывать P(игрок победит).
Таргет — финальный исход партии (won 0/1), одинаковый для всех шагов;
LSTM учится уточнять оценку по мере накопления контекста.

Метрики:
  - BCE loss
  - ROC-AUC и accuracy по ПОСЛЕДНЕМУ шагу (где оценка наиболее уверенная)
  - Калибровка: средняя предсказанная P vs реальная доля побед

Запуск:
    cd ML && source .venv/bin/activate
    python3 train_lstm.py --epochs 15
"""
from __future__ import annotations

import argparse
import os

import numpy as np
import torch
import torch.nn as nn
from torch.nn.utils.rnn import pad_sequence

from coach.lstm_model import CoachLSTM, FEAT_DIM

DATA = os.path.join(os.path.dirname(__file__), "coach", "coach_dataset.npz")
CKPT = os.path.join(os.path.dirname(__file__), "coach", "coach_lstm.pt")
ART = os.path.join(os.path.dirname(__file__), "artifacts")
os.makedirs(ART, exist_ok=True)


def load_data():
    d = np.load(DATA, allow_pickle=True)
    seqs = list(d["sequences"])
    won = d["won"].astype(np.float32)
    return seqs, won


def make_batches(seqs, won, idx, batch_size, device, shuffle=True):
    order = np.array(idx)
    if shuffle:
        np.random.shuffle(order)
    for i in range(0, len(order), batch_size):
        b = order[i:i + batch_size]
        tensors = [torch.from_numpy(seqs[j]) for j in b]
        lengths = torch.tensor([t.shape[0] for t in tensors])
        padded = pad_sequence(tensors, batch_first=True)  # (B, Tmax, FEAT)
        labels = torch.tensor(won[b])
        yield padded.to(device), lengths.to(device), labels.to(device)


def step_mask(lengths, Tmax, device):
    ar = torch.arange(Tmax, device=device).unsqueeze(0)
    return (ar < lengths.unsqueeze(1)).float()   # (B, Tmax)


def evaluate(model, seqs, won, idx, device, batch_size=256):
    model.eval()
    last_preds, last_labels = [], []
    with torch.no_grad():
        for padded, lengths, labels in make_batches(seqs, won, idx, batch_size, device, shuffle=False):
            logits, _ = model(padded)
            probs = torch.sigmoid(logits)
            for k, L in enumerate(lengths.tolist()):
                last_preds.append(probs[k, L - 1].item())
                last_labels.append(labels[k].item())
    last_preds = np.array(last_preds)
    last_labels = np.array(last_labels)
    acc = float(((last_preds > 0.5) == (last_labels > 0.5)).mean())
    auc = roc_auc(last_labels, last_preds)
    return acc, auc, last_preds.mean(), last_labels.mean()


def roc_auc(y, p):
    # компактный AUC без sklearn (метод рангов Манна–Уитни)
    order = np.argsort(p)
    ranks = np.empty_like(order, dtype=float)
    ranks[order] = np.arange(1, len(p) + 1)
    pos = y > 0.5
    n_pos = pos.sum()
    n_neg = len(y) - n_pos
    if n_pos == 0 or n_neg == 0:
        return float("nan")
    return float((ranks[pos].sum() - n_pos * (n_pos + 1) / 2) / (n_pos * n_neg))


def train(args):
    device = torch.device("cpu")
    seqs, won = load_data()
    n = len(seqs)
    print(f"Загружено {n} партий, FEAT_DIM={seqs[0].shape[1]} (ожидаем {FEAT_DIM})")

    rng = np.random.default_rng(0)
    perm = rng.permutation(n)
    split = int(n * 0.9)
    train_idx, val_idx = perm[:split], perm[split:]

    model = CoachLSTM().to(device)
    opt = torch.optim.Adam(model.parameters(), lr=args.lr)
    bce = nn.BCEWithLogitsLoss(reduction="none")

    for epoch in range(1, args.epochs + 1):
        model.train()
        total, count = 0.0, 0
        for padded, lengths, labels in make_batches(seqs, won, train_idx, args.batch, device):
            Tmax = padded.shape[1]
            logits, _ = model(padded)               # (B, Tmax)
            tgt = labels.unsqueeze(1).expand(-1, Tmax)
            m = step_mask(lengths, Tmax, device)
            loss = (bce(logits, tgt) * m).sum() / m.sum()
            opt.zero_grad()
            loss.backward()
            nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            opt.step()
            total += loss.item() * len(lengths)
            count += len(lengths)
        acc, auc, pmean, lmean = evaluate(model, seqs, won, val_idx, device)
        print(f"epoch {epoch:>2}/{args.epochs}  train_loss={total/count:.4f}  "
              f"val_acc={acc:.1%}  val_AUC={auc:.3f}  "
              f"pred_mean={pmean:.2f} (real {lmean:.2f})")

    torch.save(model.state_dict(), CKPT)
    print(f"\nМодель сохранена: {CKPT}")
    _plot_example(model, seqs, won, val_idx, device)


def _plot_example(model, seqs, won, val_idx, device):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except Exception:
        return
    model.eval()
    # покажем кривую win-prob для одной выигранной и одной проигранной партии
    win_ex = next((j for j in val_idx if won[j] > 0.5), val_idx[0])
    lose_ex = next((j for j in val_idx if won[j] < 0.5), val_idx[0])
    plt.figure(figsize=(8, 5))
    for j, lbl, color in [(win_ex, "Победа", "green"), (lose_ex, "Поражение", "red")]:
        x = torch.from_numpy(seqs[j]).unsqueeze(0).to(device)
        with torch.no_grad():
            logits, _ = model(x)
            probs = torch.sigmoid(logits)[0].cpu().numpy()
        plt.plot(range(1, len(probs) + 1), probs * 100, marker="o", ms=3,
                 label=lbl, color=color)
    plt.axhline(50, color="gray", ls="--", lw=1)
    plt.ylim(0, 100)
    plt.xlabel("Ход игрока")
    plt.ylabel("P(победа), %")
    plt.title("LSTM-коуч: динамика вероятности победы")
    plt.legend()
    plt.grid(alpha=0.3)
    out = os.path.join(ART, "coach_winprob_example.png")
    plt.savefig(out, dpi=130, bbox_inches="tight")
    print("График примера сохранён:", out)


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=15)
    ap.add_argument("--batch", type=int, default=128)
    ap.add_argument("--lr", type=float, default=1e-3)
    return ap.parse_args()


if __name__ == "__main__":
    train(parse_args())
