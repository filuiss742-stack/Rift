extends RefCounted
# Фабрика визуала: 3D-постройки из примитивов и 2D-спрайты (billboard).

static func material(color: Color, unshaded: bool = false, glow: float = 0.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

static func mesh_node(parent: Node, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

static func box(parent: Node, size: Vector3, pos: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	return mesh_node(parent, mesh, material(color, false, glow), pos)

static func textured_box(parent: Node, size: Vector3, pos: Vector3, color: Color, texture_path: String, uv_scale: Vector3 = Vector3(2.0, 2.0, 1.0)) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var mat = material(color)
	if ResourceLoader.exists(texture_path):
		mat.albedo_texture = load(texture_path) as Texture2D
		mat.uv1_scale = uv_scale
	else:
		push_warning("Не найдена текстура: " + texture_path)
	return mesh_node(parent, mesh, mat, pos)

static func cylinder(parent: Node, top: float, bottom: float, height: float, pos: Vector3, color: Color, sides: int = 8) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	return mesh_node(parent, mesh, material(color), pos)

static func roof(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh = PrismMesh.new()
	mesh.size = size
	return mesh_node(parent, mesh, material(color), pos)

static func ring(radius: float, color: Color) -> MeshInstance3D:
	var mesh = TorusMesh.new()
	mesh.inner_radius = maxf(radius - 0.08, 0.05)
	mesh.outer_radius = radius
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color, true)
	node.position.y = 0.05
	node.scale.y = 0.2
	return node

static func blob_shadow(radius: float) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.01
	mesh.radial_segments = 16
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(Color(0, 0, 0, 0.35), true)
	node.position.y = 0.02
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

# Спрайт стоит "ногами" в точке (0,0,0) родителя и всегда смотрит на камеру.
static func make_sprite(sprite_name: String, frames: int, pixel_size: float) -> Sprite3D:
	var sprite = Sprite3D.new()
	var tex: Texture2D = load("res://assets/sprites/%s.png" % sprite_name)
	if tex == null:
		push_error("Нет спрайта: " + sprite_name)
		return sprite
	sprite.texture = tex
	sprite.hframes = frames
	sprite.pixel_size = pixel_size
	sprite.offset = Vector2(0, tex.get_height() / 2.0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	return sprite

static func label(text: String, height: float, color: Color = Color.WHITE) -> Label3D:
	var node = Label3D.new()
	node.text = text
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = true
	node.font_size = 40
	node.outline_size = 10
	node.pixel_size = 0.008
	node.modulate = color
	node.position.y = height
	return node

static func static_collider(parent: Node, size: Vector3, pos: Vector3) -> void:
	var body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)

# ---------- 3D-постройки ----------
# kind: house, ruin, tower, tent, wall, apartment, hq, barracks, rts_tower, rts_tent, heart, obelisk
static func building(kind: String, size: Vector3, wall_color: Color, roof_color: Color) -> Node3D:
	var root = Node3D.new()
	var w = size.x
	var h = size.y
	var d = size.z
	var dark = wall_color.darkened(0.45)
	match kind:
		"house", "barracks", "hq":
			box(root, Vector3(w, h, d), Vector3(0, h / 2, 0), wall_color)
			roof(root, Vector3(w + 0.5, h * 0.65, d + 0.5), Vector3(0, h + h * 0.325, 0), roof_color)
			box(root, Vector3(w * 0.22, h * 0.55, 0.1), Vector3(0, h * 0.275, d / 2 + 0.03), dark)
			for side in [-1.0, 1.0]:
				box(root, Vector3(w * 0.16, h * 0.22, 0.1), Vector3(side * w * 0.3, h * 0.55, d / 2 + 0.03), Color("#ffd77a"), 0.8)
			if kind == "hq":
				box(root, Vector3(0.1, 2.0, 0.1), Vector3(w * 0.4, h + 1.2, 0), dark)
				box(root, Vector3(0.9, 0.5, 0.05), Vector3(w * 0.4 + 0.5, h + 1.9, 0), Color("#4a7bd0"), 0.4)
			if kind == "barracks":
				box(root, Vector3(0.15, 1.1, 0.15), Vector3(-w * 0.6, 0.55, d * 0.4), dark)
				box(root, Vector3(0.7, 0.15, 0.15), Vector3(-w * 0.6, 0.85, d * 0.4), dark)
		"ruin":
			box(root, Vector3(w, h * 0.75, 0.35), Vector3(0, h * 0.375, -d / 2), wall_color)
			box(root, Vector3(0.35, h, d * 0.7), Vector3(-w / 2, h / 2, -d * 0.12), wall_color)
			box(root, Vector3(0.35, h * 0.4, d), Vector3(w / 2, h * 0.2, 0), wall_color)
			box(root, Vector3(w * 0.35, h * 0.28, 0.35), Vector3(-w * 0.3, h * 0.14, d / 2), wall_color)
			var beam = box(root, Vector3(w * 1.1, 0.18, 0.18), Vector3(0, h * 0.55, -d * 0.1), roof_color)
			beam.rotation_degrees = Vector3(0, 18, 22)
			box(root, Vector3(0.6, 0.35, 0.5), Vector3(w * 0.2, 0.17, d * 0.2), dark)
		"tower", "rts_tower":
			cylinder(root, w * 0.38, w * 0.5, h, Vector3(0, h / 2, 0), wall_color)
			cylinder(root, w * 0.55, w * 0.45, 0.35, Vector3(0, h + 0.15, 0), dark)
			cylinder(root, 0.0, w * 0.55, h * 0.4, Vector3(0, h + 0.3 + h * 0.2, 0), roof_color)
		"tent", "rts_tent":
			cylinder(root, 0.0, w * 0.6, h, Vector3(0, h / 2, 0), wall_color, 6)
			box(root, Vector3(w * 0.25, h * 0.4, 0.1), Vector3(0, h * 0.2, w * 0.42), dark)
		"wall":
			box(root, Vector3(w, h, d), Vector3(0, h / 2, 0), wall_color)
			var count = int(maxf(w, d))
			for i in range(count):
				var t = -0.5 + (i + 0.5) / count
				var top_pos = Vector3(t * w, h + 0.15, 0) if w >= d else Vector3(0, h + 0.15, t * d)
				if i % 2 == 0:
					box(root, Vector3(0.45, 0.3, 0.45), top_pos, dark)
		"apartment":
			box(root, Vector3(w, h, d), Vector3(0, h / 2, 0), wall_color)
			box(root, Vector3(w + 0.2, 0.2, d + 0.2), Vector3(0, h + 0.1, 0), roof_color)
			for row in range(int(h / 1.2)):
				for col in range(int(w / 1.2)):
					var lit = (row * 3 + col) % 4 == 0
					var win_color = Color("#ffd98a") if lit else Color("#1b2438")
					box(root, Vector3(0.55, 0.65, 0.08), Vector3(-w / 2 + 0.8 + col * 1.2, 0.8 + row * 1.2, d / 2 + 0.02), win_color, 0.7 if lit else 0.0)
		"heart":
			cylinder(root, w * 0.35, w * 0.55, h * 0.3, Vector3(0, h * 0.15, 0), wall_color, 6)
			cylinder(root, 0.0, w * 0.3, h * 0.5, Vector3(0, h * 0.8, 0), roof_color, 5)
			var core = cylinder(root, w * 0.3, 0.0, h * 0.3, Vector3(0, h * 0.4, 0), roof_color, 5)
			core.material_override = material(roof_color, false, 1.6)
			for i in range(4):
				var a = TAU * i / 4.0 + 0.5
				var spike = cylinder(root, 0.0, 0.3, h * 0.6, Vector3(cos(a) * w * 0.55, h * 0.3, sin(a) * w * 0.55), wall_color, 4)
				spike.rotation_degrees = Vector3(sin(a) * 15, 0, -cos(a) * 15)
		"obelisk":
			cylinder(root, w * 0.15, w * 0.4, h, Vector3(0, h / 2, 0), wall_color, 4)
			box(root, Vector3(w * 0.4, w * 0.4, w * 0.4), Vector3(0, h + 0.35, 0), roof_color, 1.4).rotation_degrees = Vector3(45, 45, 0)
		_:
			box(root, size, Vector3(0, h / 2, 0), wall_color)
	return root
