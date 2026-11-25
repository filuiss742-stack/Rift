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
	story_button.text = "Продолжить"
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
	interact_button.text = "Осмотреть / взаимодействовать"
	interact_button.anchor_left = 0.62
	interact_button.anchor_right = 0.97
	interact_button.anchor_top = 0.84
	interact_button.anchor_bottom = 0.94
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
	_add_pad_button(pad, "↑", Vector2(0, -1))
	_add_pad_spacer(pad)
	_add_pad_button(pad, "←", Vector2(-1, 0))
	_add_pad_button(pad, "↓", Vector2(0, 1))
	_add_pad_button(pad, "→", Vector2(1, 0))

	_set_game_ui(false)

func _add_pad_spacer(parent: GridContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(42, 38)
	parent.add_child(spacer)

func _add_pad_button(parent: GridContainer, caption: String, axis: Vector2) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(48, 42)
	button.button_down.connect(func() -> void: touch_vector = axis)
	button.button_up.connect(func() -> void:
		if touch_vector == axis:
			touch_vector = Vector2.ZERO
	)
	parent.add_child(button)

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

	_box("Floor", Vector3(0, -0.2, 0), Vector3(12, 0.4, 12), Color(0.34, 0.29, 0.27), true)
	_box("Back wall", Vector3(0, 2.0, -6), Vector3(12, 4, 0.25), Color(0.72, 0.68, 0.62), true)
	_box("Left wall", Vector3(-6, 2.0, 0), Vector3(0.25, 4, 12), Color(0.62, 0.65, 0.68), true)
	_box("Right wall", Vector3(6, 2.0, 0), Vector3(0.25, 4, 12), Color(0.62, 0.65, 0.68), true)
	_box("Window glow", Vector3(0, 2.5, -5.82), Vector3(2.8, 1.8, 0.04), Color(0.24, 0.42, 0.58), false)
	_box("Bed base", Vector3(-3.4, 0.35, -3.3), Vector3(2.5, 0.7, 3.2), Color(0.22, 0.19, 0.2), true)
	_box("Bed blanket", Vector3(-3.4, 0.76, -3.3), Vector3(2.45, 0.12, 3.1), Color(0.38, 0.42, 0.52), false)
	_box("Desk", Vector3(3.4, 0.85, -3.7), Vector3(2.7, 0.15, 1.2), Color(0.30, 0.20, 0.14), true)
	_box("Desk legs", Vector3(3.4, 0.4, -3.7), Vector3(2.45, 0.8, 0.12), Color(0.22, 0.15, 0.11), true)
	_box("Wardrobe", Vector3(4.9, 1.25, 1.8), Vector3(1.4, 2.5, 1.2), Color(0.25, 0.19, 0.17), true)
	_box("Rug", Vector3(0, 0.015, 1.2), Vector3(4.0, 0.03, 3.0), Color(0.32, 0.24, 0.25), false)

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
	sprite.name = "TEMP_REPLACE_WITH_APPROVED_2D_SPRITES"
	sprite.texture = _make_placeholder_texture()
	sprite.pixel_size = 0.018
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.position.y = 0.95
	player.add_child(sprite)
	add_child(player)
	var camera_node := Camera3D.new()
	camera_node.position = Vector3(0, 8.5, 10.5)
	camera_node.rotation_degrees = Vector3(-36, 0, 0)
	camera_node.current = true
	player.add_child(camera_node)
	camera = camera_node

func _make_placeholder_texture() -> Texture2D:
	var image := Image.create(48, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(8, 78):
		for x in range(5, 44):
			var dx := float(x - 24)
			var inside_head := y < 29 and dx * dx + pow(float(y - 18), 2.0) < 105.0
			var inside_body := y >= 28 and y < 70 and absf(dx) < (10.0 if y < 56 else 16.0)
			var inside_hair := y < 37 and absf(dx) < (13.0 if y < 28 else 18.0)
			if inside_head or inside_body or inside_hair:
				image.set_pixel(x, y, Color(0.12, 0.10, 0.15, 1))
	var texture := ImageTexture.create_from_image(image)
	return texture

func _box(label: String, at: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
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
	_box("Ashen ground", Vector3(0, -0.2, 0), Vector3(34, 0.4, 34), Color(0.19, 0.20, 0.22), true)
	for i in range(7):
		var x := -10.0 + float(i) * 3.2
		_box("Broken ruin %d" % i, Vector3(x, 1.3 + float(i % 2) * 0.4, -7.5), Vector3(1.0, 2.6 + float(i % 2), 1.0), Color(0.28, 0.29, 0.31), true)
	_box("Fallen pillar", Vector3(5, 0.35, -1), Vector3(5, 0.55, 0.8), Color(0.30, 0.30, 0.32), true)
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
	story_button.text = "Продолжить"
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
