"""
Генерация датасета партий для обучения LSTM-коуча.

Для каждой партии выбираем одного «подопечного» игрока, который ходит
СМЕШАННОЙ политикой (random + heuristic + DQN с шумом) — так получаются
реалистичные траектории с ошибками. На каждом ЕГО ходу записываем:

  - obs (31)                  — состояние с его точки зрения;
  - action_onehot (8)         — что он реально сходил;
  - dqn_best (int)            — что посоветовал бы DQN-оракул (argmax по маске);
  - good_move (0/1)           — совпал ли ход с топ-действием DQN.

Метка последовательности:
  - won (0/1)                 — победил ли подопечный в этой партии.

Сохраняется в ML/coach/coach_dataset.npz:
  sequences  : object-массив [N] -> ndarray (T_i, 39)  признаки на шаг
  good_moves : object-массив [N] -> ndarray (T_i,)      метка качества хода
  dqn_best   : object-массив [N] -> ndarray (T_i,)      рекомендация оракула
  actions    : object-массив [N] -> ndarray (T_i,)      реальные действия
  won        : ndarray [N]                              исход партии

Запуск:
    cd ML && source .venv/bin/activate
    python3 gen_coach_dataset.py --games 60000 --ckpt checkpoints/dqn_final.pt
"""
from __future__ import annotations

import argparse
import os
import random

import numpy as np
import torch

from game.engine import KotozryvGame, NUM_ACTIONS, A_DRAW
from game.env import encode_observation, OBS_DIM
from agents.baselines import make_random, make_heuristic
from model import QNetwork

OUT_DIR = os.path.join(os.path.dirname(__file__), "coach")
os.makedirs(OUT_DIR, exist_ok=True)

NEG_INF = -1e9


def masked_argmax(q, mask):
    q = q.copy()
    q[~mask] = NEG_INF
    return int(np.argmax(q))


def load_dqn(ckpt):
    net = QNetwork()
    net.load_state_dict(torch.load(ckpt, map_location="cpu"))
    net.eval()
    return net


def dqn_qvalues(net, game, player):
    obs = encode_observation(game, player)
    with torch.no_grad():
        q = net(torch.from_numpy(obs).unsqueeze(0)).numpy()[0]
    return obs, q


def mixed_policy(net, rng):
    """Политика подопечного: смесь случайности, эвристики и DQN — даёт ошибки."""
    heur = make_heuristic(rng.randint(0, 10**9))

    def policy(game, player):
        r = rng.random()
        mask = np.array(game.legal_mask(player), dtype=bool)
        legal = np.flatnonzero(mask)
        if r < 0.25:                       # 25% полностью случайно
            return int(rng.choice(legal))
        if r < 0.55:                       # 30% эвристика
            return heur(game, player)
        # 45% DQN, иногда с шумом
        _, q = dqn_qvalues(net, game, player)
        if rng.random() < 0.15:
            return int(rng.choice(legal))
        return masked_argmax(q, mask)

    return policy


def generate(args):
    rng = random.Random(args.seed)
    net = load_dqn(args.ckpt)

    sequences, good_moves_all, dqn_best_all, actions_all, won_all = [], [], [], [], []

    for gi in range(args.games):
        num_players = rng.choice([2, 2, 3, 4])  # чаще 2p (как обучен DQN)
        g = KotozryvGame(num_players=num_players,
                         rng=random.Random(rng.randint(0, 10**9)))
        coachee = 0  # подопечный — игрок 0
        policy = mixed_policy(net, rng)
        opp = make_heuristic(rng.randint(0, 10**9))

        seq, goods, bests, acts = [], [], [], []
        guard = 0
        while not g.game_over and guard < 5000:
            guard += 1
            p = g.cur_player()
            mask = np.array(g.legal_mask(p), dtype=bool)
            if p.idx == coachee:
                obs, q = dqn_qvalues(net, g, p)
                a = policy(g, p)
                if not mask[a]:
                    a = A_DRAW
                best = masked_argmax(q, mask)
                onehot = np.zeros(NUM_ACTIONS, dtype=np.float32)
                onehot[a] = 1.0
                seq.append(np.concatenate([obs, onehot]))
                acts.append(a)
                bests.append(best)
                goods.append(1.0 if a == best else 0.0)
            else:
                a = opp(g, p)
                if not mask[a]:
                    a = A_DRAW
            g.play_action(a)

        if not seq:
            continue
        won = 1.0 if g.winner == coachee else 0.0
        sequences.append(np.array(seq, dtype=np.float32))
        good_moves_all.append(np.array(goods, dtype=np.float32))
        dqn_best_all.append(np.array(bests, dtype=np.int64))
        actions_all.append(np.array(acts, dtype=np.int64))
        won_all.append(won)

        if (gi + 1) % 5000 == 0:
            wr = np.mean(won_all)
            avg_good = np.mean([g.mean() for g in good_moves_all])
            print(f"  партий: {gi+1}/{args.games}  winrate подопечного={wr:.1%}  "
                  f"доля 'хороших' ходов={avg_good:.1%}")

    out = os.path.join(OUT_DIR, "coach_dataset.npz")
    np.savez(
        out,
        sequences=np.array(sequences, dtype=object),
        good_moves=np.array(good_moves_all, dtype=object),
        dqn_best=np.array(dqn_best_all, dtype=object),
        actions=np.array(actions_all, dtype=object),
        won=np.array(won_all, dtype=np.float32),
        feat_dim=OBS_DIM + NUM_ACTIONS,
    )
    print(f"\nГотово. Сохранено {len(sequences)} партий в {out}")
    print(f"Размерность признака на шаг: {OBS_DIM + NUM_ACTIONS}")


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--games", type=int, default=60000)
    ap.add_argument("--ckpt", default="checkpoints/dqn_final.pt")
    ap.add_argument("--seed", type=int, default=1)
    return ap.parse_args()


if __name__ == "__main__":
    generate(parse_args())
