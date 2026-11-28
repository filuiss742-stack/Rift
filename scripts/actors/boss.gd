extends "res://scripts/actors/enemy.gd"
# Босс "Страж Трещины": три фазы.

var phase: int = 1
var pending: Array = []
var summoned: bool = false
var attack_index: int = 0

func think(delta: float, to_hero: Vector3) -> Vector3:
	_update_pending(delta)
	_check_phase()
	timer -= delta
	var dist = to_hero.length()
	var dir = to_hero.normalized()
	face(dir)
	if state == "casting":
		if timer <= 0.0:
			state = "recover"
			timer = float(stats["cooldown"]) - 0.25 * (phase - 1)
		return Vector3.ZERO
	if state == "chase" or timer <= 0.0:
		_choose_attack(dist)
		return Vector3.ZERO
	if dist > 3.0:
		return dir * float(stats["speed"]) * (1.0 + 0.2 * (phase - 1))
	return Vector3.ZERO

func _check_phase() -> void:
	var ratio = hp / max_hp
	if phase == 1 and ratio < 0.66:
		phase = 2
		level.toast("Страж трескается. Из ран льётся красный свет!")
		if not summoned:
			summoned = true
			level.spawn_enemy("husk", position + Vector3(3, 0, 1))
			level.spawn_enemy("husk", position + Vector3(-3, 0, 1))
	elif phase == 2 and ratio < 0.33:
		phase = 3
		base_tint = Color(1.0, 0.7, 0.7)
		level.toast("Нулевая грань открывается!")

func _choose_attack(dist: float) -> void:
	state = "casting"
	attack_pose = 0.6
	attack_index += 1
	var choice = attack_index % (phase + 1)
	if dist < 3.8 and choice != 2:
		_slam()
	elif choice == 2:
		_rifts()
	elif choice == 3:
		_ring()
	else:
		_volley()

func _delayed_circle(pos: Vector3, radius: float, delay: float, damage: float) -> void:
	Fx.warn_circle(level, pos, radius, delay)
	pending.append({"time": delay, "pos": pos, "radius": radius, "damage": damage})

func _slam() -> void:
	timer = 1.0
	_delayed_circle(position, 3.8, 0.9, float(stats["damage"]) * 1.3)

func _rifts() -> void:
	timer = 1.6
	var target = level.player.position
	for i in range(4):
		var spread = Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)) if i > 0 else Vector3.ZERO
		_delayed_circle(target + spread, 1.7, 0.8 + 0.25 * i, float(stats["damage"]))

func _volley() -> void:
	timer = 0.7
	var base = level.player.position - position
	base.y = 0
	base = base.normalized()
	var count = 1 + phase * 2
	for i in range(count):
		var angle = (i - (count - 1) / 2.0) * 0.22
		shoot(base.rotated(Vector3.UP, angle), 9.0, float(stats["damage"]) * 0.6)

func _ring() -> void:
	timer = 0.9
	var shift = randf() * TAU
	for i in range(14):
		var angle = shift + TAU * i / 14.0
		shoot(Vector3(cos(angle), 0, sin(angle)), 6.0, float(stats["damage"]) * 0.6)

func _update_pending(delta: float) -> void:
	for i in range(pending.size() - 1, -1, -1):
		var item = pending[i]
		item["time"] -= delta
		if item["time"] <= 0.0:
			Fx.burst(level, item["pos"], item["radius"], Color(1.0, 0.9, 0.95, 0.7))
			var diff = level.player.position - item["pos"]
			diff.y = 0
			if diff.length() <= item["radius"]:
				level.player.take_damage(item["damage"], item["pos"], 8.0)
			pending.remove_at(i)
