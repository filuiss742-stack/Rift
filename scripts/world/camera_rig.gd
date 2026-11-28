extends Camera3D
# Камера "сверху под углом", плавно следует за целью.

var follow: Node3D = null
var offset_vec: Vector3 = Vector3(0, 13.0, 10.0)
var shake: float = 0.0
var focus: Vector3 = Vector3.ZERO

func _ready() -> void:
	fov = 40.0
	current = true
	rotation = Vector3(-atan2(offset_vec.y - 0.5, offset_vec.z), 0, 0)

func snap(point: Vector3) -> void:
	focus = point
	position = focus + offset_vec

func _process(delta: float) -> void:
	if follow != null and is_instance_valid(follow):
		focus = focus.lerp(follow.position, minf(1.0, 8.0 * delta))
	position = focus + offset_vec
	if shake > 0.0:
		position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake
		shake = move_toward(shake, 0.0, delta * 1.2)

func mouse_on_ground() -> Vector3:
	var mouse = get_viewport().get_mouse_position()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(project_ray_origin(mouse), project_ray_normal(mouse))
	if hit == null:
		return focus
	return hit
