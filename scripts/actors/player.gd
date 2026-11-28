extends "res://scripts/actors/actor.gd"
# Героиня в теле Миры. Бой в реальном времени: комбо, уворот, навыки, Искажение.

signal defeated

# damage — множитель урона, range — дальность, arc — угол, time — длительность
const COMBO = [
	{"damage": 1.0, "range": 2.1, "arc": 120.0, "time": 0.28, "lunge": 4.0, "force": 4.0},
	{"damage": 1.15, "range": 2.1, "arc": 120.0, "time": 0.28, "lunge": 4.0, "force": 4.0},
	{"damage": 1.9, "range": 2.7, "arc": 190.0, "time": 0.46, "lunge": 6.0, "force": 10.0},
]
const SPEED = 6.0
const DODGE_SPEED = 15.0
const DODGE_TIME = 0.22

var cam = null
var energy: float = 100.0
var stamina: float = 100.0
var distortion: float = 0.0
var distortion_hold: float = 0.0
var aim: Vector3 = Vector3.RIGHT

var combo_step: int = 0
var combo_reset: float = 0.0
var attack_time: float = 0.0
var hit_delay: float = -1.0
var queued_attack: bool = false

var dodge_time: float = 0.0
var dodge_age: float = 99.0
var dodge_dir: Vector3 = Vector3.RIGHT
var invul: float = 0.0
var perfect_used: bool = false
var slow_until: int = 0

var cd_q: float = 0.0
var cd_e: float = 0.0
var echo_time: float = 0.0
var tea_save_ready: bool = true
var input_grace: float = 0.2

func setup(owner_level) -> void:
	level = owner_level
	var data = level.data
	var sprite_name = "liza" if data.get("world", "") == "earth" else "mira"
	build_body(sprite_name, 0.4, 0.0043)
	if data.get("world", "") == "earth":
		set_directional_textures(
			"res://assets/sprites/lisa_idle_front.svg",
			"res://assets/sprites/lisa_idle_back.svg",
			"res://assets/sprites/lisa_idle_side.svg"
		)
	max_hp = Game.hero_max_hp()
	hp = max_hp

func can_fight() -> bool:
	return level.data.get("world", "") != "earth"

func damage_multiplier() -> float:
	var mult = 1.0 + distortion * 0.004
	if echo_time > 0.0:
		mult += 0.5
	return mult

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_update_slowmo()
	_update_timers(delta)
	var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move = Vector3(input.x, 0, input.y)
	if cam != null:
		var to_mouse = cam.mouse_on_ground() - position
		to_mouse.y = 0
		if to_mouse.length() > 0.2:
			aim = to_mouse.normalized()

	if input_grace > 0.0:
		input_grace -= delta
	elif can_fight():
		_read_actions(move)

	var wanted = Vector3.ZERO
	if dodge_time > 0.0:
		wanted = dodge_dir * DODGE_SPEED
	elif attack_time > 0.0:
		var step = COMBO[combo_step]
		if hit_delay > 0.0:
			wanted = aim * step["lunge"]
		face(aim)
	else:
		wanted = move * SPEED
		if move.length() > 0.1:
			face(move)
	move_body(wanted, delta)
	animate(delta, move.length() > 0.1)

func _update_slowmo() -> void:
	if slow_until > 0 and Time.get_ticks_msec() >= slow_until:
		slow_until = 0
		Engine.time_scale = 1.0

func _update_timers(delta: float) -> void:
	cd_q = maxf(cd_q - delta, 0.0)
	cd_e = maxf(cd_e - delta, 0.0)
	invul = maxf(invul - delta, 0.0)
	energy = minf(energy + 8.0 * delta, 100.0)
	stamina = minf(stamina + 32.0 * delta, 100.0)
	dodge_age += delta
	if dodge_time > 0.0:
		dodge_time -= delta
	if distortion_hold > 0.0:
		distortion_hold -= delta
	else:
		distortion = maxf(distortion - 3.0 * delta, 0.0)
	if echo_time > 0.0:
		echo_time -= delta
		hp = minf(hp + max_hp * 0.03 * delta, max_hp)
		if echo_time <= 0.0:
			base_tint = Color.WHITE
	if combo_reset > 0.0:
		combo_reset -= delta
		if combo_reset <= 0.0 and attack_time <= 0.0:
			combo_step = 0
	if hit_delay > 0.0:
		hit_delay -= delta
		if hit_delay <= 0.0:
			_do_combo_hit()
	if attack_time > 0.0:
		attack_time -= delta
		if attack_time <= 0.0:
			combo_step = (combo_step + 1) % COMBO.size()
			combo_reset = 0.6
			if queued_attack:
				queued_attack = false
				_start_attack()

func _read_actions(move: Vector3) -> void:
	if Input.is_action_just_pressed("dodge") and dodge_time <= 0.0 and stamina >= 25.0:
		_start_dodge(move)
	if Input.is_action_just_pressed("attack"):
		if attack_time > 0.0:
			queued_attack = true
		elif dodge_time <= 0.0:
			_start_attack()
	if Input.is_action_just_pressed("skill_1"):
		_skill_white_crack()
	if Input.is_action_just_pressed("skill_2"):
		_skill_red_distortion()
	if Input.is_action_just_pressed("skill_3"):
		_skill_tea_echo()
	if Input.is_action_just_pressed("potion"):
		_drink_potion()

func _start_attack() -> void:
	attack_time = COMBO[combo_step]["time"]
	hit_delay = 0.09
	attack_pose = attack_time

func _do_combo_hit() -> void:
	var step = COMBO[combo_step]
	var color = Color(0.85, 0.9, 1.0, 0.75) if combo_step < 2 else Color(1.0, 0.25, 0.4, 0.8)
	Fx.slash(level, position, aim, step["range"], step["arc"], color)
	var hits = 0
	for foe in level.living_enemies():
		var diff = foe.position - position
		diff.y = 0
		if diff.length() > step["range"] + foe.body_radius:
			continue
		if diff.length() > 0.8 and rad_to_deg(aim.angle_to(diff)) > step["arc"] / 2.0:
			continue
		if foe.take_damage(Game.hero_attack() * step["damage"] * damage_multiplier(), position, step["force"]):
			hits += 1
	if hits > 0:
		energy = minf(energy + 6.0 * hits, 100.0)
		cam.shake = 0.1 if combo_step < 2 else 0.25

func _start_dodge(move: Vector3) -> void:
	stamina -= 25.0
	dodge_time = DODGE_TIME
	dodge_age = 0.0
	perfect_used = false
	invul = maxf(invul, 0.3)
	dodge_dir = move.normalized() if move.length() > 0.1 else aim
	attack_time = 0.0
	hit_delay = -1.0
	attack_pose = 0.0
	queued_attack = false
	Fx.burst(level, position, 0.6, Color(0.8, 0.8, 1.0, 0.5))

func _add_distortion(amount: float) -> void:
	distortion = minf(distortion + amount, 100.0)
	distortion_hold = 4.0

# Q: рывок-разрез, поражает всех на линии.
func _skill_white_crack() -> void:
	if cd_q > 0.0 or energy < 30.0:
		return
	energy -= 30.0
	cd_q = 4.0
	invul = maxf(invul, 0.35)
	var start = position
	attack_pose = 0.25
	face(aim)
	move_and_collide(aim * 5.5)
	position.y = 0.0
	position = level.clamp_point(position, body_radius)
	Fx.line_flash(level, start, position, 0.7, Color(1, 1, 1, 0.9))
	for foe in level.living_enemies():
		var near = Geometry3D.get_closest_point_to_segment(foe.position, start, position)
		if near.distance_to(foe.position) <= foe.body_radius + 1.0:
			foe.take_damage(Game.hero_attack() * 2.4 * damage_multiplier(), start, 6.0)
	_add_distortion(12.0)

# E: взрыв красного искажения вокруг.
func _skill_red_distortion() -> void:
	if cd_e > 0.0 or energy < 40.0:
		return
	energy -= 40.0
	cd_e = 8.0
	attack_pose = 0.3
	Fx.burst(level, position, 4.2, Color(0.95, 0.08, 0.25, 0.65))
	cam.shake = 0.3
	for foe in level.living_enemies():
		if foe.position.distance_to(position) <= 4.2 + foe.body_radius:
			foe.take_damage(Game.hero_attack() * 2.1 * damage_multiplier(), position, 13.0)
	_add_distortion(25.0)

# R: открывается по сюжету. Тратит всё Искажение.
func _skill_tea_echo() -> void:
	if not Game.flags.get("tea_awakened", false):
		level.toast("Что-то внутри ещё спит...")
		return
	if distortion < 60.0:
		level.toast("Нужно хотя бы 60 Искажения")
		return
	distortion = 0.0
	echo_time = 8.0
	base_tint = Color(1.0, 0.65, 0.75)
	Fx.burst(level, position, 3.0, Color(1, 0.4, 0.6, 0.8))
	level.toast("Отголосок Теи: урон +50%, раны затягиваются")

func _drink_potion() -> void:
	if Game.potions <= 0 or hp >= max_hp:
		return
	Game.potions -= 1
	var heal = max_hp * 0.45
	hp = minf(hp + heal, max_hp)
	Fx.floating_text(level, position, "+%d" % int(heal), Color(0.4, 1.0, 0.5))

func take_damage(amount: float, from_pos: Vector3, force: float = 4.0) -> bool:
	if not alive:
		return false
	if invul > 0.0:
		# Идеальный уворот: удар пришёлся на самое начало рывка.
		if dodge_age < 0.18 and not perfect_used:
			perfect_used = true
			energy = minf(energy + 25.0, 100.0)
			Engine.time_scale = 0.35
			slow_until = Time.get_ticks_msec() + 550
			Fx.floating_text(level, position, "ИДЕАЛЬНЫЙ УВОРОТ", Color(0.6, 0.9, 1.0))
		return false
	hp -= amount
	flash_time = 0.15
	invul = 0.45
	var away = position - from_pos
	away.y = 0.0
	knock = away.normalized() * force
	_add_distortion(6.0)
	cam.shake = 0.2
	Fx.floating_text(level, position, str(int(round(amount))), Color(1.0, 0.35, 0.35))
	if hp <= 0.0:
		if tea_save_ready:
			# Сюжетная живучесть: один раз за уровень героиня не умирает.
			tea_save_ready = false
			hp = max_hp * 0.35
			invul = 2.0
			Fx.burst(level, position, 3.5, Color(1.0, 0.1, 0.3, 0.7))
			level.toast("...Это должно было меня убить.")
		else:
			die()
	return true

func die() -> void:
	alive = false
	hp = 0.0
	Engine.time_scale = 1.0
	sprite.modulate = Color(0.5, 0.1, 0.2)
	sprite.frame = 0
	defeated.emit()

func on_level_up() -> void:
	max_hp = Game.hero_max_hp()
	hp = max_hp
	Fx.floating_text(level, position, "УРОВЕНЬ %d" % Game.hero_level, Color(1.0, 0.85, 0.3))

func _exit_tree() -> void:
	Engine.time_scale = 1.0
