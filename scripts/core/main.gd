extends Node
# Главный переключатель: меню -> уровни RPG -> RTS-битва.

const Level = preload("res://scripts/world/level.gd")
const RtsMode = preload("res://scripts/rts/rts_mode.gd")
const Menu = preload("res://scripts/ui/menu.gd")
const Overlay = preload("res://scripts/ui/overlay.gd")

var current: Node = null
var overlay = null
var current_id: String = ""

func _ready() -> void:
	# Main работает и во время паузы, чтобы ловить Esc.
	process_mode = Node.PROCESS_MODE_ALWAYS
	show_menu()

func _clear() -> void:
	_close_overlay()
	get_tree().paused = false
	Engine.time_scale = 1.0
	if current != null:
		current.queue_free()
		current = null

func _set_current(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_PAUSABLE
	current = node
	add_child(node)

func show_menu() -> void:
	_clear()
	current_id = "menu"
	var menu = Menu.new()
	menu.chosen.connect(_on_menu_chosen)
	_set_current(menu)

func _on_menu_chosen(what: String) -> void:
	match what:
		"new":
			Game.new_game()
			start_stage.call_deferred(Game.chapter)
		"continue":
			if Game.load_game():
				start_stage.call_deferred(Game.chapter)
		"rts":
			# Быстрый тест RTS: без изменения сохранения.
			Game.hero_level = maxi(Game.hero_level, 5)
			start_stage.call_deferred("rts")
		"quit":
			get_tree().quit()

func start_stage(id: String) -> void:
	_clear()
	current_id = id
	if id == "rts":
		var battle = RtsMode.new()
		battle.finished.connect(_on_rts_finished)
		_set_current(battle)
		return
	if not Game.levels.has(id):
		push_error("Нет уровня: " + id)
		show_menu()
		return
	var level = Level.new()
	level.level_id = id
	level.completed.connect(_on_level_completed)
	level.hero_died.connect(_on_hero_died)
	_set_current(level)

func _on_level_completed(next_id: String) -> void:
	Game.chapter = next_id
	Game.save_game()
	start_stage.call_deferred(next_id)

func _on_hero_died() -> void:
	_open_overlay("Искажение поглотило тебя", [["Попробовать снова", "retry"], ["В меню", "menu"]])

func _on_rts_finished(victory: bool) -> void:
	if victory:
		_open_overlay("ПОБЕДА\nРазлом закрыт... пока что.\nКонец первой части.", [["В меню", "menu"]])
	else:
		_open_overlay("Оплот пал", [["Переиграть битву", "retry"], ["В меню", "menu"]])

func _open_overlay(title: String, buttons: Array) -> void:
	_close_overlay()
	get_tree().paused = true
	overlay = Overlay.new()
	overlay.title_text = title
	overlay.buttons = buttons
	overlay.chosen.connect(_on_overlay_chosen)
	add_child(overlay)

func _close_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null

func _on_overlay_chosen(what: String) -> void:
	match what:
		"resume":
			_close_overlay()
			get_tree().paused = false
		"retry":
			if current_id != "rts":
				Game.load_game()
			start_stage.call_deferred(current_id)
		"menu":
			show_menu.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE and current_id != "menu":
		if overlay != null:
			# Закрываем только меню паузы (не экран смерти/победы).
			if overlay.title_text == "Пауза":
				_on_overlay_chosen("resume")
		elif not get_tree().paused:
			_open_overlay("Пауза", [["Продолжить", "resume"], ["Начать этап заново", "retry"], ["В меню", "menu"]])
	# F10 — отладка: пропустить текущий уровень. Убери перед релизом.
	elif event.physical_keycode == KEY_F10 and Game.levels.has(current_id) and not get_tree().paused:
		var data = Game.levels[current_id]
		if data.has("grant_flag"):
			Game.flags[data["grant_flag"]] = true
		_on_level_completed(str(data.get("next", "rts")))
