extends CanvasLayer
# Пауза, смерть, победа.

signal chosen(what)

const Ui = preload("res://scripts/ui/ui_kit.gd")

var title_text: String = ""
var buttons: Array = []

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var screen = Ui.root(self)
	Ui.rect(screen, Vector2.ZERO, Vector2(1280, 720), Color(0, 0, 0, 0.72), true)
	Ui.label(screen, title_text, Vector2(190, 150), Vector2(900, 170), 38, Color(1.0, 0.85, 0.9), true)
	for i in range(buttons.size()):
		var button = Ui.button(screen, buttons[i][0], Vector2(480, 360 + i * 68), Vector2(320, 52), 22)
		button.pressed.connect(_choose.bind(buttons[i][1]))

func _choose(what: String) -> void:
	chosen.emit(what)
