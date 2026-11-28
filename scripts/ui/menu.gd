extends CanvasLayer

signal chosen(what)

const Ui = preload("res://scripts/ui/ui_kit.gd")

func _ready() -> void:
	var screen = Ui.root(self)
	Ui.rect(screen, Vector2.ZERO, Vector2(1280, 720), Color(0.06, 0.03, 0.1))
	var art = TextureRect.new()
	art.texture = load("res://assets/sprites/crack.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(930, 90)
	art.size = Vector2(270, 540)
	screen.add_child(art)
	Ui.label(screen, "ИСКАЖЕНИЕ", Vector2(100, 110), Vector2(800, 90), 72, Color(1.0, 0.95, 0.97))
	Ui.label(screen, "Нулевая грань", Vector2(104, 200), Vector2(800, 50), 34, Color(0.95, 0.25, 0.4))
	var items = [["Новая игра", "new"], ["Продолжить", "continue"], ["Тест RTS-битвы", "rts"], ["Выход", "quit"]]
	for i in range(items.size()):
		var button = Ui.button(screen, items[i][0], Vector2(104, 310 + i * 68), Vector2(320, 52), 22)
		button.pressed.connect(_choose.bind(items[i][1]))
		if items[i][1] == "continue":
			button.disabled = not Game.has_save()

func _choose(what: String) -> void:
	chosen.emit(what)
