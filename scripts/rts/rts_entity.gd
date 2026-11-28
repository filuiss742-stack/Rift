extends Node3D
# Общая база юнитов и зданий RTS: здоровье, полоска HP, кольцо выделения.

signal destroyed(entity)

const Builder = preload("res://scripts/world/builder.gd")
const Fx = preload("res://scripts/combat/fx.gd")

var game = null
var key: String = ""
var stats: Dictionary = {}
var title: String = ""
var team: int = 0
var hp: float = 1.0
var max_hp: float = 1.0
var radius: float = 0.4
var alive: bool = true
var is_building: bool = false
var selected: bool = false
var ring: MeshInstance3D = null
var bar_back = null
var bar_fill = null
var bar_width: float = 1.0

func init_entity(ring_radius: float, bar_height: float, width: float) -> void:
	var color = Color(0.3, 1.0, 0.45) if team == 0 else Color(1.0, 0.25, 0.3)
	ring = Builder.ring(ring_radius, color)
	ring.visible = false
	add_child(ring)
	bar_width = width
	bar_back = _bar_quad(Color(0, 0, 0, 0.8), bar_height, 1)
	bar_fill = _bar_quad(color, bar_height, 2)
	refresh_bar()

func _bar_quad(color: Color, height: float, priority: int) -> MeshInstance3D:
	var mesh = QuadMesh.new()
	mesh.size = Vector2(bar_width, 0.12)
	var mat = Builder.material(color, true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.render_priority = priority
	var node = Builder.mesh_node(self, mesh, mat, Vector3(0, height, 0))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func refresh_bar() -> void:
	var show_bar = selected or hp < max_hp
	bar_back.visible = show_bar
	bar_fill.visible = show_bar
	bar_fill.mesh.size.x = maxf(bar_width * hp / max_hp, 0.01)

func set_selected(value: bool) -> void:
	selected = value
	ring.visible = value
	refresh_bar()

func take_damage(amount: float, _attacker = null) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		alive = false
		Fx.burst(game, position, radius * 1.8, Color(1.0, 0.5, 0.3, 0.7))
		destroyed.emit(self)
		queue_free()
	else:
		refresh_bar()
