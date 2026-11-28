extends Control
# Рамка выделения поверх экрана.

var game = null

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null or not game.dragging:
		return
	var area = Rect2(game.drag_start, get_viewport().get_mouse_position() - game.drag_start).abs()
	draw_rect(area, Color(0.3, 1.0, 0.45, 0.15))
	draw_rect(area, Color(0.3, 1.0, 0.45, 0.9), false)
