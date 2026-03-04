class_name GameUI
extends Control

var model: GameModel
var player_card_displays: Array[CardDisplay] = []
var ai_card_displays: Array[CardDisplay] = []
var table_attack_displays: Array[CardDisplay] = []
var table_defense_displays: Array[CardDisplay] = []
var selected_card_index: int = -1

var card_pile_display: TextureRect
var trump_display: CardDisplay
var message_label: Label
var next_turn_button: Button
var new_game_button: Button
var deck_count_label: Label

const CARD_SCALE: float = 0.25
const CARD_WIDTH: float = 70.0
var ai_timer: float = 0.0
var ai_action_pending: bool = false

func _ready():
	model = GameModel.new()
	model.state_changed.connect(_on_state_changed)
	model.hands_updated.connect(_on_hands_updated)
	model.table_updated.connect(_on_table_updated)
	model.deck_updated.connect(_on_deck_updated)
	model.game_over.connect(_on_game_over)
	model.message_updated.connect(_on_message_updated)
	model.request_ai_action.connect(_on_request_ai_action)
	model.card_to_beat_selected.connect(_on_card_to_beat_selected)
	
	_setup_ui()
	model.start_new_game()

func _setup_ui():
	card_pile_display = TextureRect.new()
	card_pile_display.name = "CardPile"
	card_pile_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_pile_display.set_scale(Vector2(0.2, 0.2))
	add_child(card_pile_display)
	
	var back_path = "res://images/player_card_back.png"
	if ResourceLoader.exists(back_path):
		card_pile_display.texture = load(back_path)
	
	trump_display = CardDisplay.new()
	trump_display.name = "TrumpCard"
	add_child(trump_display)
	
	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_stylebox_override("normal", _create_label_style())
	add_child(message_label)
	
	next_turn_button = Button.new()
	next_turn_button.name = "NextTurnButton"
	next_turn_button.text = "Next Turn"
	next_turn_button.pressed.connect(_on_next_turn_pressed)
	add_child(next_turn_button)
	
	new_game_button = Button.new()
	new_game_button.name = "NewGameButton"
	new_game_button.text = "New Game"
	new_game_button.pressed.connect(_on_new_game_pressed)
	new_game_button.visible = false
	add_child(new_game_button)
	
	deck_count_label = Label.new()
	deck_count_label.name = "DeckCountLabel"
	deck_count_label.add_theme_font_size_override("font_size", 16)
	deck_count_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(deck_count_label)

func _create_label_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _on_state_changed(new_state):
	_update_card_selectability()
	_clear_selection()
	_update_table_display()
	
	match new_state:
		GameModel.GameState.PLAYER_ATTACK, GameModel.GameState.PLAYER_DEFEND:
			_update_next_turn_button()
		GameModel.GameState.AI_ATTACK, GameModel.GameState.AI_DEFEND:
			next_turn_button.visible = false
			if not ai_action_pending:
				ai_action_pending = true
				ai_timer = 0.5
		GameModel.GameState.GAME_OVER:
			next_turn_button.visible = false
			new_game_button.visible = true

func _update_next_turn_button():
	next_turn_button.visible = model.can_press_next_turn()

func _on_card_to_beat_selected(_index: int):
	_update_table_display()
	_update_card_selectability()

func _on_hands_updated():
	_update_player_hand_display()
	_update_ai_hand_display()
	_update_card_selectability()
	_update_next_turn_button()

func _on_table_updated():
	_update_table_display()
	_update_next_turn_button()

func _on_deck_updated():
	_update_deck_display()

func _on_game_over(_player_won: bool):
	next_turn_button.visible = false
	new_game_button.visible = true

func _on_message_updated(msg: String):
	message_label.text = msg

func _on_request_ai_action():
	ai_action_pending = true
	ai_timer = 0.5

func _update_all_displays():
	_update_player_hand_display()
	_update_ai_hand_display()
	_update_table_display()
	_update_deck_display()
	_update_card_selectability()
	_position_ui_elements()

func _update_player_hand_display():
	for card_display in player_card_displays:
		card_display.queue_free()
	player_card_displays.clear()
	
	var hand = model.player_hand
	var card_size = _get_card_size()
	var total_width = _calculate_hand_width(hand.size())
	var start_x = (get_viewport().get_visible_rect().size.x - total_width) / 2
	var y = get_viewport().get_visible_rect().size.y - card_size.y - 20
	
	for i in range(hand.size()):
		var card = hand[i]
		var card_display = CardDisplay.new()
		card_display.setup(card.get_texture_path(), i, true)
		card_display.card_clicked.connect(_on_player_card_clicked)
		card_display.card_hovered.connect(_on_player_card_hovered)
		card_display.card_unhovered.connect(_on_player_card_unhovered)
		add_child(card_display)
		
		var x = start_x + i * CARD_WIDTH
		card_display.set_position(Vector2(x, y))
		card_display.original_position = Vector2(x, y)
		player_card_displays.append(card_display)

func _update_ai_hand_display():
	for card_display in ai_card_displays:
		card_display.queue_free()
	ai_card_displays.clear()
	
	var hand = model.ai_hand
	var card_size = _get_card_size()
	var total_width = _calculate_hand_width(hand.size())
	var start_x = (get_viewport().get_visible_rect().size.x - total_width) / 2
	var y = 15
	
	for i in range(hand.size()):
		var card_display = CardDisplay.new()
		card_display.setup_back(i)
		card_display.is_selectable = false
		add_child(card_display)
		
		var x = start_x + i * CARD_WIDTH
		card_display.set_position(Vector2(x, y))
		ai_card_displays.append(card_display)

func _update_table_display():
	for display in table_attack_displays:
		display.queue_free()
	for display in table_defense_displays:
		display.queue_free()
	table_attack_displays.clear()
	table_defense_displays.clear()
	
	var table = model.table_cards
	var card_size = _get_card_size()
	var viewport_size = get_viewport().get_visible_rect().size
	var center_y = viewport_size.y / 2 - card_size.y / 2
	
	var spacing = CARD_WIDTH * 1.2
	var total_table_width = table.size() * spacing
	var attack_x = viewport_size.x / 2 - total_table_width / 2
	
	var is_defending = model.current_state == GameModel.GameState.PLAYER_DEFEND
	var selected_idx = model.get_selected_card_to_beat_index()
	
	for i in range(table.size()):
		var tc = table[i]
		var attack_display = CardDisplay.new()
		attack_display.setup(tc.attacking_card.get_texture_path(), i, false)
		
		if is_defending and tc.defending_card == null:
			attack_display.is_selectable = true
			attack_display.mouse_filter = Control.MOUSE_FILTER_STOP
			attack_display.card_clicked.connect(_on_table_card_clicked)
			if i == selected_idx:
				attack_display.set_selected(true)
		
		add_child(attack_display)
		attack_display.set_position(Vector2(attack_x + i * spacing, center_y))
		table_attack_displays.append(attack_display)
		
		if tc.defending_card != null:
			var defense_display = CardDisplay.new()
			defense_display.setup(tc.defending_card.get_texture_path(), i, false)
			defense_display.is_selectable = false
			add_child(defense_display)
			defense_display.set_position(Vector2(attack_x + i * spacing + card_size.x * 0.15, center_y - card_size.y * 0.15))
			table_defense_displays.append(defense_display)

func _on_table_card_clicked(table_index: int):
	if model.current_state == GameModel.GameState.PLAYER_DEFEND:
		model.select_card_to_beat(table_index)

func _update_deck_display():
	var deck_size = model.get_deck_size()
	var card_size = _get_card_size()
	var viewport_size = get_viewport().get_visible_rect().size
	
	card_pile_display.visible = deck_size > 0
	
	if deck_size > 0:
		var pile_scale = 0.15 + (deck_size / 36.0) * 0.1
		card_pile_display.set_scale(Vector2(pile_scale, pile_scale))
		var pile_size = Vector2(226, 314) * pile_scale
		card_pile_display.set_position(Vector2(20, viewport_size.y / 2 - pile_size.y / 2))
		
		if model.trump_card:
			trump_display.setup(model.trump_card.get_texture_path(), -1, false)
			trump_display.is_selectable = false
			trump_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
			trump_display.set_scale(Vector2(CARD_SCALE * 0.6, CARD_SCALE * 0.6))
			trump_display.rotation = PI / 2
			var trump_size = Vector2(226, 314) * CARD_SCALE * 0.6
			trump_display.set_position(Vector2(130, viewport_size.y / 3))
			trump_display.visible = true
	else:
		trump_display.visible = false
	
	deck_count_label.text = "Deck: %d" % deck_size
	deck_count_label.set_position(Vector2(20, viewport_size.y / 2 + card_size.y * 0.7))

func _update_card_selectability():
	match model.current_state:
		GameModel.GameState.PLAYER_ATTACK:
			for display in player_card_displays:
				display.set_selectable(true)
				display.set_valid_for_defense(true)
		GameModel.GameState.PLAYER_DEFEND:
			var valid_indices = model.get_valid_defense_cards()
			for i in range(player_card_displays.size()):
				player_card_displays[i].set_selectable(i in valid_indices)
				player_card_displays[i].set_valid_for_defense(i in valid_indices)
		_:
			for display in player_card_displays:
				display.set_selectable(false)

func _get_card_size() -> Vector2:
	return Vector2(226, 314) * CARD_SCALE

func _calculate_hand_width(card_count: int) -> float:
	if card_count <= 0:
		return 0
	return CARD_WIDTH * (card_count - 1) + _get_card_size().x

func _on_player_card_clicked(card_index: int):
	if model.current_state == GameModel.GameState.PLAYER_ATTACK:
		if selected_card_index == card_index:
			_play_selected_card(card_index)
		else:
			_select_card(card_index)
	elif model.current_state == GameModel.GameState.PLAYER_DEFEND:
		var valid_indices = model.get_valid_defense_cards()
		if card_index in valid_indices:
			_play_selected_card(card_index, model.get_selected_card_to_beat_index())

func _on_player_card_hovered(card_index: int):
	if card_index >= 0 and card_index < player_card_displays.size():
		var display = player_card_displays[card_index]
		if display.is_selectable:
			display.modulate = Color(1.2, 1.2, 1.0, 1.0)

func _on_player_card_unhovered(card_index: int):
	if card_index >= 0 and card_index < player_card_displays.size():
		player_card_displays[card_index].modulate = Color(1, 1, 1, 1)

func _select_card(card_index: int):
	_clear_selection()
	selected_card_index = card_index
	if card_index >= 0 and card_index < player_card_displays.size():
		player_card_displays[card_index].set_selected(true)

func _clear_selection():
	if selected_card_index >= 0 and selected_card_index < player_card_displays.size():
		player_card_displays[selected_card_index].set_selected(false)
	selected_card_index = -1

func _play_selected_card(card_index: int, target_index: int = -1):
	if model.player_play_card(card_index, target_index):
		_clear_selection()
		_update_next_turn_button()

func _on_next_turn_pressed():
	if model.can_press_next_turn():
		model.player_next_turn()

func _on_new_game_pressed():
	new_game_button.visible = false
	next_turn_button.visible = true
	model.start_new_game()

func _process(delta):
	if ai_action_pending:
		ai_timer -= delta
		if ai_timer <= 0:
			_execute_ai_action()
	
	_position_ui_elements()

func _position_ui_elements():
	var viewport_size = get_viewport().get_visible_rect().size
	
	message_label.set_position(Vector2(viewport_size.x / 2 - 220, viewport_size.y / 2 - 100))
	message_label.set_size(Vector2(440, 50))
	
	next_turn_button.set_position(Vector2(viewport_size.x - 140, viewport_size.y / 2 - 20))
	new_game_button.set_position(Vector2(viewport_size.x - 140, viewport_size.y / 2 - 20))

func _execute_ai_action():
	if model.current_state == GameModel.GameState.GAME_OVER:
		ai_action_pending = false
		return
	
	match model.current_state:
		GameModel.GameState.AI_ATTACK:
			if model.ai_do_attack_step():
				ai_timer = 0.4
				return
		GameModel.GameState.AI_DEFEND:
			if model.ai_do_defend_step():
				ai_timer = 0.3
				return
	
	if model.current_state != GameModel.GameState.AI_ATTACK and model.current_state != GameModel.GameState.AI_DEFEND:
		ai_action_pending = false

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_clear_selection()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		call_deferred("_update_all_displays")
