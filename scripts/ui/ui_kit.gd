extends RefCounted
# Мелкие помощники для интерфейса. Экран всегда 1280x720 (растягивается сам).

static func root(layer_node: Node) -> Control:
	var node = Control.new()
	node.size = Vector2(1280, 720)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_node.add_child(node)
	return node

static func rect(parent: Node, pos: Vector2, size: Vector2, color: Color, blocks_mouse: bool = false) -> ColorRect:
	var node = ColorRect.new()
	node.position = pos
	node.size = size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_STOP if blocks_mouse else Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func label(parent: Node, text: String, pos: Vector2, size: Vector2, font_size: int = 18, color: Color = Color.WHITE, centered: bool = false) -> Label:
	var node = Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	node.add_theme_constant_override("outline_size", 5)
	if centered:
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.position = pos
	node.size = size
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, pos: Vector2, size: Vector2, font_size: int = 20) -> Button:
	var node = Button.new()
	node.text = text
	node.position = pos
	node.size = size
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", font_size)
	parent.add_child(node)
	return node

static func _style(color: Color) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(4)
	return box

static func bar(parent: Node, pos: Vector2, size: Vector2, color: Color) -> ProgressBar:
	var node = ProgressBar.new()
	node.show_percentage = false
	node.step = 0.0
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.6)))
	node.add_theme_stylebox_override("fill", _style(color))
	node.position = pos
	node.size = size
	parent.add_child(node)
	return node
