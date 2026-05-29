"""
Базовые политики-оппоненты для обучения и оценки RL-агента.

  random_policy    — случайное легальное действие (нижняя планка).
  heuristic_policy — повторяет эвристику AI из GameScreenPresenter.swift
                     (реагирует на danger score и знание верхних карт).
"""
from __future__ import annotations

import random

from game.engine import (
    KotozryvGame, PlayerState,
    A_DRAW, A_ATTACK, A_SKIP, A_FAVOR, A_SHUFFLE, A_SEE_FUTURE,
    A_CAT_PAIR, A_CAT_TRIO,
)
from game.cards import EXPLODING


def make_random(seed: int | None = None):
    rng = random.Random(seed)

    def policy(game: KotozryvGame, p: PlayerState) -> int:
        legal = game.legal_actions(p)
        return rng.choice(legal)

    return policy


random_policy = make_random()


def make_heuristic(seed: int | None = None):
    rng = random.Random(seed)

    def policy(game: KotozryvGame, p: PlayerState) -> int:
        legal = set(game.legal_actions(p))
        danger = game.danger_score()
        knows_explosion_on_top = bool(p.known_top) and p.known_top[0] == EXPLODING

        def pick(*actions):
            for a in actions:
                if a in legal:
                    return a
            return None

        # 1) Если ТОЧНО знаем, что сверху взрыв — избегаем взятия.
        if knows_explosion_on_top:
            choice = pick(A_SKIP, A_ATTACK, A_SHUFFLE, A_CAT_TRIO, A_CAT_PAIR, A_FAVOR)
            if choice is not None:
                return choice
            return A_DRAW  # вынуждены, defuse спасёт если есть

        # 2) Высокая опасность — сбрасываем/уклоняемся.
        if danger >= 0.25:
            choice = pick(A_SHUFFLE, A_SKIP, A_ATTACK)
            if choice is not None:
                return choice

        # 3) Средняя опасность и нет знания — заглядываем в будущее.
        if danger >= 0.10 and not p.known_top:
            choice = pick(A_SEE_FUTURE)
            if choice is not None:
                return choice

        # 4) Низкая опасность — пробуем красть котами / favor.
        if danger < 0.10 and not knows_explosion_on_top:
            choice = pick(A_CAT_TRIO, A_CAT_PAIR)
            if choice is not None:
                return choice

        choice = pick(A_FAVOR)
        if choice is not None:
            return choice

        # 5) Иначе — берём карту.
        return A_DRAW

    return policy


heuristic_policy = make_heuristic()
