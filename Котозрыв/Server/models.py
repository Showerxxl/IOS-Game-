from __future__ import annotations
import uuid
import random
from enum import Enum
from dataclasses import dataclass, field
from typing import Optional



class CardType(str, Enum):
    EXPLODING_KITTEN = "exploding_kitten"   # Взрывной котенок
    DEFUSE           = "defuse"             # Обезвредь
    NOPE             = "nope"               # Неть
    ATTACK           = "attack"             # Нападай
    SKIP             = "skip"               # Слиняй
    FAVOR            = "favor"              # Подлижись
    SHUFFLE          = "shuffle"            # Затасуй
    SEE_THE_FUTURE   = "see_the_future"     # Подсмотри грядущее
    # Кошкокарты
    CAT_TACO         = "cat_taco"
    CAT_WATERMELON   = "cat_watermelon"
    CAT_BEARD        = "cat_beard"
    CAT_POTATO       = "cat_potato"

    @property
    def playable(self) -> bool:
        return self not in (CardType.EXPLODING_KITTEN, CardType.DEFUSE)

    @property
    def display_name(self) -> str:
        names = {
            CardType.EXPLODING_KITTEN: "Взрывной котенок",
            CardType.DEFUSE:           "Обезвредь",
            CardType.NOPE:             "Неть",
            CardType.ATTACK:           "Нападай",
            CardType.SKIP:             "Слиняй",
            CardType.FAVOR:            "Подлижись",
            CardType.SHUFFLE:          "Затасуй",
            CardType.SEE_THE_FUTURE:   "Подсмотри грядущее",
            CardType.CAT_TACO:         "Кот-Повар",
            CardType.CAT_WATERMELON:   "Кот-Тако",
            CardType.CAT_BEARD:        "Кот-Борода",
            CardType.CAT_POTATO:       "Кот-Картошка",
        }
        return names[self]



@dataclass
class Card:
    card_type: CardType
    id: str = field(default_factory=lambda: str(uuid.uuid4()))

    def to_dict(self, hidden: bool = False) -> dict:
        if hidden:
            return {"id": self.id, "hidden": True}
        return {
            "id": self.id,
            "type": self.card_type.value,
            "name": self.card_type.display_name,
            "playable": self.card_type.playable,
        }



@dataclass
class Player:
    player_id: str
    name: str
    hand: list[Card] = field(default_factory=list)
    alive: bool = True
    turns_remaining: int = 1

    def has_card_type(self, card_type: CardType) -> bool:
        return any(c.card_type == card_type for c in self.hand)

    def take_card(self, card_id: str) -> Optional[Card]:
        for i, card in enumerate(self.hand):
            if card.id == card_id:
                return self.hand.pop(i)
        return None

    def take_card_of_type(self, card_type: CardType) -> Optional[Card]:
        for i, card in enumerate(self.hand):
            if card.card_type == card_type:
                return self.hand.pop(i)
        return None

    def add_card(self, card: Card) -> None:
        self.hand.append(card)

    def to_dict(self, for_player_id: Optional[str] = None) -> dict:
        is_owner = for_player_id == self.player_id
        return {
            "player_id":       self.player_id,
            "name":            self.name,
            "alive":           self.alive,
            "card_count":      len(self.hand),
            "turns_remaining": self.turns_remaining,
            "hand": [c.to_dict(hidden=False) for c in self.hand] if is_owner
                    else [c.to_dict(hidden=True) for c in self.hand],
        }




class RoomStatus(str, Enum):
    WAITING  = "waiting"
    PLAYING  = "playing"
    FINISHED = "finished"


@dataclass
class Room:
    room_id: str = field(default_factory=lambda: str(uuid.uuid4())[:6].upper())
    players: list[Player] = field(default_factory=list)
    status: RoomStatus = RoomStatus.WAITING
    max_players: int = 5
    game_state: Optional["GameState"] = None

    @property
    def host_id(self) -> Optional[str]:
        return self.players[0].player_id if self.players else None

    def get_player(self, player_id: str) -> Optional[Player]:
        return next((p for p in self.players if p.player_id == player_id), None)

    def to_dict(self) -> dict:
        return {
            "room_id":     self.room_id,
            "status":      self.status.value,
            "max_players": self.max_players,
            "player_count": len(self.players),
            "players": [
                {"player_id": p.player_id, "name": p.name}
                for p in self.players
            ],
        }


class GameState:
    def __init__(self, players: list[Player]):
        self.players: list[Player] = players
        self.deck: list[Card] = []
        self.discard: list[Card] = []
        self.current_player_index: int = 0
        self.winner: Optional[Player] = None
        self.finished: bool = False
        self._build_deck()
        self._deal()


    def _build_deck(self) -> None:
        cards: list[Card] = []
        composition = {
            CardType.NOPE:           5,
            CardType.ATTACK:         4,
            CardType.SKIP:           4,
            CardType.FAVOR:          4,
            CardType.SHUFFLE:        4,
            CardType.SEE_THE_FUTURE: 5,
            CardType.CAT_TACO:       4,
            CardType.CAT_WATERMELON: 4,
            CardType.CAT_BEARD:      4,
            CardType.CAT_POTATO:     4,
        }
        for card_type, count in composition.items():
            cards.extend(Card(card_type) for _ in range(count))
        random.shuffle(cards)
        self.deck = cards

    def _deal(self) -> None:
        n = len(self.players)
        for player in self.players:
            for _ in range(7):
                player.add_card(self.deck.pop())
            player.add_card(Card(CardType.DEFUSE))

     
        extra_defuse = 2 if n <= 3 else max(0, n - 1)
        for _ in range(extra_defuse):
            self.deck.append(Card(CardType.DEFUSE))

  
        for _ in range(n - 1):
            self.deck.append(Card(CardType.EXPLODING_KITTEN))

        random.shuffle(self.deck)


    @property
    def current_player(self) -> Player:
        return self.players[self.current_player_index]

    @property
    def alive_players(self) -> list[Player]:
        return [p for p in self.players if p.alive]

    def _next_alive_index(self) -> int:
        n = len(self.players)
        idx = (self.current_player_index + 1) % n
        while not self.players[idx].alive:
            idx = (idx + 1) % n
        return idx

    def advance_turn(self) -> None:
        cp = self.current_player

        if not cp.alive:
            cp.turns_remaining = 1
            self.current_player_index = self._next_alive_index()
        else:
            cp.turns_remaining -= 1
            if cp.turns_remaining <= 0:
                cp.turns_remaining = 1
                self.current_player_index = self._next_alive_index()
        alive = self.alive_players
        if len(alive) == 1:
            self.winner = alive[0]
            self.finished = True

    def draw_card(self) -> Card:
        if not self.deck:
            raise ValueError("Колода пуста")
        return self.deck.pop()

    def top_of_deck(self, n: int = 3) -> list[Card]:
        return list(reversed(self.deck[-n:])) if len(self.deck) >= n else list(reversed(self.deck))

    def insert_card_at(self, card: Card, position: str) -> None:
        """position: 'top' | 'bottom' | 'random'"""
        if position == "top":
            self.deck.append(card)
        elif position == "bottom":
            self.deck.insert(0, card)
        else:
            idx = random.randint(0, len(self.deck))
            self.deck.insert(idx, card)


    def to_dict(self, for_player_id: Optional[str] = None) -> dict:
        return {
            "deck_size":        len(self.deck),
            "discard_size":     len(self.discard),
            "top_discard_card": self.discard[-1].to_dict() if self.discard else None,
            "current_player_id": self.current_player.player_id,
            "finished":         self.finished,
            "winner_id":        self.winner.player_id if self.winner else None,
            "players": [p.to_dict(for_player_id=for_player_id) for p in self.players],
        }
