"""
Определения карт игры «Котозрыв» (клон Exploding Kittens).

Карты кодируются целочисленными id, чтобы их было удобно подавать
в нейросеть и кодировать состояние одним вектором.

Состав колоды и правила раздачи полностью повторяют Swift-реализацию
(GameScreenInteractor.createInitialDeck / dealInitialCards / addDefuse / addExploding).
"""

# --- Идентификаторы типов карт (соответствуют CardType.swift) ---
EXPLODING = 0
DEFUSE = 1
NOPE = 2
ATTACK = 3
SKIP = 4
FAVOR = 5
SHUFFLE = 6
SEE_FUTURE = 7
CAT_BEARD = 8
CAT_TACO = 9
CAT_WATERMELON = 10
CAT_POTATO = 11

NUM_CARD_TYPES = 12

CAT_TYPES = (CAT_BEARD, CAT_TACO, CAT_WATERMELON, CAT_POTATO)

CARD_NAMES = {
    EXPLODING: "Exploding",
    DEFUSE: "Defuse",
    NOPE: "Nope",
    ATTACK: "Attack",
    SKIP: "Skip",
    FAVOR: "Favor",
    SHUFFLE: "Shuffle",
    SEE_FUTURE: "SeeTheFuture",
    CAT_BEARD: "CatBeard",
    CAT_TACO: "CatTaco",
    CAT_WATERMELON: "CatWatermelon",
    CAT_POTATO: "CatPotato",
}


def is_cat(card: int) -> bool:
    return card in CAT_TYPES


def can_be_noped(card: int) -> bool:
    # В Swift: всё, кроме explodingKitten и defuse, можно «нетнуть».
    return card not in (EXPLODING, DEFUSE)


def build_base_deck() -> list[int]:
    """Базовая колода ДО раздачи (без exploding и без доп. defuse)."""
    deck: list[int] = []
    deck += [NOPE] * 5
    deck += [ATTACK] * 4
    deck += [SKIP] * 4
    deck += [FAVOR] * 4
    deck += [SHUFFLE] * 4
    deck += [SEE_FUTURE] * 5
    for cat in CAT_TYPES:
        deck += [cat] * 4
    return deck  # длина = 5+4+4+4+4+5+16 = 42


def defuse_count_for(player_count: int) -> int:
    """Сколько defuse добавляется в колоду (Swift addDefuseCards)."""
    return 2 if player_count <= 3 else (6 - player_count)


def exploding_count_for(player_count: int) -> int:
    """Сколько взрывных котят кладётся в колоду (Swift addExplodingKittens)."""
    return player_count - 1
