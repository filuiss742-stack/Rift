extends Node3D
# Снаряд врага. Во время уворота пролетает сквозь героиню.

const Builder = preload("res://scripts/world/builder.gd")

var level = null
var direction: Vector3 = Vector3.RIGHT
var speed: float = 8.0
var damage: float = 8.0
var life: float = 4.0

func _ready() -> void:
	var mesh = SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	var orb = Builder.mesh_node(self, mesh, Builder.material(Color("#ff3d7f"), true), Vector3(0, 0.8, 0))
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(Builder.blob_shadow(0.2))

func _physics_process(delta: float) -> void:
	life -= delta
	position += direction * speed * delta
	if life <= 0.0 or level == null or level.is_blocked(position):
		queue_free()
		return
	var hero = level.player
	if hero != null and hero.alive:
		var flat = hero.position - position
		flat.y = 0
		if flat.length() < hero.body_radius + 0.22:
			if hero.take_damage(damage, position - direction, 3.0):
				queue_free()
