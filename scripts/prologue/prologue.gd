extends Node3D
## First playable story slice: the void, Lisa's ordinary room, and the first awakening.
## Temporary protagonist art is generated in code and must be replaced by approved sprite art.

const WALK_SPEED := 4.2
const GRAVITY := 18.0
const INTERACT_DISTANCE := 2.35

var player: CharacterBody3D
var camera: Camera3D
var ui_layer: CanvasLayer
var story_panel: PanelContainer
var story_label: Label
var story_button: Button
var prompt_label: Label
var interact_button: Button
var touch_vector := Vector2.ZERO
var touch_up := false
var touch_down := false
var touch_left := false
var touch_right := false
var player_sprite: Sprite3D
var sprite_front: Texture2D
var sprite_back: Texture2D
var sprite_side: Texture2D
var nearby: Area3D
var inspected := {}
var current_phase := "void"
var dialogue_lines: Array[String] = []
var dialogue_index := 0
var dialogue_action: Callable
var controls_enabled := false

func _ready() -> void:
	_setup_input()
	_build_ui()
	_show_void()

func _physics_process(delta: float) -> void:
	if not controls_enabled or player == null:
		return
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(keyboard.x + touch_vector.x, 0.0, keyboard.y + touch_vector.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	player.velocity.x = direction.x * WALK_SPEED
	player.velocity.z = direction.z * WALK_SPEED
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	else:
		player.velocity.y = 0.0
	player.move_and_slide()
	_update_player_sprite(direction)
	_update_nearby()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and controls_enabled:
		_interact()
		get_viewport().set_input_as_handled()

func _setup_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("interact", KEY_E)
	_add_key_action("interact", KEY_SPACE)

func _add_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root)

	story_panel = PanelContainer.new()
	story_panel.anchor_left = 0.12
	story_panel.anchor_right = 0.88
	story_panel.anchor_top = 0.68
	story_panel.anchor_bottom = 0.96
	root.add_child(story_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	story_panel.add_child(column)
	story_label = Label.new()
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.add_theme_font_size_override("font_size", 19)
	column.add_child(story_label)
	story_button = Button.new()
	story_button.custom_minimum_size = Vector2(0, 48)
	story_button.text = "▶"
	story_button.pressed.connect(_advance_story)
	column.add_child(story_button)

	prompt_label = Label.new()
	prompt_label.anchor_left = 0.2
	prompt_label.anchor_right = 0.8
	prompt_label.anchor_top = 0.57
	prompt_label.anchor_bottom = 0.64
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	root.add_child(prompt_label)

	interact_button = Button.new()
	interact_button.text = "✦"
	interact_button.tooltip_text = "Взаимодействовать"
	interact_button.custom_minimum_size = Vector2(76, 76)
	interact_button.anchor_left = 0.82
	interact_button.anchor_right = 0.98
	interact_button.anchor_top = 0.79
	interact_button.anchor_bottom = 0.97
	interact_button.add_theme_font_size_override("font_size", 34)
	_style_icon_button(interact_button, 38)
	interact_button.pressed.connect(_interact)
	root.add_child(interact_button)

	var pad := GridContainer.new()
	pad.columns = 3
	pad.anchor_left = 0.03
	pad.anchor_right = 0.37
	pad.anchor_top = 0.76
	pad.anchor_bottom = 0.98
	pad.add_theme_constant_override("h_separation", 5)
	pad.add_theme_constant_override("v_separation", 5)
	root.add_child(pad)
	_add_pad_spacer(pad)
	_add_pad_button(pad, "▲", Vector2(0, -1))
	_add_pad_spacer(pad)
	_add_pad_button(pad, "◀", Vector2(-1, 0))
	_add_pad_button(pad, "▼", Vector2(0, 1))
	_add_pad_button(pad, "▶", Vector2(1, 0))

	_set_game_ui(false)

func _add_pad_spacer(parent: GridContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(42, 38)
	parent.add_child(spacer)

func _add_pad_button(parent: GridContainer, caption: String, axis: Vector2) -> void:
	var button := Button.new()
	button.text = caption
	button.tooltip_text = "Движение"
	button.custom_minimum_size = Vector2(58, 54)
	button.add_theme_font_size_override("font_size", 27)
	_style_icon_button(button, 29)
	button.button_down.connect(_set_touch_direction.bind(axis, true))
	button.button_up.connect(_set_touch_direction.bind(axis, false))
	parent.add_child(button)

func _style_icon_button(button: Button, font_size: int) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.075, 0.11, 0.82)
	normal.border_color = Color(0.72, 0.76, 0.86, 0.62)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(22)
	normal.shadow_color = Color(0, 0, 0, 0.28)
	normal.shadow_size = 5
	button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.34, 0.19, 0.29, 0.94)
	pressed.border_color = Color(1.0, 0.66, 0.75, 0.95)
	button.add_theme_stylebox_override("pressed", pressed)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.17, 0.24, 0.94)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.93))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.82))
	button.add_theme_font_size_override("font_size", font_size)

func _set_touch_direction(axis: Vector2, pressed: bool) -> void:
	if axis.y < 0.0:
		touch_up = pressed
	elif axis.y > 0.0:
		touch_down = pressed
	elif axis.x < 0.0:
		touch_left = pressed
	elif axis.x > 0.0:
		touch_right = pressed
	touch_vector = Vector2(
		float(touch_right) - float(touch_left),
		float(touch_down) - float(touch_up)
	)
	if touch_vector.length() > 1.0:
		touch_vector = touch_vector.normalized()

func _set_game_ui(enabled: bool) -> void:
	story_panel.visible = not enabled
	prompt_label.visible = enabled
	interact_button.visible = enabled
	for child in ui_layer.get_child(0).get_children():
		if child is GridContainer:
			child.visible = enabled
	controls_enabled = enabled

func _show_void() -> void:
	current_phase = "void"
	_clear_world()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.002, 0.002, 0.008)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.08, 0.12)
	environment.environment = env
	add_child(environment)
	var void_camera := Camera3D.new()
	void_camera.position = Vector3(0, 0, 8)
	void_camera.current = true
	add_child(void_camera)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2, 0)
	light.light_color = Color(1.0, 0.08, 0.12)
	light.light_energy = 3.0
	light.omni_range = 9.0
	add_child(light)
	_add_crack()
	_set_game_ui(false)
	_show_lines([
		"…",
		"В бесконечной темноте что-то дрогнуло.",
		"Тонкая белая трещина прорезала пустоту.",
		"Из неё хлынуло красное искажение. Оно будто пыталось выбраться наружу.",
		"Вспышка поглотила всё."
	], _enter_modern_world)

func _add_crack() -> void:
	var crack := MeshInstance3D.new()
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	var points := [
		Vector3(-0.06, 2.7, 0), Vector3(0.04, 2.0, 0),
		Vector3(0.04, 2.0, 0), Vector3(-0.13, 1.1, 0),
		Vector3(-0.13, 1.1, 0), Vector3(0.10, 0.3, 0),
		Vector3(0.10, 0.3, 0), Vector3(-0.04, -0.6, 0),
		Vector3(-0.04, -0.6, 0), Vector3(0.15, -1.7, 0),
		Vector3(0.15, -1.7, 0), Vector3(-0.10, -2.6, 0)
	]
	for point in points:
		immediate.surface_add_vertex(point)
	immediate.surface_end()
	crack.mesh = immediate
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.86, 0.92)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.35, 0.55)
	material.emission_energy_multiplier = 5.0
	crack.material_override = material
	add_child(crack)

func _enter_modern_world() -> void:
	current_phase = "modern"
	_clear_world()
	_build_room()
	_set_game_ui(true)
	_show_lines([
		"Лиза открыла глаза.",
		"Знакомый потолок. Знакомая комната. За окном — обычный город.",
		"Всё выглядело так, будто ничего не произошло.",
		"Но странное чувство не отпускало. Может, это был просто сон?"
	], func() -> void:
		_set_game_ui(true)
		_show_hint("Осмотрись. Подойди к предметам и нажми E или кнопку взаимодействия.")
	)

func _build_room() -> void:
	var env := WorldEnvironment.new()
	var world_env := Environment.new()
	world_env.background_mode = Environment.BG_COLOR
	world_env.background_color = Color(0.12, 0.17, 0.23)
	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.ambient_light_color = Color(0.62, 0.66, 0.75)
	world_env.ambient_light_energy = 0.75
	env.environment = world_env
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.0
	add_child(sun)

	_box("Floor", Vector3(0, -0.2, 0), Vector3(12, 0.4, 12), Color.WHITE, true, "res://assets/textures/wood_floor.svg")
	_box("Back wall", Vector3(0, 2.0, -6), Vector3(12, 4, 0.25), Color.WHITE, true, "res://assets/textures/wallpaper.svg")
	_box("Left wall", Vector3(-6, 2.0, 0), Vector3(0.25, 4, 12), Color.WHITE, true, "res://assets/textures/wallpaper.svg")
	_box("Right wall", Vector3(6, 2.0, 0), Vector3(0.25, 4, 12), Color.WHITE, true, "res://assets/textures/wallpaper.svg")
	_box("Window glow", Vector3(0, 2.5, -5.82), Vector3(2.8, 1.8, 0.04), Color(0.24, 0.42, 0.58), false)
	_box("Bed base", Vector3(-3.4, 0.35, -3.3), Vector3(2.5, 0.7, 3.2), Color(0.22, 0.19, 0.2), true)
	_box("Bed blanket", Vector3(-3.4, 0.76, -3.3), Vector3(2.45, 0.12, 3.1), Color(0.38, 0.42, 0.52), false)
	_box("Desk", Vector3(3.4, 0.85, -3.7), Vector3(2.7, 0.15, 1.2), Color(0.30, 0.20, 0.14), true)
	_box("Desk legs", Vector3(3.4, 0.4, -3.7), Vector3(2.45, 0.8, 0.12), Color(0.22, 0.15, 0.11), true)
	_box("Wardrobe", Vector3(4.9, 1.25, 1.8), Vector3(1.4, 2.5, 1.2), Color(0.25, 0.19, 0.17), true)
	_box("Rug", Vector3(0, 0.015, 1.2), Vector3(4.0, 0.03, 3.0), Color.WHITE, false, "res://assets/textures/rug.svg")

	_add_interactable("Phone", "Телефон", Vector3(3.2, 1.12, -3.7), "На экране несколько обычных уведомлений. Ничего необычного. Мир продолжает жить своей жизнью.", "phone")
	_add_interactable("Mirror", "Зеркало", Vector3(5.2, 1.4, -0.3), "В отражении — уставшая девушка. На мгновение кажется, что отражение моргнуло чуть позже. Наверное, показалось.", "mirror")
	_add_interactable("Window", "Окно", Vector3(0, 1.8, -5.2), "За окном мерцают огни города. Машины, окна соседних домов, далёкий шум. Самая обычная ночь.", "window")
	_add_interactable("Bed", "Кровать", Vector3(-3.4, 0.8, -3.3), "Пора спать. Завтра будет обычный день…", "bed")
	_spawn_player(Vector3(0, 0.15, 3.2))

func _spawn_player(at: Vector3) -> void:
	player = CharacterBody3D.new()
	player.name = "LisaSpritePlaceholder"
	player.position = at
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.55
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.78
	player.add_child(collision)
	var sprite := Sprite3D.new()
	sprite.name = "LisaDirectional2DSprite"
	sprite_front = load("res://assets/sprites/lisa_idle_front.svg") as Texture2D
	sprite_back = load("res://assets/sprites/lisa_idle_back.svg") as Texture2D
	sprite_side = load("res://assets/sprites/lisa_idle_side.svg") as Texture2D
	sprite.texture = sprite_front
	sprite.pixel_size = 0.0062
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.position.y = 1.05
	player_sprite = sprite
	player.add_child(sprite)
	add_child(player)
	var camera_node := Camera3D.new()
	camera_node.position = Vector3(0, 8.5, 10.5)
	camera_node.rotation_degrees = Vector3(-36, 0, 0)
	camera_node.current = true
	player.add_child(camera_node)
	camera = camera_node

func _update_player_sprite(direction: Vector3) -> void:
	if player_sprite == null or direction.length_squared() < 0.02:
		return
	if absf(direction.x) > absf(direction.z):
		player_sprite.texture = sprite_side
		player_sprite.flip_h = direction.x < 0.0
	elif direction.z < 0.0:
		player_sprite.texture = sprite_back
		player_sprite.flip_h = false
	else:
		player_sprite.texture = sprite_front
		player_sprite.flip_h = false

func _box(label: String, at: Vector3, size: Vector3, color: Color, solid: bool, texture_path: String = "") -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		material.albedo_texture = load(texture_path) as Texture2D
		material.uv1_scale = Vector3(2.0, 2.0, 1.0)
	mesh.material = material
	mesh_node.mesh = mesh
	mesh_node.position = at
	add_child(mesh_node)
	if solid:
		var body := StaticBody3D.new()
		body.position = at
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		add_child(body)

func _add_interactable(node_name: String, label: String, at: Vector3, text: String, key: String) -> void:
	var area := Area3D.new()
	area.name = node_name
	area.position = at
	area.set_meta("label", label)
	area.set_meta("description", text)
	area.set_meta("story_key", key)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.35
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)

func _update_nearby() -> void:
	nearby = null
	var best := INTERACT_DISTANCE
	for candidate in get_children():
		if candidate is Area3D and candidate.has_meta("story_key"):
			var distance := player.global_position.distance_to(candidate.global_position)
			if distance < best:
				best = distance
				nearby = candidate
	if nearby:
		prompt_label.text = "E — " + str(nearby.get_meta("label"))
		interact_button.disabled = false
	else:
		prompt_label.text = "Осмотрись вокруг"
		interact_button.disabled = true

func _interact() -> void:
	if not controls_enabled or nearby == null:
		return
	var key: String = nearby.get_meta("story_key")
	if key == "bed":
		if inspected.size() < 3:
			_show_lines(["Ты ещё не закончила свои дела. Можно осмотреть телефон, зеркало и окно."], func() -> void: _set_game_ui(true))
			return
		_sleep_and_wake()
		return
	if inspected.has(key):
		_show_lines(["Ты уже осмотрела это."], func() -> void: _set_game_ui(true))
		return
	inspected[key] = true
	var description: String = nearby.get_meta("description")
	_show_lines([description], func() -> void:
		_set_game_ui(true)
		_show_hint("Осмотрено: %d / 3" % inspected.size())
	)

func _sleep_and_wake() -> void:
	_set_game_ui(false)
	_show_lines([
		"Лиза легла в кровать. Мысли постепенно растворились в тишине.",
		"…",
		"Но это был не обычный сон."
	], _wake_in_fantasy)

func _wake_in_fantasy() -> void:
	current_phase = "fantasy"
	_clear_world()
	_build_fantasy_world()
	_set_game_ui(false)
	_show_lines([
		"Холодная земля. Запах сырости и пепла.",
		"Лиза резко открыла глаза — над ней было незнакомое небо.",
		"Вместо привычной комнаты — разрушенные каменные стены и чужой мир.",
		"Она попыталась подняться. Тело ощущалось… иначе.",
		"Где она? И почему её руки ей незнакомы?"
	], func() -> void:
		_show_final_card()
	)

func _build_fantasy_world() -> void:
	var env := WorldEnvironment.new()
	var world_env := Environment.new()
	world_env.background_mode = Environment.BG_COLOR
	world_env.background_color = Color(0.08, 0.10, 0.15)
	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.ambient_light_color = Color(0.34, 0.38, 0.48)
	world_env.ambient_light_energy = 0.55
	env.environment = world_env
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, 28, 0)
	moon.light_color = Color(0.52, 0.62, 0.88)
	moon.light_energy = 0.45
	add_child(moon)
	_box("Ashen ground", Vector3(0, -0.2, 0), Vector3(34, 0.4, 34), Color.WHITE, true, "res://assets/textures/ashen_ground.svg")
	for i in range(7):
		var x := -10.0 + float(i) * 3.2
		_box("Broken ruin %d" % i, Vector3(x, 1.3 + float(i % 2) * 0.4, -7.5), Vector3(1.0, 2.6 + float(i % 2), 1.0), Color.WHITE, true, "res://assets/textures/stone_ruins.svg")
	_box("Fallen pillar", Vector3(5, 0.35, -1), Vector3(5, 0.55, 0.8), Color.WHITE, true, "res://assets/textures/stone_ruins.svg")
	var rift_light := OmniLight3D.new()
	rift_light.position = Vector3(-5, 2, -5)
	rift_light.light_color = Color(0.75, 0.08, 0.16)
	rift_light.light_energy = 2.0
	rift_light.omni_range = 8
	add_child(rift_light)
	_spawn_player(Vector3(0, 0.15, 3.0))
	_show_hint("ПРОБУЖДЕНИЕ — незнакомый мир")

func _show_final_card() -> void:
	_show_lines([
		"ПРОЛОГ ОКОНЧЕН",
		"Лиза ещё не знает, что произошло с ней этой ночью.",
		"И что где-то в этом мире есть другая девушка, которой принадлежит это тело."
	], func() -> void:
		_show_hint("Конец пролога. Продолжение истории впереди.")
	)

func _show_hint(message: String) -> void:
	prompt_label.text = message

func _show_lines(lines: Array[String], after: Callable) -> void:
	dialogue_lines = lines
	dialogue_index = 0
	dialogue_action = after
	story_panel.visible = true
	story_button.visible = true
	story_button.text = "▶"
	story_label.text = dialogue_lines[0] if not dialogue_lines.is_empty() else ""
	controls_enabled = false
	interact_button.visible = false
	for child in ui_layer.get_child(0).get_children():
		if child is GridContainer:
			child.visible = false

func _advance_story() -> void:
	dialogue_index += 1
	if dialogue_index < dialogue_lines.size():
		story_label.text = dialogue_lines[dialogue_index]
		return
	story_panel.visible = false
	if dialogue_action.is_valid():
		dialogue_action.call()

func _clear_world() -> void:
	for child in get_children():
		if child == ui_layer:
			continue
		child.queue_free()
	player = null
	camera = null
	nearby = null
