extends RefCounted
# Боевые эффекты: цифры урона, дуга удара, предупреждения об атаках, взрывы.

const Builder = preload("res://scripts/world/builder.gd")

static func floating_text(parent: Node, pos: Vector3, text: String, color: Color) -> void:
	var node = Builder.label(text, 0.0, color)
	node.position = pos + Vector3(randf_range(-0.3, 0.3), 1.8, 0)
	parent.add_child(node)
	var tween = node.create_tween()
	tween.tween_property(node, "position:y", node.position.y + 1.0, 0.7)
	tween.tween_callback(node.queue_free)

static func _sector_mesh(radius: float, arc_deg: float) -> ArrayMesh:
	# Сектор лежит на земле и смотрит в сторону +X.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps = 20
	var half = deg_to_rad(arc_deg) / 2.0
	for i in range(steps):
		var a0 = lerpf(-half, half, float(i) / steps)
		var a1 = lerpf(-half, half, float(i + 1) / steps)
		var in0 = Vector3(cos(a0), 0, sin(a0)) * radius * 0.45
		var in1 = Vector3(cos(a1), 0, sin(a1)) * radius * 0.45
		var out0 = Vector3(cos(a0), 0, sin(a0)) * radius
		var out1 = Vector3(cos(a1), 0, sin(a1)) * radius
		for v in [in0, out0, out1, in0, out1, in1]:
			st.add_vertex(v)
	return st.commit()

static func _flat(parent: Node, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mat = Builder.material(color, true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node = Builder.mesh_node(parent, mesh, mat, pos)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static func _fade(node: MeshInstance3D, duration: float) -> void:
	var tween = node.create_tween()
	tween.tween_property(node.material_override, "albedo_color:a", 0.0, duration)
	tween.tween_callback(node.queue_free)

static func slash(parent: Node, pos: Vector3, dir: Vector3, radius: float, arc_deg: float, color: Color) -> void:
	var node = _flat(parent, _sector_mesh(radius, arc_deg), color, pos + Vector3(0, 0.5, 0))
	node.rotation.y = atan2(-dir.z, dir.x)
	_fade(node, 0.18)

static func _disc(radius: float) -> CylinderMesh:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	return mesh

# Красный круг: внутренний растёт, пока не заполнит внешний — в этот момент удар.
static func warn_circle(parent: Node, pos: Vector3, radius: float, duration: float) -> void:
	var outer = _flat(parent, _disc(radius), Color(1, 0.1, 0.15, 0.22), Vector3(pos.x, 0.04, pos.z))
	var inner = _flat(parent, _disc(radius), Color(1, 0.15, 0.2, 0.45), Vector3(pos.x, 0.06, pos.z))
	inner.scale = Vector3(0.05, 1, 0.05)
	var tween = inner.create_tween()
	tween.tween_property(inner, "scale", Vector3.ONE, duration)
	tween.tween_callback(inner.queue_free)
	var tween2 = outer.create_tween()
	tween2.tween_interval(duration)
	tween2.tween_callback(outer.queue_free)

static func warn_line(parent: Node, from: Vector3, dir: Vector3, length: float, width: float, duration: float) -> void:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(length, 0.02, width)
	var mid = from + dir * (length / 2.0)
	var node = _flat(parent, mesh, Color(1, 0.1, 0.15, 0.3), Vector3(mid.x, 0.05, mid.z))
	node.rotation.y = atan2(-dir.z, dir.x)
	var tween = node.create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(node.queue_free)

static func line_flash(parent: Node, from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var diff = to - from
	if diff.length() < 0.1:
		return
	var mesh = BoxMesh.new()
	mesh.size = Vector3(diff.length(), 0.05, width)
	var node = _flat(parent, mesh, color, (from + to) / 2.0 + Vector3(0, 0.6, 0))
	node.rotation.y = atan2(-diff.z, diff.x)
	_fade(node, 0.3)

static func burst(parent: Node, pos: Vector3, radius: float, color: Color) -> void:
	var node = _flat(parent, _disc(radius), color, Vector3(pos.x, 0.1, pos.z))
	node.scale = Vector3(0.2, 1, 0.2)
	var tween = node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE, 0.18)
	tween.tween_property(node.material_override, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(node.queue_free)
