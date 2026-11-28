extends Control
# Миникарта. Клик или перетаскивание переносят камеру.

var game = null

func _process(_delta: float) -> void:
	queue_redraw()

func _to_map(point: Vector3) -> Vector2:
	return Vector2((point.x / game.half.x + 1.0) * 0.5 * size.x, (point.z / game.half.y + 1.0) * 0.5 * size.y)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.14, 0.11, 0.17))
	if game == null:
		return
	for node in game.crystals:
		draw_circle(_to_map(node["pos"]), 3.0, Color(0.4, 0.9, 1.0))
	for item in game.buildings:
		if item.alive:
			var color = Color(0.3, 0.7, 1.0) if item.team == 0 else Color(1.0, 0.2, 0.35)
			draw_rect(Rect2(_to_map(item.position) - Vector2(4, 4), Vector2(8, 8)), color)
	for unit in game.units:
		if unit.alive:
			var color = Color(0.4, 1.0, 0.5) if unit.team == 0 else Color(1.0, 0.4, 0.4)
			if unit.key == "hero":
				color = Color.WHITE
			draw_circle(_to_map(unit.position), 2.0, color)
	var view = _to_map(game.cam.focus)
	draw_rect(Rect2(view - Vector2(26, 16), Vector2(52, 32)), Color(1, 1, 1, 0.8), false)

func _gui_input(event: InputEvent) -> void:
	var click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var drag = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if click or drag:
		var ratio = event.position / size
		game.move_camera_to(Vector3((ratio.x * 2.0 - 1.0) * game.half.x, 0, (ratio.y * 2.0 - 1.0) * game.half.y))
		accept_event()
