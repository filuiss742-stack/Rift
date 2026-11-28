extends CharacterBody3D
# База для героини и врагов: здоровье, спрайт, отбрасывание, анимация.
# Кадры спрайта: 0 стоит, 1-2 шаг, 3 атака. Спрайт нарисован лицом вправо.

signal died(actor)

const Builder = preload("res://scripts/world/builder.gd")
const Fx = preload("res://scripts/combat/fx.gd")

var level = null
var max_hp: float = 10.0
var hp: float = 10.0
var alive: bool = true
var body_radius: float = 0.4
var sprite: Sprite3D = null
var knock: Vector3 = Vector3.ZERO
var flash_time: float = 0.0
var anim_time: float = 0.0
var attack_pose: float = 0.0
var base_tint: Color = Color.WHITE
var directional_enabled: bool = false
var directional_textures: Dictionary = {}

func build_body(sprite_name: String, radius: float, pixel_size: float) -> void:
	body_radius = radius
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	var shape = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 1.2
	shape.shape = cyl
	shape.position.y = 0.6
	add_child(shape)
	add_child(Builder.blob_shadow(radius * 1.2))
	sprite = Builder.make_sprite(sprite_name, 4, pixel_size)
	add_child(sprite)

func set_directional_textures(front_path: String, back_path: String, side_path: String) -> void:
	directional_textures = {
		"front": load(front_path) as Texture2D,
		"back": load(back_path) as Texture2D,
		"side": load(side_path) as Texture2D
	}
	if directional_textures["front"] == null or directional_textures["back"] == null or directional_textures["side"] == null:
		push_warning("Не удалось загрузить один из направленных спрайтов Лизы")
		directional_textures.clear()
		return
	directional_enabled = true
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.frame = 0
	sprite.texture = directional_textures["front"]

func _update_directional_sprite(dir: Vector3) -> void:
	if not directional_enabled or level == null or level.cam == null:
		return
	var camera_offset = level.cam.global_position - global_position
	var camera_direction = Vector2(camera_offset.x, camera_offset.z).normalized()
	var facing = Vector2(dir.x, dir.z).normalized()
	var dot_value = facing.dot(camera_direction)
	if dot_value > 0.45:
		sprite.texture = directional_textures["front"]
		sprite.flip_h = false
	elif dot_value < -0.45:
		sprite.texture = directional_textures["back"]
		sprite.flip_h = false
	else:
		sprite.texture = directional_textures["side"]
		sprite.flip_h = facing.cross(camera_direction) < 0.0
	sprite.frame = 0

func move_body(wanted: Vector3, delta: float) -> void:
	velocity = wanted + knock
	velocity.y = 0.0
	move_and_slide()
	position.y = 0.0
	if level != null:
		position = level.clamp_point(position, body_radius)
	knock = knock.move_toward(Vector3.ZERO, 40.0 * delta)

func face(dir: Vector3) -> void:
	if dir.length_squared() < 0.0025:
		return
	if directional_enabled:
		_update_directional_sprite(dir)
	elif absf(dir.x) > 0.05:
		sprite.flip_h = dir.x < 0.0

func animate(delta: float, moving: bool) -> void:
	anim_time += delta
	if directional_enabled:
		sprite.frame = 0
	elif attack_pose > 0.0:
		attack_pose -= delta
		sprite.frame = 3
	elif moving:
		sprite.frame = 1 + int(anim_time * 8.0) % 2
	else:
		sprite.frame = 0
	if flash_time > 0.0:
		flash_time -= delta
		sprite.modulate = Color(1.0, 0.35, 0.35)
	else:
		sprite.modulate = base_tint

# Возвращает true, если урон прошёл.
func take_damage(amount: float, from_pos: Vector3, force: float = 4.0) -> bool:
	if not alive:
		return false
	hp -= amount
	flash_time = 0.12
	var away = position - from_pos
	away.y = 0.0
	knock = away.normalized() * force
	Fx.floating_text(level, position, str(int(round(amount))), Color(1, 0.95, 0.75))
	if hp <= 0.0:
		hp = 0.0
		die()
	return true

func die() -> void:
	alive = false
	collision_layer = 0
	died.emit(self)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector3(1.3, 0.05, 1.0), 0.3)
	tween.tween_callback(queue_free)
