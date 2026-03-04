class_name CardDisplay
extends TextureRect

signal card_clicked(card_index: int)
signal card_hovered(card_index: int)
signal card_unhovered(card_index: int)

var card_index: int = -1
var is_selected: bool = false
var is_hovered: bool = false
var is_selectable: bool = true
var original_position: Vector2
var selected_offset: Vector2 = Vector2(0, -20)
var hover_scale: float = 1.05
var original_scale: Vector2 = Vector2(0.25, 0.25)

func _ready():
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_scale(original_scale)

func setup(card_path: String, index: int, selectable: bool = true):
	card_index = index
	is_selectable = selectable
	if ResourceLoader.exists(card_path):
		texture = load(card_path)
	else:
		push_warning("Card texture not found: " + card_path)
	_update_size()

func setup_back(index: int):
	card_index = index
	var back_path = "res://images/player_card_back.png"
	if ResourceLoader.exists(back_path):
		texture = load(back_path)
	_update_size()

func _update_size():
	if texture:
		var size = texture.get_size() * 0.25
		custom_minimum_size = size
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _gui_input(event: InputEvent):
	if not is_selectable:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(card_index)
		accept_event()

func _notification(what):
	if what == NOTIFICATION_MOUSE_ENTER:
		if is_selectable:
			is_hovered = true
			card_hovered.emit(card_index)
			_update_appearance()
	elif what == NOTIFICATION_MOUSE_EXIT:
		if is_selectable:
			is_hovered = false
			card_unhovered.emit(card_index)
			_update_appearance()

func _update_appearance():
	var target_scale = original_scale
	var target_modulate = Color(1, 1, 1, 1)
	var target_position = original_position
	
	if is_selected:
		target_modulate = Color(0.8, 1.0, 0.8, 1.0)
		target_position = original_position + selected_offset
		z_index = 10
	elif is_hovered:
		target_scale = original_scale * hover_scale
		z_index = 5
	else:
		z_index = 0
	
	set_scale(target_scale)
	self_modulate = target_modulate
	
	if original_position != Vector2.ZERO:
		set_position(target_position)

func set_selected(selected: bool):
	is_selected = selected
	_update_appearance()

func set_selectable(selectable: bool):
	is_selectable = selectable
	if selectable:
		modulate = Color(1, 1, 1, 1)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func set_valid_for_defense(valid: bool):
	if valid:
		modulate = Color(1, 1, 1, 1)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		modulate = Color(0.4, 0.4, 0.4, 0.7)
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func get_card_size() -> Vector2:
	if texture:
		return texture.get_size() * 0.25
	return Vector2(50, 70)
