extends Node3D
# Финальная битва в реальном времени: экономика, стройка, найм, приказы, волны.

signal finished(victory)

const Builder = preload("res://scripts/world/builder.gd")
const Fx = preload("res://scripts/combat/fx.gd")
const CameraRig = preload("res://scripts/world/camera_rig.gd")
const Unit = preload("res://scripts/rts/rts_unit.gd")
const Building = preload("res://scripts/rts/rts_building.gd")
const RtsHud = preload("res://scripts/ui/rts_hud.gd")
const Dialogue = preload("res://scripts/ui/dialogue.gd")

const CAMERA_OFFSET = Vector3(0, 21.0, 15.0)

var config: Dictionary = {}
var half: Vector2 = Vector2(36, 24)
var cam = null
var hud = null
var dialogue = null

var units: Array = []
var buildings: Array = []
var crystals: Array = []
var rocks: Array = []
var obstacle_list: Array = []
var selection: Array = []
var groups: Dictionary = {}

var crystal_stock: int = 0
var player_hq = null
var heart = null
var hero = null
var skill_cooldown: float = 0.0
var wave_timer: float = 80.0
var wave_number: int = 0
var zoom: float = 1.0

var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var attack_mode: bool = false
var build_mode: String = ""
var ghost = null
var over: bool = false

func _ready() -> void:
	config = Game.rts
	var map = config["map"]
	half = Vector2(float(map["size"][0]), float(map["size"][1])) / 2.0
	crystal_stock = int(config["start_crystals"])
	wave_timer = float(config["first_wave"])
	_build_world()

	cam = CameraRig.new()
	cam.offset_vec = CAMERA_OFFSET
	add_child(cam)

	player_hq = spawn_building("hq", 0, _vec(map["hq"]))
	heart = spawn_building("heart", 1, _vec(map["heart"]))
	for pos in map["obelisks"]:
		spawn_building("obelisk", 1, _vec(pos))
	for guard in map["guards"]:
		spawn_unit(str(guard["type"]), 1, _vec(guard["pos"]))
	for pos in map["crystals"]:
		_add_crystal(_vec(pos), int(map["crystal_amount"]))
	for pos in map["rocks"]:
		_add_rock(_vec(pos))
	_update_obstacles()

	for i in range(int(map["workers"])):
		var worker = spawn_unit("worker", 0, player_hq.position + Vector3(-1.5 + i, 0, 3.2))
		var node = nearest_crystal(worker.position)
		if node != null:
			worker.command_gather(node)
	_spawn_hero()
	cam.snap(player_hq.position + Vector3(6, 0, 0))

	hud = RtsHud.new()
	hud.game = self
	add_child(hud)
	hud.refresh()
	dialogue = Dialogue.new()
	add_child(dialogue)
	dialogue.play_id("rts_intro")

func _vec(pair: Array) -> Vector3:
	return Vector3(float(pair[0]), 0.0, float(pair[1]))

func _build_world() -> void:
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1c0c18")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#a896a8")
	env.ambient_light_energy = 0.85
	env.glow_enabled = true
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	Builder.box(self, Vector3(half.x * 2 + 40, 1.0, half.y * 2 + 40), Vector3(0, -0.56, 0), Color("#201820"))
	Builder.box(self, Vector3(half.x * 2, 1.0, half.y * 2), Vector3(0, -0.5, 0), Color("#55504a"))
	# Заражённая земля на стороне врага и дорога между базами.
	Builder.box(self, Vector3(22, 0.01, half.y * 2), Vector3(half.x - 11, 0.004, 0), Color("#4a3040"))
	Builder.box(self, Vector3(half.x * 2 - 8, 0.01, 3.5), Vector3(0, 0.01, 0), Color("#6a5c4e"))

func _add_crystal(pos: Vector3, amount: int) -> void:
	var node = Builder.make_sprite("crystal", 1, 0.045)
	node.position = pos
	add_child(node)
	crystals.append({"node": node, "pos": pos, "amount": amount})

func _add_rock(pos: Vector3) -> void:
	var node = Builder.make_sprite("rock", 1, 0.085)
	node.position = pos
	add_child(node)
	rocks.append({"pos": pos, "radius": 1.3})

func _update_obstacles() -> void:
	obstacle_list = []
	for item in buildings:
		if item.alive:
			obstacle_list.append({"pos": item.position, "radius": item.radius})
	for node in crystals:
		obstacle_list.append({"pos": node["pos"], "radius": 0.9})
	obstacle_list.append_array(rocks)

# ---------- Создание ----------
func spawn_unit(unit_key: String, team: int, pos: Vector3):
	var unit = Unit.new()
	unit.position = pos
	add_child(unit)
	unit.setup(self, unit_key, team)
	unit.destroyed.connect(_on_destroyed)
	units.append(unit)
	return unit

func spawn_building(building_key: String, team: int, pos: Vector3):
	var item = Building.new()
	item.position = pos
	add_child(item)
	item.setup(self, building_key, team)
	item.destroyed.connect(_on_destroyed)
	buildings.append(item)
	return item

func _spawn_hero() -> void:
	hero = spawn_unit("hero", 0, player_hq.position + Vector3(4.5, 0, 0))
	hero.max_hp += 30.0 * (Game.hero_level - 1)
	hero.hp = hero.max_hp
	hero.refresh_bar()

# ---------- Запросы ----------
func is_valid_target(item) -> bool:
	return item != null and is_instance_valid(item) and item.alive

func nearest_enemy(pos: Vector3, team: int, reach: float):
	var best = null
	var best_score = 99999.0
	for item in units + buildings:
		if not item.alive or item.team == team:
			continue
		var dist = pos.distance_to(item.position) - item.radius
		if dist > reach:
			continue
		# Сначала бойцы, потом здания.
		var score = dist + (4.0 if item.is_building else 0.0)
		if score < best_score:
			best_score = score
			best = item
	return best

func nearest_crystal(pos: Vector3):
	var best = null
	var best_dist = 99999.0
	for node in crystals:
		var dist = pos.distance_to(node["pos"])
		if node["amount"] > 0 and dist < best_dist:
			best_dist = dist
			best = node
	return best

func mine(node: Dictionary, amount: int) -> void:
	node["amount"] -= amount
	if node["amount"] <= 0:
		node["node"].queue_free()
		for i in range(crystals.size() - 1, -1, -1):
			if is_same(crystals[i], node):
				crystals.remove_at(i)
		_update_obstacles()

func supply_cap() -> int:
	var total = 0
	for item in buildings:
		if item.alive and item.team == 0 and item.is_complete():
			total += int(item.stats.get("supply", 0))
	return mini(total, int(config["max_supply"]))

func supply_used() -> int:
	var total = 0
	for unit in units:
		if unit.alive and unit.team == 0:
			total += int(unit.stats.get("supply", 0))
	for item in buildings:
		if item.alive and item.team == 0:
			for unit_key in item.queue:
				total += int(config["units"][unit_key]["supply"])
	return total

func toast(text: String) -> void:
	hud.toast(text)

# ---------- Симуляция ----------
func _physics_process(delta: float) -> void:
	if over:
		return
	for unit in units.duplicate():
		if unit.alive and not over:
			unit.tick(delta)
	for item in buildings.duplicate():
		if item.alive and not over:
			item.tick(delta)
	_separate_units()
	units = units.filter(func(u): return is_instance_valid(u) and u.alive)
	buildings = buildings.filter(func(b): return is_instance_valid(b) and b.alive)
	selection = selection.filter(func(s): return is_instance_valid(s) and s.alive)
	skill_cooldown = maxf(skill_cooldown - delta, 0.0)
	wave_timer -= delta
	if wave_timer <= 0.0:
		wave_timer = float(config["wave_interval"])
		_spawn_wave()

func _separate_units() -> void:
	for i in range(units.size()):
		var a = units[i]
		if not a.alive:
			continue
		for j in range(i + 1, units.size()):
			var b = units[j]
			if not b.alive:
				continue
			var diff = a.position - b.position
			var need = a.radius + b.radius
			var dist = diff.length()
			if dist < need:
				var push = diff / dist if dist > 0.01 else Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()
				push *= (need - dist) * 0.5
				a.position += push
				b.position -= push
		for obstacle in obstacle_list:
			var away = a.position - obstacle["pos"]
			var need = a.radius + float(obstacle["radius"])
			if away.length() < need and away.length() > 0.01:
				a.position = obstacle["pos"] + away.normalized() * need
		a.position.x = clampf(a.position.x, -half.x + a.radius, half.x - a.radius)
		a.position.z = clampf(a.position.z, -half.y + a.radius, half.y - a.radius)
		a.position.y = 0.0

func _spawn_wave() -> void:
	if not is_valid_target(heart):
		return
	var enemy_count = 0
	for unit in units:
		if unit.team == 1:
			enemy_count += 1
	if enemy_count >= 36:
		return
	wave_number += 1
	var list = []
	for i in range(mini(2 + wave_number, 9)):
		list.append("rift_husk")
	for i in range(mini(int(wave_number / 2.0), 4)):
		list.append("rift_spitter")
	for i in range(clampi(int((wave_number - 1) / 2.0), 0, 3)):
		list.append("rift_brute")
	var goal = player_hq.position
	for i in range(list.size()):
		var pos = heart.position + Vector3(-4.0 - (i / 5) * 1.2, 0, -2.4 + (i % 5) * 1.2)
		var unit = spawn_unit(list[i], 1, pos)
		unit.command_attack_move(goal)
	toast("Разлом выпускает волну %d!" % wave_number)

func _on_destroyed(item) -> void:
	if item.is_building:
		_update_obstacles.call_deferred()
	if over:
		return
	if item == hero:
		over = true
		toast("Героиня пала. Битва проиграна.")
		_finish.call_deferred(false)
	elif item == heart:
		over = true
		dialogue.play_id.call_deferred("epilogue", _finish.bind(true))
	elif item == player_hq:
		over = true
		_finish.call_deferred(false)

func _finish(victory: bool) -> void:
	finished.emit(victory)

# ---------- Камера и интерфейс ----------
func move_camera_to(point: Vector3) -> void:
	cam.focus = Vector3(clampf(point.x, -half.x + 8, half.x - 8), 0, clampf(point.z, -half.y + 4, half.y - 2))

func _process(delta: float) -> void:
	var pan = Vector2(
		float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	var mouse = get_viewport().get_mouse_position()
	if get_window().has_focus() and not dragging:
		if mouse.x >= 0 and mouse.x < 8:
			pan.x -= 1
		elif mouse.x > 1272 and mouse.x <= 1280:
			pan.x += 1
		if mouse.y >= 0 and mouse.y < 8:
			pan.y -= 1
		elif mouse.y > 712 and mouse.y <= 720:
			pan.y += 1
	if pan != Vector2.ZERO:
		move_camera_to(cam.focus + Vector3(pan.x, 0, pan.y) * 22.0 * delta)
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		_finish_selection(mouse)
	_update_ghost()
	hud.refresh()

# ---------- Ввод ----------
func _unhandled_input(event: InputEvent) -> void:
	if over:
		return
	if event is InputEventMouseButton and event.pressed:
		_on_mouse(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event)

func _on_mouse(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if build_mode != "":
				_place_building(cam.mouse_on_ground())
			elif attack_mode:
				attack_mode = false
				_issue_attack(event.position)
			else:
				dragging = true
				drag_start = event.position
		MOUSE_BUTTON_RIGHT:
			if build_mode != "" or attack_mode:
				_cancel_modes()
			else:
				_issue_context(event.position)
		MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom - 0.08, 0.65, 1.35)
			cam.offset_vec = CAMERA_OFFSET * zoom
		MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom + 0.08, 0.65, 1.35)
			cam.offset_vec = CAMERA_OFFSET * zoom

func _on_key(event: InputEventKey) -> void:
	var code = event.physical_keycode
	match code:
		KEY_ESCAPE:
			# Если нечего отменять, Esc уходит в main.gd и открывает паузу.
			if build_mode != "" or attack_mode:
				_cancel_modes()
				get_viewport().set_input_as_handled()
		KEY_A:
			start_attack_mode()
		KEY_S:
			stop_selected()
		KEY_B:
			start_build("barracks")
		KEY_T:
			start_build("tower")
		KEY_H:
			start_build("tent")
		KEY_Q:
			hero_skill()
		KEY_SPACE:
			if is_valid_target(hero):
				move_camera_to(hero.position)
		KEY_1, KEY_2, KEY_3:
			if event.ctrl_pressed:
				groups[code] = selection.duplicate()
				toast("Отряд сохранён")
			elif groups.has(code):
				# Сначала убираем погибших из отряда.
				var alive_members = []
				for member in groups[code]:
					if is_valid_target(member):
						alive_members.append(member)
				groups[code] = alive_members
				_set_selection(alive_members)

func _cancel_modes() -> void:
	attack_mode = false
	build_mode = ""

# ---------- Выделение ----------
func _screen_pos(item) -> Vector2:
	return cam.unproject_position(item.position + Vector3(0, 0.7, 0))

func _pick(screen_point: Vector2):
	var best = null
	var best_dist = 30.0
	for unit in units:
		if unit.alive:
			var dist = _screen_pos(unit).distance_to(screen_point)
			if dist < best_dist:
				best_dist = dist
				best = unit
	if best != null:
		return best
	var ground = cam.mouse_on_ground()
	for item in buildings:
		if item.alive and (ground.distance_to(item.position) <= item.radius or _screen_pos(item).distance_to(screen_point) < 45.0):
			return item
	return null

func _set_selection(items: Array) -> void:
	for item in selection:
		if is_valid_target(item):
			item.set_selected(false)
	selection = items.duplicate()
	for item in selection:
		item.set_selected(true)

func _finish_selection(end_point: Vector2) -> void:
	var area = Rect2(drag_start, end_point - drag_start).abs()
	var picked = []
	if area.size.length() < 8.0:
		var item = _pick(end_point)
		if item != null and item.team == 0:
			picked.append(item)
	else:
		var soldiers = []
		for unit in units:
			if unit.alive and unit.team == 0 and area.has_point(_screen_pos(unit)):
				picked.append(unit)
				if not unit.is_worker():
					soldiers.append(unit)
		# Если в рамке есть бойцы, рабочих не берём.
		if not soldiers.is_empty():
			picked = soldiers
	if Input.is_key_pressed(KEY_SHIFT) and _selected_units().size() == selection.size():
		for item in selection:
			if not picked.has(item) and (picked.is_empty() or not picked[0].is_building):
				picked.append(item)
	_set_selection(picked)

func _selected_units() -> Array:
	var result = []
	for item in selection:
		if is_valid_target(item) and not item.is_building:
			result.append(item)
	return result

# ---------- Приказы ----------
func _formation(point: Vector3, count: int) -> Array:
	var spots = []
	var cols = int(ceil(sqrt(float(count))))
	var rows = int(ceil(float(count) / maxi(cols, 1)))
	for i in range(count):
		var col = i % cols
		var row = i / cols
		spots.append(point + Vector3((col - (cols - 1) / 2.0) * 1.1, 0, (row - (rows - 1) / 2.0) * 1.1))
	return spots

func _crystal_at(point: Vector3):
	for node in crystals:
		if node["pos"].distance_to(point) <= 1.6:
			return node
	return null

func _issue_context(screen_point: Vector2) -> void:
	var ground = cam.mouse_on_ground()
	var army = _selected_units()
	if army.is_empty():
		if selection.size() == 1 and selection[0].is_building:
			selection[0].rally = ground
			Fx.burst(self, ground, 0.8, Color(0.4, 0.7, 1.0, 0.8))
		return
	var item = _pick(screen_point)
	if item != null and item.team == 1:
		for unit in army:
			unit.command_attack(item)
		Fx.burst(self, item.position, item.radius + 0.3, Color(1.0, 0.2, 0.2, 0.7))
		return
	var node = _crystal_at(ground)
	var spots = _formation(ground, army.size())
	for i in range(army.size()):
		var unit = army[i]
		if unit.is_worker() and node != null:
			unit.command_gather(node)
		elif unit.is_worker() and item != null and item.is_building and not item.is_complete():
			unit.command_build(item)
		else:
			unit.command_move(spots[i])
	Fx.burst(self, ground, 0.6, Color(0.3, 1.0, 0.45, 0.8))

func _issue_attack(screen_point: Vector2) -> void:
	var army = _selected_units()
	var item = _pick(screen_point)
	var ground = cam.mouse_on_ground()
	var spots = _formation(ground, army.size())
	for i in range(army.size()):
		if item != null and item.team == 1:
			army[i].command_attack(item)
		else:
			army[i].command_attack_move(spots[i])
	Fx.burst(self, ground, 0.7, Color(1.0, 0.4, 0.2, 0.8))

func start_attack_mode() -> void:
	if not _selected_units().is_empty():
		build_mode = ""
		attack_mode = true

func stop_selected() -> void:
	for unit in _selected_units():
		unit.command_stop()

func hero_skill() -> void:
	if not is_valid_target(hero) or skill_cooldown > 0.0:
		return
	skill_cooldown = 14.0
	var center = hero.position
	var damage = 60.0 + 8.0 * (Game.hero_level - 1)
	Fx.burst(self, center, 5.0, Color(0.95, 0.08, 0.3, 0.7))
	for item in units + buildings:
		if item.alive and item.team == 1 and item.position.distance_to(center) <= 5.0 + item.radius:
			item.take_damage(damage * (0.5 if item.is_building else 1.0), hero)

# ---------- Стройка и найм ----------
func _builders() -> Array:
	var result = []
	for unit in _selected_units():
		if unit.is_worker():
			result.append(unit)
	return result

func start_build(building_key: String) -> void:
	if _builders().is_empty():
		return
	if crystal_stock < int(config["buildings"][building_key]["cost"]):
		toast("Не хватает кристаллов")
		return
	attack_mode = false
	build_mode = building_key

func _footprint(building_key: String) -> float:
	var size = config["buildings"][building_key]["size"]
	return maxf(float(size[0]), float(size[2])) * 0.55

func _can_place(building_key: String, point: Vector3) -> bool:
	var need = _footprint(building_key)
	if absf(point.x) > half.x - need or absf(point.z) > half.y - need:
		return false
	# Нельзя строить на земле врага.
	if point.x > 10.0:
		return false
	for obstacle in obstacle_list:
		if point.distance_to(obstacle["pos"]) < need + float(obstacle["radius"]) + 0.4:
			return false
	return true

func _place_building(point: Vector3) -> void:
	var workers = _builders()
	var cost = int(config["buildings"][build_mode]["cost"])
	if workers.is_empty() or crystal_stock < cost:
		_cancel_modes()
		return
	if not _can_place(build_mode, point):
		toast("Здесь строить нельзя")
		return
	crystal_stock -= cost
	var item = spawn_building(build_mode, 0, point)
	item.start_site()
	_update_obstacles()
	for worker in workers:
		worker.command_build(item)
	build_mode = ""

func _update_ghost() -> void:
	if build_mode == "":
		if ghost != null:
			ghost.queue_free()
			ghost = null
		return
	if ghost == null:
		ghost = Builder.box(self, Vector3.ONE, Vector3.ZERO, Color(0, 1, 0, 0.35))
	var point = cam.mouse_on_ground()
	var width = _footprint(build_mode) * 1.7
	ghost.scale = Vector3(width, 1.0, width)
	ghost.position = point + Vector3(0, 0.5, 0)
	ghost.material_override.albedo_color = Color(0.2, 1.0, 0.3, 0.35) if _can_place(build_mode, point) else Color(1.0, 0.2, 0.2, 0.35)

func train(unit_key: String) -> void:
	if selection.is_empty() or not selection[0].is_building:
		return
	var item = selection[0]
	var data = config["units"][unit_key]
	if item.team != 0 or not item.is_complete() or item.queue.size() >= 5:
		return
	if crystal_stock < int(data["cost"]):
		toast("Не хватает кристаллов")
		return
	if supply_used() + int(data["supply"]) > supply_cap():
		toast("Лимит войск: построй палатку (H)")
		return
	crystal_stock -= int(data["cost"])
	item.queue.append(unit_key)

func cancel_train() -> void:
	if selection.is_empty() or not selection[0].is_building or selection[0].queue.is_empty():
		return
	var item = selection[0]
	var unit_key = item.queue.pop_back()
	crystal_stock += int(config["units"][unit_key]["cost"])
	if item.queue.is_empty():
		item.train_time = 0.0
