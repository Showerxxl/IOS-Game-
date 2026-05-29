"""
Обучение DQN-агента для «Котозрыва» через self-play + игру против эвристики.

Ключевые приёмы:
  - Target network (стабилизация TD-таргета).
  - Replay buffer (декорреляция переходов).
  - Epsilon-greedy с маскированием нелегальных действий.
  - Пул оппонентов: эвристика + замороженные снапшоты самого агента (self-play),
    чтобы агент учился против всё более сильных противников.
  - Периодическая оценка против random и heuristic -> кривые обучения.
  - Сохранение чекпойнтов на 10% / 50% / 100% обучения -> 3 уровня сложности бота.

Запуск:
    cd ML && source .venv/bin/activate
    python3 train_dqn.py --steps 400000 --players 2

Артефакты складываются в ML/checkpoints/ и ML/artifacts/.
"""
from __future__ import annotations

import argparse
import os
import random
import time
from collections import deque

import numpy as np
import torch
import torch.nn as nn

from game.env import KotozryvEnv, encode_observation, OBS_DIM
from game.engine import KotozryvGame, NUM_ACTIONS, A_DRAW
from agents.baselines import make_random, make_heuristic
from model import QNetwork

CKPT_DIR = os.path.join(os.path.dirname(__file__), "checkpoints")
ART_DIR = os.path.join(os.path.dirname(__file__), "artifacts")
os.makedirs(CKPT_DIR, exist_ok=True)
os.makedirs(ART_DIR, exist_ok=True)

NEG_INF = -1e9


def masked_argmax(q: np.ndarray, mask: np.ndarray) -> int:
    q = q.copy()
    q[~mask] = NEG_INF
    return int(np.argmax(q))


def greedy_policy_from_net(net: QNetwork, device):
    """Возвращает policy(game, player) на основе текущих весов сети."""
    def policy(game: KotozryvGame, player):
        obs = encode_observation(game, player)
        mask = np.array(game.legal_mask(player), dtype=bool)
        with torch.no_grad():
            q = net(torch.from_numpy(obs).to(device).unsqueeze(0)).cpu().numpy()[0]
        return masked_argmax(q, mask)
    return policy


class ReplayBuffer:
    def __init__(self, capacity: int):
        self.buf = deque(maxlen=capacity)

    def push(self, s, a, r, s2, done, mask2):
        self.buf.append((s, a, r, s2, done, mask2))

    def sample(self, batch_size: int):
        batch = random.sample(self.buf, batch_size)
        s, a, r, s2, done, mask2 = zip(*batch)
        return (
            torch.tensor(np.array(s), dtype=torch.float32),
            torch.tensor(a, dtype=torch.int64),
            torch.tensor(r, dtype=torch.float32),
            torch.tensor(np.array(s2), dtype=torch.float32),
            torch.tensor(done, dtype=torch.float32),
            torch.tensor(np.array(mask2), dtype=torch.bool),
        )

    def __len__(self):
        return len(self.buf)


def evaluate(net, device, num_players, opponent_factory, n_games=400, seed=12345):
    """Win rate агента (perspective P0) против заданного оппонента."""
    rng = random.Random(seed)
    policy = greedy_policy_from_net(net, device)
    wins = 0
    for _ in range(n_games):
        env = KotozryvEnv(num_players=num_players,
                          opponent_policy=opponent_factory(rng.randint(0, 10**9)),
                          rng=random.Random(rng.randint(0, 10**9)))
        obs, mask = env.reset()
        done = False
        while not done:
            a = masked_argmax(
                net(torch.from_numpy(obs).to(device).unsqueeze(0))
                .detach().cpu().numpy()[0], mask)
            obs, reward, done, info = env.step(a)
            mask = info["mask"]
        if info["winner"] == 0:
            wins += 1
    return wins / n_games


def make_opponent(pool, heuristic_prob, rng, device):
    """С вероятностью heuristic_prob — эвристика, иначе — снапшот из пула."""
    if not pool or rng.random() < heuristic_prob:
        return make_heuristic(rng.randint(0, 10**9))
    snap = rng.choice(pool)
    return greedy_policy_from_net(snap, device)


def train(args):
    device = torch.device("cpu")  # MLP крошечная, CPU быстрее из-за оверхеда MPS
    torch.manual_seed(args.seed)
    np.random.seed(args.seed)
    random.seed(args.seed)

    net = QNetwork().to(device)
    target = QNetwork().to(device)
    target.load_state_dict(net.state_dict())
    target.eval()

    opt = torch.optim.Adam(net.parameters(), lr=args.lr)
    buffer = ReplayBuffer(args.buffer)
    rng = random.Random(args.seed)

    snapshots = []  # пул замороженных версий для self-play
    history = {"step": [], "wr_random": [], "wr_heuristic": []}

    eps_start, eps_end = 1.0, 0.05
    eps_decay_steps = int(args.steps * 0.6)

    # чекпойнты для уровней сложности
    milestones = {int(args.steps * f): name
                  for f, name in [(0.10, "easy"), (0.50, "medium"), (1.0, "hard")]}

    def current_eps(step):
        if step >= eps_decay_steps:
            return eps_end
        frac = step / eps_decay_steps
        return eps_start + frac * (eps_end - eps_start)

    # окружение пересоздаётся при каждой новой партии со свежим оппонентом
    def new_env():
        opp = make_opponent(snapshots, args.heuristic_prob, rng, device)
        return KotozryvEnv(num_players=args.players, opponent_policy=opp,
                           rng=random.Random(rng.randint(0, 10**9)))

    env = new_env()
    obs, mask = env.reset()

    t0 = time.time()
    losses = deque(maxlen=1000)

    for step in range(1, args.steps + 1):
        eps = current_eps(step)
        # выбор действия (epsilon-greedy с маской)
        if random.random() < eps:
            legal = np.flatnonzero(mask)
            a = int(random.choice(legal))
        else:
            with torch.no_grad():
                q = net(torch.from_numpy(obs).to(device).unsqueeze(0)).cpu().numpy()[0]
            a = masked_argmax(q, mask)

        obs2, reward, done, info = env.step(a)
        mask2 = info["mask"]
        buffer.push(obs, a, reward, obs2, float(done), mask2)

        obs, mask = obs2, mask2

        if done:
            env = new_env()
            obs, mask = env.reset()

        # обучение
        if len(buffer) >= args.warmup:
            s, acts, r, s2, d, m2 = buffer.sample(args.batch)
            s, acts, r, s2, d, m2 = (x.to(device) for x in (s, acts, r, s2, d, m2))

            q = net(s).gather(1, acts.unsqueeze(1)).squeeze(1)
            with torch.no_grad():
                q_next = target(s2)
                q_next[~m2] = NEG_INF
                # если в s2 нет легальных действий (терминал) — max даст NEG_INF,
                # но там d=1, поэтому target = r и слагаемое зануляется.
                max_next = q_next.max(dim=1).values
                max_next = torch.nan_to_num(max_next, neginf=0.0)
                tgt = r + args.gamma * max_next * (1.0 - d)
            loss = nn.functional.smooth_l1_loss(q, tgt)

            opt.zero_grad()
            loss.backward()
            nn.utils.clip_grad_norm_(net.parameters(), 10.0)
            opt.step()
            losses.append(loss.item())

        # обновление target-сети
        if step % args.target_update == 0:
            target.load_state_dict(net.state_dict())

        # пополнение пула снапшотов для self-play
        if step % args.snapshot_every == 0 and len(buffer) >= args.warmup:
            snap = QNetwork().to(device)
            snap.load_state_dict(net.state_dict())
            snap.eval()
            snapshots.append(snap)
            if len(snapshots) > args.pool_size:
                snapshots.pop(0)

        # оценка + лог
        if step % args.eval_every == 0:
            wr_r = evaluate(net, device, args.players, make_random, n_games=args.eval_games)
            wr_h = evaluate(net, device, args.players, make_heuristic, n_games=args.eval_games)
            history["step"].append(step)
            history["wr_random"].append(wr_r)
            history["wr_heuristic"].append(wr_h)
            avg_loss = np.mean(losses) if losses else 0.0
            sps = step / (time.time() - t0)
            print(f"step {step:>7}/{args.steps}  eps={eps:.2f}  "
                  f"loss={avg_loss:.4f}  WR vs random={wr_r:.1%}  "
                  f"WR vs heuristic={wr_h:.1%}  ({sps:.0f} steps/s, "
                  f"pool={len(snapshots)})")

        # чекпойнты уровней сложности
        if step in milestones:
            name = milestones[step]
            path = os.path.join(CKPT_DIR, f"dqn_{name}.pt")
            torch.save(net.state_dict(), path)
            print(f"  -> сохранён чекпойнт уровня '{name}': {path}")

    # финал
    torch.save(net.state_dict(), os.path.join(CKPT_DIR, "dqn_final.pt"))
    np.savez(os.path.join(ART_DIR, "training_history.npz"),
             step=np.array(history["step"]),
             wr_random=np.array(history["wr_random"]),
             wr_heuristic=np.array(history["wr_heuristic"]))
    _plot_history(history)
    print("\nГотово. Чекпойнты в checkpoints/, графики в artifacts/.")


def _plot_history(history):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except Exception as e:
        print("matplotlib недоступен, график пропущен:", e)
        return
    plt.figure(figsize=(8, 5))
    plt.plot(history["step"], [w * 100 for w in history["wr_random"]],
             label="vs Random", marker="o", ms=3)
    plt.plot(history["step"], [w * 100 for w in history["wr_heuristic"]],
             label="vs Heuristic", marker="s", ms=3)
    plt.axhline(50, color="gray", ls="--", lw=1, label="50% (равная игра 2p)")
    plt.xlabel("Шаги обучения")
    plt.ylabel("Win Rate, %")
    plt.title("DQN-агент «Котозрыв»: win rate по ходу обучения")
    plt.legend()
    plt.grid(alpha=0.3)
    out = os.path.join(ART_DIR, "winrate_curve.png")
    plt.savefig(out, dpi=130, bbox_inches="tight")
    print("График сохранён:", out)


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", type=int, default=400000)
    ap.add_argument("--players", type=int, default=2)
    ap.add_argument("--lr", type=float, default=5e-4)
    ap.add_argument("--gamma", type=float, default=0.99)
    ap.add_argument("--batch", type=int, default=128)
    ap.add_argument("--buffer", type=int, default=100000)
    ap.add_argument("--warmup", type=int, default=2000)
    ap.add_argument("--target-update", type=int, default=1000)
    ap.add_argument("--eval-every", type=int, default=20000)
    ap.add_argument("--eval-games", type=int, default=300)
    ap.add_argument("--snapshot-every", type=int, default=25000)
    ap.add_argument("--pool-size", type=int, default=5)
    ap.add_argument("--heuristic-prob", type=float, default=0.5)
    ap.add_argument("--seed", type=int, default=0)
    return ap.parse_args()


if __name__ == "__main__":
    train(parse_args())
