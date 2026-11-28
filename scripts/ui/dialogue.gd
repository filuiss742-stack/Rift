extends CanvasLayer
# Диалоги. Пока идёт разговор, игра на паузе.
# Строка: {"who": "Рен", "text": "...", "screen": "void" | "white" | "red" | ""}

const Ui = preload("res://scripts/ui/ui_kit.gd")
const SCREENS = {
	"void": Color(0.01, 0.0, 0.03, 1.0),
	"white": Color(0.55, 0.55, 0.62, 1.0),
	"red": Color(0.28, 0.0, 0.05, 1.0),
}

var lines: Array = []
var index: int = 0
var on_done: Callable = Callable()
var active: bool = false
var shown: float = 0.0

var panel: Control = null
var backdrop: ColorRect = null
var crack_image: TextureRect = null
var who_label: Label = null
var text_label: Label = null

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Ui.root(self)
	backdrop = Ui.rect(panel, Vector2.ZERO, Vector2(1280, 720), Color.BLACK)
	crack_image = TextureRect.new()
	crack_image.texture = load("res://assets/sprites/crack.png")
	crack_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crack_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crack_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crack_image.position = Vector2(500, 40)
	crack_image.size = Vector2(280, 460)
	panel.add_child(crack_image)
	Ui.rect(panel, Vector2(90, 510), Vector2(1100, 180), Color(0.05, 0.03, 0.09, 0.93))
	Ui.rect(panel, Vector2(90, 510), Vector2(1100, 3), Color(0.85, 0.15, 0.3, 1.0))
	who_label = Ui.label(panel, "", Vector2(120, 522), Vector2(700, 34), 24, Color(1.0, 0.55, 0.65))
	text_label = Ui.label(panel, "", Vector2(120, 562), Vector2(1040, 100), 21)
	Ui.label(panel, "F / клик — дальше", Vector2(980, 660), Vector2(200, 24), 14, Color(0.7, 0.7, 0.8))
	panel.visible = false

func play_id(dialogue_id: String, done: Callable = Callable()) -> void:
	var found = Game.dialogues.get(dialogue_id, [])
	if dialogue_id != "" and found.is_empty():
		push_warning("Нет диалога: " + dialogue_id)
	play(found, done)

func play(new_lines: Array, done: Callable = Callable()) -> void:
	if new_lines.is_empty():
		if done.is_valid():
			done.call()
		return
	lines = new_lines
	on_done = done
	index = 0
	active = true
	panel.visible = true
	get_tree().paused = true
	_show_line()

func _show_line() -> void:
	var line = lines[index]
	who_label.text = str(line.get("who", ""))
	text_label.text = str(line.get("text", ""))
	shown = 0.0
	text_label.visible_characters = 0
	var screen = str(line.get("screen", ""))
	backdrop.visible = SCREENS.has(screen)
	crack_image.visible = screen == "white" or screen == "red"
	if backdrop.visible:
		backdrop.color = SCREENS[screen]

func _process(delta: float) -> void:
	if active:
		shown += delta * 70.0
		text_label.visible_characters = int(shown)

func _input(event: InputEvent) -> void:
	if not active:
		return
	var enter = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ENTER
	if enter or event.is_action_pressed("interact") or event.is_action_pressed("attack") or event.is_action_pressed("dodge"):
		get_viewport().set_input_as_handled()
		_advance()

func _advance() -> void:
	if shown < text_label.text.length():
		shown = text_label.text.length()
		return
	index += 1
	if index < lines.size():
		_show_line()
		return
	active = false
	panel.visible = false
	get_tree().paused = false
	var callback = on_done
	on_done = Callable()
	if callback.is_valid():
		callback.call()
