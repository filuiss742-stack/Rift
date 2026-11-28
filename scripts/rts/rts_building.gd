extends "res://scripts/rts/rts_entity.gd"
# Здание: строительство, очередь найма, стрельба башен.

var visual: Node3D = null
var progress: float = 1.0
var queue: Array = []
var train_time: float = 0.0
var cooldown: float = 0.0
var rally: Vector3 = Vector3.ZERO

func setup(owner_game, building_key: String, building_team: int) -> void:
	game = owner_game
	key = building_key
	team = building_team
	is_building = true
	stats = Game.rts["buildings"][key]
	title = str(stats["title"])
	var size = Vector3(float(stats["size"][0]), float(stats["size"][1]), float(stats["size"][2]))
	radius = maxf(size.x, size.z) * 0.55
	max_hp = float(stats["hp"])
	hp = max_hp
	visual = Builder.building(str(stats["kind"]), size, Color(str(stats["color"])), Color(str(stats["roof"])))
	add_child(visual)
	init_entity(radius + 0.2, size.y * 1.7 + 0.6, radius * 1.8)
	var side = 1.0 if team == 0 else -1.0
	rally = position + Vector3(side * (radius + 1.5), 0, 1.0)

func is_complete() -> bool:
	return progress >= 1.0

func start_site() -> void:
	progress = 0.0
	hp = max_hp * 0.1
	visual.scale.y = 0.2
	refresh_bar()

func construct(delta: float) -> void:
	if is_complete():
		return
	var part = delta / float(stats["time"])
	progress = minf(progress + part, 1.0)
	hp = minf(hp + max_hp * 0.9 * part, max_hp)
	visual.scale.y = lerpf(0.2, 1.0, progress)
	refresh_bar()
	if is_complete():
		game.toast("Построено: " + title)

func tick(delta: float) -> void:
	if not is_complete():
		return
	if not queue.is_empty():
		train_time += delta
		var unit_key = str(queue[0])
		if train_time >= float(Game.rts["units"][unit_key]["time"]):
			train_time = 0.0
			queue.pop_front()
			var angle = randf_range(-0.6, 0.6)
			var door = position + Vector3(sin(angle), 0, cos(angle)) * (radius + 0.6)
			var unit = game.spawn_unit(unit_key, team, door)
			if unit.is_worker():
				var node = game.nearest_crystal(unit.position)
				if node != null:
					unit.command_gather(node)
			else:
				unit.command_attack_move(rally)
	if stats.has("damage"):
		cooldown -= delta
		if cooldown <= 0.0:
			var foe = game.nearest_enemy(position, team, float(stats["range"]))
			if foe != null:
				cooldown = float(stats["cooldown"])
				var color = Color(0.6, 0.85, 1.0, 0.9) if team == 0 else Color(1.0, 0.2, 0.4, 0.9)
				Fx.line_flash(game, position + Vector3(0, 2.0, 0), foe.position, 0.1, color)
				foe.take_damage(float(stats["damage"]), self)
			else:
				cooldown = 0.3
