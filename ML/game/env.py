"""
Кодирование состояния (observation) и gym-подобная среда для обучения.

Observation — это вектор фиксированной длины OBS_DIM, описывающий игру
С ТОЧКИ ЗРЕНИЯ конкретного игрока (включая его приватное знание после
See the Future). Тот же кодировщик потом используется в Swift (MLBotService),
поэтому раскладка вектора зафиксирована и задокументирована ниже.

Раскладка observation (всего 31 значение):
  [0..11]  hand_counts      — кол-во карт каждого из 12 типов в руке (норм. /4)
  [12]     has_defuse       — есть ли defuse (0/1)
  [13]     hand_total       — размер руки (норм. /15)
  [14]     deck_size        — размер колоды (норм. /40)
  [15]     exploding_known  — взрывных котят в колоде (норм. /4)
  [16]     danger_score     — exploding / deck_size
  [17]     stf_valid        — актуально ли знание верхних карт (0/1)
  [18..20] stf_top_explode  — для топ-1/2/3: это взрывной котёнок? (0/1)
  [21]     turns_remaining  — сколько ходов осталось текущему (норм. /3)
  [22]     alive_count      — живых игроков (норм. /5)
  [23..26] opp_hand_sizes   — размеры рук соперников (до 4, отсорт. убыв., /15)
  [27..30] opp_alive        — флаги «слот соперника занят живым игроком» (0/1)
"""
from __future__ import annotations

import numpy as np

from . import cards
from .engine import KotozryvGame, PlayerState, NUM_ACTIONS, A_DRAW
from .cards import EXPLODING, DEFUSE, NUM_CARD_TYPES

OBS_DIM = 31
MAX_OPP = 4


def encode_observation(game: KotozryvGame, player: PlayerState) -> np.ndarray:
    obs = np.zeros(OBS_DIM, dtype=np.float32)

    # [0..11] hand counts
    for c in player.hand:
        obs[c] += 1.0
    obs[0:NUM_CARD_TYPES] /= 4.0

    # [12] has defuse
    obs[12] = 1.0 if player.has(DEFUSE) else 0.0
    # [13] hand total
    obs[13] = min(len(player.hand), 15) / 15.0
    # [14] deck size
    obs[14] = min(len(game.deck), 40) / 40.0
    # [15] exploding known in deck
    obs[15] = min(game.exploding_in_deck(), 4) / 4.0
    # [16] danger score
    obs[16] = game.danger_score()

    # [17..20] see-the-future knowledge
    if player.known_top:
        obs[17] = 1.0
        for i in range(min(3, len(player.known_top))):
            obs[18 + i] = 1.0 if player.known_top[i] == EXPLODING else 0.0

    # [21] turns remaining
    obs[21] = min(player.turns_remaining, 3) / 3.0
    # [22] alive count
    obs[22] = len(game.alive_players()) / 5.0

    # [23..30] opponents
    opp_sizes = sorted(
        (len(q.hand) for q in game.players
         if q.idx != player.idx and q.alive),
        reverse=True,
    )
    for i in range(min(MAX_OPP, len(opp_sizes))):
        obs[23 + i] = min(opp_sizes[i], 15) / 15.0
        obs[27 + i] = 1.0
    return obs


class KotozryvEnv:
    """
    Среда для обучения ОДНОГО агента (perspective player = 0).
    Остальные игроки управляются переданными политиками opponent_policies.

    API в духе Gym:
      obs, mask = env.reset()
      obs, reward, done, info = env.step(action)

    Награда: +1 за победу, -1 за гибель, иначе 0.
    На каждом шаге info["mask"] — булева маска легальных действий.
    """

    def __init__(self, num_players: int = 2, opponent_policy=None,
                 rng=None, enable_nope: bool = True, max_steps: int = 2000):
        import random
        self.num_players = num_players
        self.rng = rng or random.Random()
        self.enable_nope = enable_nope
        self.max_steps = max_steps
        # opponent_policy(game, player) -> action_id
        self.opponent_policy = opponent_policy or (lambda g, p: A_DRAW)
        self.game: KotozryvGame | None = None
        self.agent_idx = 0
        self._steps = 0

    def reset(self):
        self.game = KotozryvGame(
            num_players=self.num_players, rng=self.rng,
            enable_nope=self.enable_nope)
        self.agent_idx = 0
        self._steps = 0
        self._run_until_agent_turn()
        return self._obs(), self._mask()

    def _agent(self) -> PlayerState:
        return self.game.players[self.agent_idx]

    def _obs(self) -> np.ndarray:
        return encode_observation(self.game, self._agent())

    def _mask(self):
        return np.array(self.game.legal_mask(self._agent()), dtype=bool)

    def _run_until_agent_turn(self) -> None:
        """Прогоняет ходы оппонентов, пока снова не наступит ход агента
        (или игра не закончится / агент не погибнет)."""
        g = self.game
        guard = 0
        while not g.game_over and g.current != self.agent_idx:
            guard += 1
            if guard > self.max_steps:
                break
            p = g.cur_player()
            action = self.opponent_policy(g, p)
            mask = g.legal_mask(p)
            if not mask[action]:
                action = A_DRAW
            g.play_action(action)

    def step(self, action: int):
        g = self.game
        self._steps += 1

        mask = g.legal_mask(self._agent())
        if not mask[action]:
            action = A_DRAW  # защита от нелегального действия

        agent = self._agent()
        was_alive = agent.alive
        g.play_action(action)

        # дать сходить оппонентам, пока не вернётся ход агенту
        self._run_until_agent_turn()

        done = g.game_over or (not agent.alive) or (self._steps >= self.max_steps)

        reward = 0.0
        if g.game_over and g.winner == self.agent_idx:
            reward = 1.0
        elif not agent.alive and was_alive:
            reward = -1.0
        elif g.game_over and g.winner != self.agent_idx:
            reward = -1.0

        info = {"mask": self._mask(), "winner": g.winner}
        return self._obs(), reward, done, info
