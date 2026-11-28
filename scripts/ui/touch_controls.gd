extends CanvasLayer
# Сенсорное управление RPG: движение, атака, уклонение, навыки и взаимодействие.

var root: Control = null
var combat_buttons: Array[Button] = []

func _ready() -> void:
	layer = 6
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	_build_direction_pad()
	_build_action_pad()

func _build_direction_pad() -> void:
	_add_button("▲", Vector2(112, 535), Vector2(66, 60), "move_up")
	_add_button("◀", Vector2(42, 600), Vector2(66, 60), "move_left")
	_add_button("▼", Vector2(112, 600), Vector2(66, 60), "move_down")
	_add_button("▶", Vector2(182, 600), Vector2(66, 60), "move_right")

func _build_action_pad() -> void:
	combat_buttons.append(_add_button("Удар", Vector2(1080, 590), Vector2(120, 72), "attack"))
	combat_buttons.append(_add_button("Уворот", Vector2(950, 620), Vector2(112, 60), "dodge"))
	combat_buttons.append(_add_button("Q", Vector2(1010, 525), Vector2(62, 58), "skill_1"))
	combat_buttons.append(_add_button("E", Vector2(1080, 515), Vector2(62, 58), "skill_2"))
	combat_buttons.append(_add_button("R", Vector2(1150, 515), Vector2(62, 58), "skill_3"))
	combat_buttons.append(_add_button("Зелье", Vector2(880, 550), Vector2(112, 58), "potion"))
	_add_button("✦", Vector2(1180, 420), Vector2(64, 64), "interact")

func set_combat_enabled(enabled: bool) -> void:
	for button in combat_buttons:
		button.visible = enabled

func _add_button(caption: String, at: Vector2, button_size: Vector2, action: String) -> Button:
	var button = Button.new()
	button.text = caption
	button.position = at
	button.size = button_size
	button.custom_minimum_size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20 if caption.length() > 1 else 26)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.075, 0.11, 0.72)
	normal.border_color = Color(0.72, 0.76, 0.86, 0.62)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(18)
	button.add_theme_stylebox_override("normal", normal)
	var pressed = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.34, 0.19, 0.29, 0.94)
	pressed.border_color = Color(1.0, 0.66, 0.75, 0.95)
	button.add_theme_stylebox_override("pressed", pressed)
	button.button_down.connect(_press_action.bind(action))
	button.button_up.connect(_release_action.bind(action))
	root.add_child(button)
	return button

func _press_action(action: String) -> void:
	Input.action_press(action)

func _release_action(action: String) -> void:
	Input.action_release(action)

func _exit_tree() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "attack", "dodge", "skill_1", "skill_2", "skill_3", "potion", "interact"]:
		Input.action_release(action)
