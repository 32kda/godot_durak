class_name GameModel
extends RefCounted

enum Suit { HEARTS, DIAMONDS, CLUBS, SPADES }
enum Rank { SIX = 6, SEVEN = 7, EIGHT = 8, NINE = 9, TEN = 10, JACK = 11, QUEEN = 12, KING = 13, ACE = 14 }
enum GameState { PLAYER_ATTACK, PLAYER_DEFEND, AI_ATTACK, AI_DEFEND, GAME_OVER }

var deck: Array[Card] = []
var player_hand: Array[Card] = []
var ai_hand: Array[Card] = []
var table_cards: Array[TableCard] = []
var trump_suit: Suit
var trump_card: Card
var current_state: GameState
var current_attacker_is_player: bool = true
var cards_to_beat: Array[Card] = []
var selected_card_to_beat_index: int = -1
var player_has_played_this_turn: bool = false

signal state_changed(new_state: GameState)
signal hands_updated()
signal table_updated()
signal deck_updated()
signal game_over(player_won: bool)
signal message_updated(msg: String)
signal request_ai_action()
signal card_to_beat_selected(index: int)

class Card:
	var suit: Suit
	var rank: Rank
	
	func _init(s: Suit, r: Rank):
		suit = s
		rank = r
	
	func get_texture_path() -> String:
		var suit_name: String
		match suit:
			Suit.HEARTS: suit_name = "hearts"
			Suit.DIAMONDS: suit_name = "diamonds"
			Suit.CLUBS: suit_name = "clubs"
			Suit.SPADES: suit_name = "spades"
		
		var rank_name: String
		match rank:
			Rank.SIX: rank_name = "6"
			Rank.SEVEN: rank_name = "7"
			Rank.EIGHT: rank_name = "8"
			Rank.NINE: rank_name = "9"
			Rank.TEN: rank_name = "10"
			Rank.JACK: rank_name = "jack"
			Rank.QUEEN: rank_name = "queen"
			Rank.KING: rank_name = "king"
			Rank.ACE: rank_name = "ace"
		
		return "res://images/%s_of_%s.png" % [rank_name, suit_name]
	
	func beats(other: Card, trump: Suit) -> bool:
		if suit == trump and other.suit != trump:
			return true
		if suit != trump and other.suit == trump:
			return false
		if suit != other.suit:
			return false
		return rank > other.rank
	
	func can_beat(attacking_card: Card, trump: Suit) -> bool:
		return beats(attacking_card, trump)

class TableCard:
	var attacking_card: Card
	var defending_card: Card = null
	
	func _init(card: Card):
		attacking_card = card

func _init():
	pass

func start_new_game():
	deck.clear()
	player_hand.clear()
	ai_hand.clear()
	table_cards.clear()
	cards_to_beat.clear()
	selected_card_to_beat_index = -1
	player_has_played_this_turn = false
	
	for s in [Suit.HEARTS, Suit.DIAMONDS, Suit.CLUBS, Suit.SPADES]:
		for r in [Rank.SIX, Rank.SEVEN, Rank.EIGHT, Rank.NINE, Rank.TEN, Rank.JACK, Rank.QUEEN, Rank.KING, Rank.ACE]:
			deck.append(Card.new(s, r))
	
	deck.shuffle()
	
	trump_card = deck.pop_back()
	trump_suit = trump_card.suit
	
	current_attacker_is_player = randf() > 0.5
	
	deal_cards()
	
	if current_attacker_is_player:
		current_state = GameState.PLAYER_ATTACK
	else:
		current_state = GameState.AI_ATTACK
	
	_emit_all_updates()
	
	if not current_attacker_is_player:
		emit_signal("request_ai_action")

func _emit_all_updates():
	emit_signal("state_changed", current_state)
	emit_signal("hands_updated")
	emit_signal("table_updated")
	emit_signal("deck_updated")
	emit_signal("message_updated", get_state_message())

func deal_cards():
	while player_hand.size() < 6 and deck.size() > 0:
		player_hand.append(deck.pop_back())
	while ai_hand.size() < 6 and deck.size() > 0:
		ai_hand.append(deck.pop_back())
	emit_signal("hands_updated")
	emit_signal("deck_updated")

func get_state_message() -> String:
	match current_state:
		GameState.PLAYER_ATTACK: return "Your turn to attack. Select cards to play or press Next Turn."
		GameState.PLAYER_DEFEND: return "You are defending. Beat the cards or press Next Turn to take."
		GameState.AI_ATTACK: return "AI is attacking..."
		GameState.AI_DEFEND: return "AI is defending..."
		GameState.GAME_OVER:
			if player_hand.is_empty() and deck.is_empty():
				return "Congratulations! You won!"
			else:
				return "Game Over! AI wins!"
	return ""

func player_play_card(card_index: int, target_card_to_beat_index: int = -1) -> bool:
	if card_index < 0 or card_index >= player_hand.size():
		return false
	
	var card = player_hand[card_index]
	
	match current_state:
		GameState.PLAYER_ATTACK:
			if table_cards.is_empty() or can_add_to_table(card):
				player_hand.erase(card)
				table_cards.append(TableCard.new(card))
				player_has_played_this_turn = true
				emit_signal("hands_updated")
				emit_signal("table_updated")
				return true
		GameState.PLAYER_DEFEND:
			var target_idx = target_card_to_beat_index if target_card_to_beat_index >= 0 else selected_card_to_beat_index
			if target_idx >= 0 and target_idx < table_cards.size():
				var tc = table_cards[target_idx]
				if tc.defending_card == null and card.can_beat(tc.attacking_card, trump_suit):
					player_hand.erase(card)
					tc.defending_card = card
					cards_to_beat.erase(tc.attacking_card)
					player_has_played_this_turn = true
					selected_card_to_beat_index = -1
					_auto_select_next_card_to_beat()
					emit_signal("hands_updated")
					emit_signal("table_updated")
					emit_signal("card_to_beat_selected", selected_card_to_beat_index)
					return true
	return false

func _auto_select_next_card_to_beat():
	if cards_to_beat.is_empty():
		selected_card_to_beat_index = -1
		return
	for i in range(table_cards.size()):
		if table_cards[i].defending_card == null:
			selected_card_to_beat_index = i
			return
	selected_card_to_beat_index = -1

func select_card_to_beat(table_index: int) -> bool:
	if current_state != GameState.PLAYER_DEFEND:
		return false
	if table_index < 0 or table_index >= table_cards.size():
		return false
	if table_cards[table_index].defending_card != null:
		return false
	selected_card_to_beat_index = table_index
	emit_signal("card_to_beat_selected", table_index)
	return true

func get_selected_card_to_beat_index() -> int:
	return selected_card_to_beat_index

func can_press_next_turn() -> bool:
	match current_state:
		GameState.PLAYER_ATTACK:
			return player_has_played_this_turn
		GameState.PLAYER_DEFEND:
			return true
	return false

func can_add_to_table(card: Card) -> bool:
	if table_cards.is_empty():
		return true
	var ranks_on_table = []
	for tc in table_cards:
		ranks_on_table.append(tc.attacking_card.rank)
		if tc.defending_card != null:
			ranks_on_table.append(tc.defending_card.rank)
	return card.rank in ranks_on_table

func get_valid_defense_cards() -> Array[int]:
	var valid_indices: Array[int] = []
	if current_state != GameState.PLAYER_DEFEND:
		return valid_indices
	if selected_card_to_beat_index < 0 or selected_card_to_beat_index >= table_cards.size():
		return valid_indices
	
	var tc = table_cards[selected_card_to_beat_index]
	if tc.defending_card != null:
		return valid_indices
	
	var card_to_beat = tc.attacking_card
	for i in range(player_hand.size()):
		if player_hand[i].can_beat(card_to_beat, trump_suit):
			valid_indices.append(i)
	return valid_indices

func player_next_turn():
	match current_state:
		GameState.PLAYER_ATTACK:
			if table_cards.is_empty():
				end_round_defender_becomes_attacker()
			else:
				transition_to_ai_defense()
		GameState.PLAYER_DEFEND:
			if any_unbeaten_on_table():
				player_take_cards()
			else:
				end_round_defender_becomes_attacker()

func any_unbeaten_on_table() -> bool:
	for tc in table_cards:
		if tc.defending_card == null:
			return true
	return false

func all_cards_beaten() -> bool:
	for tc in table_cards:
		if tc.defending_card == null:
			return false
	return true

func player_take_cards():
	for tc in table_cards:
		player_hand.append(tc.attacking_card)
		if tc.defending_card != null:
			player_hand.append(tc.defending_card)
	table_cards.clear()
	cards_to_beat.clear()
	selected_card_to_beat_index = -1
	
	deal_cards()
	
	if check_game_over():
		return
	
	current_state = GameState.AI_ATTACK
	current_attacker_is_player = false
	player_has_played_this_turn = false
	emit_signal("state_changed", current_state)
	emit_signal("hands_updated")
	emit_signal("table_updated")
	emit_signal("message_updated", get_state_message())
	emit_signal("request_ai_action")

func end_round_defender_becomes_attacker():
	table_cards.clear()
	cards_to_beat.clear()
	selected_card_to_beat_index = -1
	emit_signal("table_updated")
	
	deal_cards()
	
	if check_game_over():
		return
	
	current_attacker_is_player = not current_attacker_is_player
	
	if current_attacker_is_player:
		current_state = GameState.PLAYER_ATTACK
		player_has_played_this_turn = false
		emit_signal("state_changed", current_state)
		emit_signal("message_updated", get_state_message())
	else:
		current_state = GameState.AI_ATTACK
		emit_signal("state_changed", current_state)
		emit_signal("message_updated", get_state_message())
		emit_signal("request_ai_action")

func check_game_over() -> bool:
	if player_hand.is_empty() and deck.is_empty():
		current_state = GameState.GAME_OVER
		emit_signal("state_changed", current_state)
		emit_signal("game_over", true)
		emit_signal("message_updated", get_state_message())
		return true
	
	if ai_hand.is_empty() and deck.is_empty():
		current_state = GameState.GAME_OVER
		emit_signal("state_changed", current_state)
		emit_signal("game_over", false)
		emit_signal("message_updated", get_state_message())
		return true
	
	return false

func get_deck_size() -> int:
	return deck.size()

func ai_do_attack_step() -> bool:
	if current_state != GameState.AI_ATTACK:
		return false
	
	if check_game_over():
		return false
	
	var card_to_play = ai_select_attack_card()
	if card_to_play == null:
		ai_finish_attack()
		return false
	
	ai_hand.erase(card_to_play)
	table_cards.append(TableCard.new(card_to_play))
	emit_signal("hands_updated")
	emit_signal("table_updated")
	
	var unbeaten_count = table_cards.filter(func(tc): return tc.defending_card == null).size()
	if unbeaten_count >= player_hand.size():
		ai_finish_attack()
		return false
	
	return true

func ai_finish_attack():
	if table_cards.is_empty():
		end_round_defender_becomes_attacker()
	else:
		current_state = GameState.PLAYER_DEFEND
		cards_to_beat.clear()
		for tc in table_cards:
			if tc.defending_card == null:
				cards_to_beat.append(tc.attacking_card)
		player_has_played_this_turn = false
		_auto_select_next_card_to_beat()
		emit_signal("state_changed", current_state)
		emit_signal("card_to_beat_selected", selected_card_to_beat_index)
		emit_signal("message_updated", get_state_message())

func ai_select_attack() -> Card:
	if ai_hand.is_empty():
		return null
	
	var non_trump_cards = ai_hand.filter(func(c): return c.suit != trump_suit)
	if non_trump_cards.is_empty():
		return ai_hand[0]
	
	non_trump_cards.sort_custom(func(a, b): return a.rank < b.rank)
	return non_trump_cards[0]

func ai_select_attack_card() -> Card:
	if ai_hand.is_empty():
		return null
	
	if table_cards.is_empty():
		return ai_select_attack()
	
	for card in ai_hand:
		if can_add_to_table(card):
			return card
	
	return null

func ai_do_defend_step() -> bool:
	if current_state != GameState.AI_DEFEND:
		return false
	
	for tc in table_cards:
		if tc.defending_card == null:
			var defending_card = ai_find_defense(tc.attacking_card)
			if defending_card != null:
				ai_hand.erase(defending_card)
				tc.defending_card = defending_card
				emit_signal("hands_updated")
				emit_signal("table_updated")
				return true
			else:
				ai_take_cards()
				return false
	
	end_round_defender_becomes_attacker()
	return false

func ai_find_defense(attacking_card: Card) -> Card:
	var valid_cards = ai_hand.filter(func(c): return c.can_beat(attacking_card, trump_suit))
	if valid_cards.is_empty():
		return null
	
	valid_cards.sort_custom(func(a, b): return a.rank < b.rank)
	return valid_cards[0]

func ai_take_cards():
	for tc in table_cards:
		ai_hand.append(tc.attacking_card)
		if tc.defending_card != null:
			ai_hand.append(tc.defending_card)
	table_cards.clear()
	cards_to_beat.clear()
	
	deal_cards()
	
	if check_game_over():
		return
	
	current_state = GameState.PLAYER_ATTACK
	current_attacker_is_player = true
	emit_signal("state_changed", current_state)
	emit_signal("hands_updated")
	emit_signal("table_updated")
	emit_signal("message_updated", get_state_message())

func transition_to_ai_defense():
	current_state = GameState.AI_DEFEND
	emit_signal("state_changed", current_state)
	emit_signal("message_updated", get_state_message())
	emit_signal("request_ai_action")
