extends "res://scripts/rts/rts_entity.gd"
# Юнит RTS. Приказы: idle, move, attack_move, attack, gather, build.

const CARRY = 10
const MINE_TIME = 2.0

var sprite: Sprite3D = null
var order: String = "idle"
var after_attack: String = "idle"
var target = null
var site = null
var crystal = null
var carry: int = 0
var work: float = 0.0
var move_point: Vector3 = Vector3.ZERO
var cooldown: float = 0.0
var scan: float = 0.0
var anim_time: float = 0.0
var attack_pose: float = 0.0
var moving: bool = false
var stuck_time: float = 0.0
var best_distance: float = 99999.0

func setup(owner_game, unit_key: String, unit_team: int) -> void:
	game = owner_game
	key = unit_key
	team = unit_team
	stats = Game.rts["units"][key]
	title = str(stats["title"])
	radius = float(stats["radius"])
	max_hp = float(stats["hp"])
	hp = max_hp
	var pixel = float(stats["pixel"])
	add_child(Builder.blob_shadow(radius))
	sprite = Builder.make_sprite(str(stats["sprite"]), 4, pixel)
	add_child(sprite)
	init_entity(radius + 0.2, sprite.texture.get_height() * pixel + 0.2, radius * 2.2)
	scan = randf() * 0.3

func damage_value() -> float:
	var value = float(stats["damage"])
	if key == "hero":
		value += 3.0 * (Game.hero_level - 1)
	return value

func is_worker() -> bool:
	return key == "worker"

# ---------- Приказы ----------
func _new_order(kind: String) -> void:
	order = kind
	after_attack = "idle"
	target = null
	stuck_time = 0.0
	best_distance = 99999.0

func command_move(point: Vector3) -> void:
	_new_order("move")
	move_point = point

func command_attack_move(point: Vector3) -> void:
	if is_worker():
		command_move(point)
		return
	_new_order("attack_move")
	move_point = point

func command_attack(enemy) -> void:
	_new_order("attack")
	target = enemy

func command_gather(node: Dictionary) -> void:
	_new_order("gather")
	crystal = node
	work = 0.0

func command_build(building) -> void:
	_new_order("build")
	site = building

func command_stop() -> void:
	_new_order("idle")

func take_damage(amount: float, attacker = null) -> void:
	super.take_damage(amount, attacker)
	# Свободный боец отвечает обидчику.
	if alive and order == "idle" and not is_worker() and game.is_valid_target(attacker):
		command_attack(attacker)

# ---------- Симуляция (вызывается из rts_mode) ----------
func tick(delta: float) -> void:
	cooldown -= delta
	scan -= delta
	moving = false
	match order:
		"idle":
			_look_for_enemy("idle")
		"move":
			if _go(move_point, 0.4, delta):
				order = "idle"
		"attack_move":
			if not _look_for_enemy("attack_move") and _go(move_point, 0.8, delta):
				order = "idle"
		"attack":
			_tick_attack(delta)
		"gather":
			_tick_gather(delta)
		"build":
			_tick_build(delta)
	_animate(delta)

func _look_for_enemy(then: String) -> bool:
	if scan > 0.0 or is_worker():
		return false
	scan = 0.3
	var found = game.nearest_enemy(position, team, float(stats["sight"]))
	if found == null:
		return false
	order = "attack"
	after_attack = then
	target = found
	return true

func _gap(other) -> float:
	return position.distance_to(other.position) - other.radius - radius

func _tick_attack(delta: float) -> void:
	if not game.is_valid_target(target):
		target = null
		order = after_attack
		after_attack = "idle"
		scan = 0.0
		stuck_time = 0.0
		best_distance = 99999.0
		return
	# В атаке по пути переключаемся с зданий на подошедших бойцов.
	if after_attack == "attack_move" and target.is_building and scan <= 0.0:
		scan = 0.5
		var better = game.nearest_enemy(position, team, float(stats["sight"]))
		if better != null:
			target = better
	if _gap(target) <= float(stats["range"]):
		_face(target.position - position)
		if cooldown <= 0.0:
			cooldown = float(stats["cooldown"])
			attack_pose = 0.25
			if float(stats["range"]) > 3.0:
				var color = Color(1.0, 0.9, 0.6, 0.9) if team == 0 else Color(1.0, 0.25, 0.55, 0.9)
				Fx.line_flash(game, position, target.position, 0.08, color)
			target.take_damage(damage_value(), self)
	else:
		_step(target.position, delta)

func _tick_gather(delta: float) -> void:
	if carry >= CARRY or (crystal == null and carry > 0):
		var base = game.player_hq
		if not game.is_valid_target(base):
			order = "idle"
		elif _gap(base) <= 0.5:
			game.crystal_stock += carry
			carry = 0
		else:
			_step(base.position, delta)
		return
	if crystal == null or crystal["amount"] <= 0:
		crystal = game.nearest_crystal(position)
		if crystal == null:
			order = "idle"
		return
	if position.distance_to(crystal["pos"]) <= 0.9 + radius + 0.4:
		_face(crystal["pos"] - position)
		work += delta
		attack_pose = 0.1 if fmod(work, 0.5) < 0.25 else 0.0
		if work >= MINE_TIME:
			work = 0.0
			carry = mini(CARRY, int(crystal["amount"]))
			game.mine(crystal, carry)
	else:
		_step(crystal["pos"], delta)

func _tick_build(delta: float) -> void:
	if not game.is_valid_target(site) or site.is_complete():
		# После стройки возвращаемся к добыче.
		site = null
		var node = game.nearest_crystal(position)
		if node != null:
			command_gather(node)
		else:
			order = "idle"
		return
	if _gap(site) <= 0.6:
		_face(site.position - position)
		attack_pose = 0.1 if fmod(anim_time, 0.5) < 0.25 else 0.0
		site.construct(delta)
	else:
		_step(site.position, delta)

# Идти к точке. true — пришли (или дальше пройти нельзя).
func _go(point: Vector3, stop_distance: float, delta: float) -> bool:
	var dist = position.distance_to(point)
	if dist <= stop_distance:
		return true
	if dist < best_distance - 0.2:
		best_distance = dist
		stuck_time = 0.0
	else:
		stuck_time += delta
	if stuck_time > 2.5 and dist < 4.0:
		return true
	_step(point, delta)
	return false

func _step(point: Vector3, delta: float) -> void:
	var to = point - position
	to.y = 0
	if to.length() < 0.05:
		return
	var dir = to.normalized()
	for obstacle in game.obstacle_list:
		var center = obstacle["pos"]
		var size = float(obstacle["radius"])
		if center.distance_to(point) < size + 0.5:
			continue
		var away = center - position
		if away.length() < size + radius + 0.8 and away.dot(dir) > 0.0:
			var side = Vector3(-away.z, 0, away.x).normalized()
			if side.dot(dir) < 0.0:
				side = -side
			dir = (dir * 0.25 + side).normalized()
	position += dir * float(stats["speed"]) * delta
	moving = true
	_face(dir)

func _face(dir: Vector3) -> void:
	if absf(dir.x) > 0.1:
		sprite.flip_h = dir.x < 0.0

func _animate(delta: float) -> void:
	anim_time += delta
	if attack_pose > 0.0:
		attack_pose -= delta
		sprite.frame = 3
	elif moving:
		sprite.frame = 1 + int(anim_time * 8.0) % 2
	else:
		sprite.frame = 0
