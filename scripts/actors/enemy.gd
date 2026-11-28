extends "res://scripts/actors/actor.gd"
# Враг с ИИ: преследование -> замах с красным предупреждением -> удар -> отдых.
# Параметры берутся из data/enemies.json.

const Projectile = preload("res://scripts/combat/projectile.gd")

var kind: String = "husk"
var stats: Dictionary = {}
var state: String = "chase"
var timer: float = 0.0
var stun: float = 0.0
var strike_dir: Vector3 = Vector3.RIGHT
var charge_hit: bool = false
var hp_bar: Label3D = null

func setup(owner_level, enemy_kind: String) -> void:
	level = owner_level
	kind = enemy_kind
	stats = Game.enemies[kind]
	var pixel = float(stats["pixel"])
	build_body(str(stats["sprite"]), float(stats["radius"]), pixel)
	max_hp = float(stats["hp"])
	hp = max_hp
	timer = randf_range(0.2, 0.8)
	state = "recover"
	if not stats.get("boss", false):
		hp_bar = Builder.label("", sprite.texture.get_height() * pixel + 0.25, Color(1, 0.3, 0.35))
		hp_bar.font_size = 28
		add_child(hp_bar)
		_update_bar()

func _update_bar() -> void:
	if hp_bar != null:
		var filled = clampi(int(ceil(hp / max_hp * 8.0)), 0, 8)
		hp_bar.text = "|".repeat(filled) + ".".repeat(8 - filled)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	var wanted = Vector3.ZERO
	var hero = level.player
	if stun > 0.0:
		stun -= delta
	elif hero != null and hero.alive:
		var to_hero = hero.position - position
		to_hero.y = 0
		wanted = think(delta, to_hero)
	wanted += _separation()
	move_body(wanted, delta)
	animate(delta, wanted.length() > 0.5)

func _separation() -> Vector3:
	var push = Vector3.ZERO
	for other in level.living_enemies():
		if other == self:
			continue
		var diff = position - other.position
		var need = body_radius + other.body_radius
		if diff.length() < need and diff.length() > 0.01:
			push += diff.normalized() * (need - diff.length()) * 6.0
	return push

# Возвращает желаемую скорость.
func think(delta: float, to_hero: Vector3) -> Vector3:
	var dist = to_hero.length()
	var dir = to_hero.normalized()
	var speed = float(stats["speed"])
	var style = str(stats["attack"])
	timer -= delta
	match state:
		"chase":
			face(dir)
			if dist <= float(stats["range"]):
				_begin_windup(dir, dist)
				return Vector3.ZERO
			return dir * speed
		"windup":
			if timer <= 0.0:
				_strike()
		"charge":
			var hero = level.player
			if not charge_hit and position.distance_to(hero.position) < body_radius + hero.body_radius + 0.35:
				charge_hit = hero.take_damage(float(stats["damage"]), position, 12.0)
			if timer <= 0.0:
				_recover()
			else:
				return strike_dir * float(stats.get("charge_speed", 12.0))
		"recover":
			if timer <= 0.0:
				state = "chase"
			elif style == "ranged" and dist < 4.0:
				face(dir)
				return -dir * speed
	return Vector3.ZERO

func _begin_windup(dir: Vector3, dist: float) -> void:
	state = "windup"
	timer = float(stats["windup"])
	strike_dir = dir
	face(dir)
	match str(stats["attack"]):
		"melee":
			Fx.warn_circle(level, position + dir * 0.9, float(stats["hit_radius"]), timer)
		"charge":
			var length = float(stats.get("charge_speed", 12.0)) * float(stats.get("charge_time", 0.45))
			Fx.warn_line(level, position, dir, length, body_radius * 2.0 + 0.4, timer)
		"ranged":
			Fx.floating_text(level, position, "!", Color(1, 0.5, 0.8))

func _strike() -> void:
	attack_pose = 0.3
	var damage = float(stats["damage"])
	match str(stats["attack"]):
		"melee":
			var center = position + strike_dir * 0.9
			var radius = float(stats["hit_radius"])
			Fx.burst(level, center, radius, Color(1.0, 0.3, 0.3, 0.5))
			if center.distance_to(level.player.position) <= radius + level.player.body_radius * 0.5:
				level.player.take_damage(damage, position, 6.0)
			_recover()
		"charge":
			state = "charge"
			timer = float(stats.get("charge_time", 0.45))
			charge_hit = false
		"ranged":
			var aim_dir = level.player.position - position
			aim_dir.y = 0
			shoot(aim_dir.normalized(), float(stats.get("shot_speed", 9.0)), damage)
			_recover()

func shoot(dir: Vector3, speed: float, damage: float) -> void:
	var shot = Projectile.new()
	shot.level = level
	shot.direction = dir
	shot.speed = speed
	shot.damage = damage
	shot.position = position + dir * (body_radius + 0.3)
	level.add_child(shot)

func _recover() -> void:
	state = "recover"
	timer = float(stats["cooldown"])

func take_damage(amount: float, from_pos: Vector3, force: float = 4.0) -> bool:
	var poise = bool(stats.get("poise", false))
	var done = super.take_damage(amount, from_pos, force * (0.2 if poise else 1.0))
	if done and alive:
		_update_bar()
		if not poise:
			# Обычного врага удар сбивает с замаха.
			stun = 0.25
			if state == "windup" or state == "charge":
				_recover()
	return done
