extends Node3D
# Уровень RPG. Всё строится по описанию из data/levels.json.

signal completed(next_id)
signal hero_died

const Builder = preload("res://scripts/world/builder.gd")
const Fx = preload("res://scripts/combat/fx.gd")
const CameraRig = preload("res://scripts/world/camera_rig.gd")
const Player = preload("res://scripts/actors/player.gd")
const Enemy = preload("res://scripts/actors/enemy.gd")
const Boss = preload("res://scripts/actors/boss.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const Dialogue = preload("res://scripts/ui/dialogue.gd")

var level_id: String = ""
var data: Dictionary = {}
var half: Vector2 = Vector2(20, 15)
var player = null
var cam = null
var hud = null
var dialogue = null
var boss = null
var enemies: Array = []
var obstacles: Array = []
var interactables: Array = []
var pickups: Array = []
var done_ids: Dictionary = {}
var wave_index: int = 0
var wave_timer: float = -1.0
var wave_active: bool = false
var cleared: bool = false
var finishing: bool = false
var interact_grace: float = 0.3
var death_timer: float = -1.0

func _ready() -> void:
	data = Game.levels[level_id]
	half = Vector2(float(data["size"][0]), float(data["size"][1])) / 2.0
	_build_environment()
	_build_ground()
	for item in data.get("buildings", []):
		_add_building(item)
	for item in data.get("props", []):
		_add_prop(item)
	for item in data.get("interactables", []):
		_add_interactable(item)
	_spawn_player()
	hud = Hud.new()
	add_child(hud)
	hud.title_label.text = str(data.get("title", ""))
	dialogue = Dialogue.new()
	add_child(dialogue)
	hud.refresh(player, player.can_fight(), null)
	dialogue.play_id(str(data.get("intro", "")), _after_intro)

func _after_intro() -> void:
	_close_dialogue_grace()
	if data.get("waves", []).is_empty():
		cleared = true
	else:
		wave_timer = 1.5

func _close_dialogue_grace() -> void:
	interact_grace = 0.3
	if player != null:
		player.input_grace = 0.2

# ---------- Построение мира ----------
func _vec(pair: Array) -> Vector3:
	return Vector3(float(pair[0]), 0.0, float(pair[1]))

func _build_environment() -> void:
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(str(data.get("sky", "#1a1020")))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(str(data.get("ambient", "#9a8aaa")))
	env.ambient_light_energy = 0.8
	env.glow_enabled = true
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = float(data.get("sun_energy", 0.9))
	sun.light_color = Color(str(data.get("sun_color", "#ffe2d0")))
	sun.shadow_enabled = true
	add_child(sun)

func _build_ground() -> void:
	var ground = Color(str(data.get("ground", "#4a3f4a")))
	Builder.box(self, Vector3(half.x * 2 + 40, 1.0, half.y * 2 + 40), Vector3(0, -0.56, 0), ground.darkened(0.55))
	var ground_texture = "res://assets/textures/ashen_ground.svg"
	if data.get("world", "") == "earth":
		ground_texture = "res://assets/textures/wood_floor.svg"
	Builder.textured_box(self, Vector3(half.x * 2, 1.0, half.y * 2), Vector3(0, -0.5, 0), ground, ground_texture, Vector3(half.x / 3.0, half.y / 3.0, 1.0))
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(level_id)
	for i in range(int(data.get("patches", 40))):
		var size = Vector3(rng.randf_range(0.6, 2.4), 0.012, rng.randf_range(0.6, 2.0))
		var pos = Vector3(rng.randf_range(-half.x + 1.5, half.x - 1.5), 0.004 + (i % 7) * 0.0004, rng.randf_range(-half.y + 1.5, half.y - 1.5))
		var shade = ground.darkened(0.12) if i % 2 == 0 else ground.lightened(0.07)
		Builder.box(self, size, pos, shade)
	for i in range(int(data.get("grass", 0))):
		var tuft = Builder.make_sprite("grass", 1, 0.035)
		tuft.position = Vector3(rng.randf_range(-half.x + 1, half.x - 1), 0, rng.randf_range(-half.y + 1, half.y - 1))
		add_child(tuft)

func _add_obstacle(center: Vector3, width: float, depth: float) -> void:
	Builder.static_collider(self, Vector3(width, 2.0, depth), center + Vector3(0, 1.0, 0))
	obstacles.append(Rect2(center.x - width / 2.0, center.z - depth / 2.0, width, depth))

func _add_building(item: Dictionary) -> void:
	var size = Vector3(float(item["size"][0]), float(item["size"][1]), float(item["size"][2]))
	var node = Builder.building(str(item["kind"]), size, Color(str(item.get("color", "#8a7a70"))), Color(str(item.get("roof", "#5a3038"))))
	node.position = _vec(item["pos"])
	add_child(node)
	if item.get("solid", true):
		_add_obstacle(node.position, size.x, size.z)

func _add_prop(item: Dictionary) -> void:
	var sprite = Builder.make_sprite(str(item["sprite"]), 1, float(item.get("pixel", 0.045)))
	sprite.position = _vec(item["pos"])
	add_child(sprite)
	var solid = float(item.get("solid", 0.0))
	if solid > 0.0:
		_add_obstacle(sprite.position, solid, solid)
	if item.has("light"):
		var lamp = OmniLight3D.new()
		lamp.light_color = Color(str(item["light"]))
		lamp.omni_range = 7.0
		lamp.light_energy = 1.6
		lamp.position = sprite.position + Vector3(0, 1.4, 0.4)
		add_child(lamp)

func _add_interactable(item: Dictionary) -> void:
	var holder = Node3D.new()
	holder.position = _vec(item["pos"])
	add_child(holder)
	var sprite_name = str(item["sprite"])
	var frames = int(item.get("frames", 1))
	holder.add_child(Builder.make_sprite(sprite_name, frames, float(item.get("pixel", 0.045))))
	var ring = Builder.ring(0.9, Color(0.5, 0.5, 0.55, 0.6))
	holder.add_child(ring)
	var tag = Builder.label(str(item.get("label", "")), float(item.get("label_height", 2.3)))
	holder.add_child(tag)
	interactables.append({"info": item, "node": holder, "ring": ring})

func _spawn_player() -> void:
	player = Player.new()
	add_child(player)
	player.position = _vec(data.get("start", [0, 0]))
	player.setup(self)
	player.defeated.connect(_on_player_defeated)
	cam = CameraRig.new()
	add_child(cam)
	cam.follow = player
	cam.snap(player.position)
	player.cam = cam

func spawn_enemy(kind: String, pos: Vector3):
	var is_boss = bool(Game.enemies[kind].get("boss", false))
	var foe = Boss.new() if is_boss else Enemy.new()
	add_child(foe)
	foe.position = clamp_point(pos, 1.0)
	foe.setup(self, kind)
	foe.died.connect(_on_enemy_died)
	enemies.append(foe)
	if is_boss:
		boss = foe
	Fx.burst(self, foe.position, 1.2, Color(0.8, 0.05, 0.25, 0.7))
	return foe

# ---------- Запросы от бойцов ----------
func living_enemies() -> Array:
	var result = []
	for foe in enemies:
		if is_instance_valid(foe) and foe.alive:
			result.append(foe)
	return result

func clamp_point(point: Vector3, radius: float) -> Vector3:
	return Vector3(clampf(point.x, -half.x + radius, half.x - radius), 0.0, clampf(point.z, -half.y + radius, half.y - radius))

func is_blocked(point: Vector3) -> bool:
	if absf(point.x) > half.x or absf(point.z) > half.y:
		return true
	var flat = Vector2(point.x, point.z)
	for area in obstacles:
		if area.has_point(flat):
			return true
	return false

func toast(text: String) -> void:
	hud.toast(text)

# ---------- События ----------
func _on_enemy_died(foe) -> void:
	if Game.add_xp(int(foe.stats["xp"])):
		player.on_level_up()
	if randf() < 0.14:
		var drop = Builder.make_sprite("potion", 1, 0.035)
		drop.position = foe.position
		add_child(drop)
		pickups.append(drop)

func _on_player_defeated() -> void:
	death_timer = 1.4

func _on_all_cleared() -> void:
	cleared = true
	dialogue.play_id(str(data.get("clear_dialogue", "")), _after_clear)

func _after_clear() -> void:
	_close_dialogue_grace()
	if data.has("grant_flag"):
		Game.flags[data["grant_flag"]] = true
	player.hp = player.max_hp
	toast("Путь открыт")

# ---------- Каждый кадр ----------
func _process(delta: float) -> void:
	if death_timer > 0.0:
		death_timer -= delta
		if death_timer <= 0.0:
			hero_died.emit()
	_update_waves(delta)
	_update_pickups()
	_update_interact(delta)
	_update_objective()
	hud.refresh(player, player.can_fight(), boss)

func _update_waves(delta: float) -> void:
	var waves = data.get("waves", [])
	if cleared or waves.is_empty() or not player.alive:
		return
	if wave_timer > 0.0:
		wave_timer -= delta
		if wave_timer <= 0.0:
			for entry in waves[wave_index]:
				spawn_enemy(str(entry["type"]), _vec(entry["pos"]))
			wave_active = true
			toast("Волна %d из %d" % [wave_index + 1, waves.size()])
	elif wave_active and living_enemies().is_empty():
		wave_active = false
		wave_index += 1
		if wave_index < waves.size():
			wave_timer = 2.5
		else:
			_on_all_cleared()

func _update_pickups() -> void:
	for i in range(pickups.size() - 1, -1, -1):
		if pickups[i].position.distance_to(player.position) < 1.0:
			Game.potions += 1
			Fx.floating_text(self, player.position, "+1 зелье", Color(0.5, 1.0, 0.6))
			pickups[i].queue_free()
			pickups.remove_at(i)

func _is_available(info: Dictionary) -> bool:
	if info.get("after_clear", false) and not cleared:
		return false
	for need in info.get("requires", []):
		if not done_ids.has(need):
			return false
	return true

func _update_interact(delta: float) -> void:
	var nearest = null
	var best = 2.0
	for entry in interactables:
		var info = entry["info"]
		var open = _is_available(info)
		var color = Color(0.45, 0.45, 0.5, 0.5)
		if open and not done_ids.has(info["id"]):
			color = Color(1.0, 0.82, 0.3, 0.95)
		entry["ring"].material_override.albedo_color = color
		var dist = entry["node"].position.distance_to(player.position)
		if dist < best:
			best = dist
			nearest = entry
	hud.prompt_label.text = ""
	if interact_grace > 0.0:
		interact_grace -= delta
		return
	if nearest == null or finishing or not player.alive:
		return
	var chosen_info = nearest["info"]
	if not _is_available(chosen_info):
		hud.prompt_label.text = str(chosen_info.get("locked", "Пока рано"))
		return
	hud.prompt_label.text = "F — " + str(chosen_info.get("prompt", "осмотреть"))
	if Input.is_action_just_pressed("interact"):
		_use(chosen_info)

func _use(info: Dictionary) -> void:
	done_ids[info["id"]] = true
	if info.get("rest", false):
		player.hp = player.max_hp
		Game.potions = maxi(Game.potions, 3)
	if info.get("exit", false):
		finishing = true
		dialogue.play_id(str(info.get("dialogue", "")), _finish_level)
	else:
		dialogue.play_id(str(info.get("dialogue", "")), _close_dialogue_grace)

func _finish_level() -> void:
	completed.emit(str(data.get("next", "rts")))

func _update_objective() -> void:
	var text = str(data.get("objective", ""))
	if not data.get("waves", []).is_empty():
		if cleared:
			text = str(data.get("objective_after", text))
		else:
			text += "\nВрагов рядом: %d" % living_enemies().size()
	hud.objective_label.text = text
