"""
Дымовой тест движка: гоняем партии между политиками и печатаем статистику.
Запуск:  cd ML && python3 test_engine.py
"""
import random
import time
from collections import Counter

from game.engine import KotozryvGame, ACTION_NAMES
from agents.baselines import make_random, make_heuristic


def play_one(num_players, policies, rng, max_turns=5000):
    g = KotozryvGame(num_players=num_players, rng=rng)
    guard = 0
    while not g.game_over and guard < max_turns:
        guard += 1
        p = g.cur_player()
        action = policies[p.idx](g, p)
        mask = g.legal_mask(p)
        if not mask[action]:
            action = 0  # DRAW
        g.play_action(action)
    return g


def benchmark(num_players, p0_factory, p1_factory, n_games=2000, seed=0):
    rng = random.Random(seed)
    wins = Counter()
    actions_used = Counter()
    finished = 0
    t0 = time.time()
    for _ in range(n_games):
        # игрок 0 = тестируемая политика, остальные = оппонент
        policies = [p0_factory(rng.randint(0, 10**9))]
        for _ in range(num_players - 1):
            policies.append(p1_factory(rng.randint(0, 10**9)))
        g = play_one(num_players, policies, rng)
        if g.game_over:
            finished += 1
            wins[g.winner] += 1
        for entry in g.turn_log:
            actions_used[ACTION_NAMES[entry["action"]]] += 1
    dt = time.time() - t0
    p0_winrate = wins[0] / n_games
    return p0_winrate, finished, dt, actions_used


if __name__ == "__main__":
    print("=== Котозрыв: дымовой тест движка ===\n")

    for n in (2, 3, 4, 5):
        wr, fin, dt, _ = benchmark(n, make_heuristic, make_random, n_games=1000)
        print(f"[{n} игрока] heuristic(P0) vs random:  winrate P0 = {wr:.1%}  "
              f"(завершено {fin}/1000, {dt:.1f}s)")

    print()
    # sanity: random vs random в 2p должно быть ~50%
    wr, fin, dt, acts = benchmark(2, make_random, make_random, n_games=2000)
    print(f"[2 игрока] random vs random:  winrate P0 = {wr:.1%}  (ожидаем ~50%)")

    print("\nЧастота действий (random vs random):")
    total = sum(acts.values())
    for name, cnt in acts.most_common():
        print(f"  {name:12s} {cnt/total:6.1%}")
