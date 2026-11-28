extends Node
# Автозагрузка "Game": данные игры, параметры героини, сохранения, клавиши.

const SAVE_PATH = "user://save.json"
const FIRST_LEVEL = "earth_room"

var levels: Dictionary = {}
var dialogues: Dictionary = {}
var enemies: Dictionary = {}
var rts: Dictionary = {}

var hero_level: int = 1
var hero_xp: int = 0
var potions: int = 3
var chapter: String = FIRST_LEVEL
var flags: Dictionary = {}

func _ready() -> void:
	_setup_input()
	levels = load_json("res://data/levels.json")
	dialogues = load_json("res://data/dialogues.json")
	enemies = load_json("res://data/enemies.json")
	rts = load_json("res://data/rts.json")

func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Нет файла: " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Ошибка в JSON: " + path)
		return {}
	return parsed

# ---------- Клавиши ----------
# physical_keycode: управление работает и при русской раскладке.
func _setup_input() -> void:
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("attack", [KEY_J])
	_add_mouse("attack", MOUSE_BUTTON_LEFT)
	_add_keys("dodge", [KEY_SPACE])
	_add_mouse("dodge", MOUSE_BUTTON_RIGHT)
	_add_keys("skill_1", [KEY_Q])
	_add_keys("skill_2", [KEY_E])
	_add_keys("skill_3", [KEY_R])
	_add_keys("interact", [KEY_F])
	_add_keys("potion", [KEY_1, KEY_H])

func _add_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

func _add_keys(action: String, keys: Array) -> void:
	_add_action(action)
	for key in keys:
		var ev = InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)

func _add_mouse(action: String, button: int) -> void:
	_add_action(action)
	var ev = InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

# ---------- Параметры героини ----------
func hero_max_hp() -> float:
	return 120.0 + 18.0 * (hero_level - 1)

func hero_attack() -> float:
	return 14.0 + 3.0 * (hero_level - 1)

func xp_to_next() -> int:
	return 60 + 40 * (hero_level - 1)

# Возвращает true, если получен новый уровень.
func add_xp(amount: int) -> bool:
	hero_xp += amount
	var leveled = false
	while hero_xp >= xp_to_next():
		hero_xp -= xp_to_next()
		hero_level += 1
		leveled = true
	return leveled

# ---------- Сохранения ----------
func new_game() -> void:
	hero_level = 1
	hero_xp = 0
	potions = 3
	chapter = FIRST_LEVEL
	flags = {}
	save_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось сохранить игру")
		return
	file.store_string(JSON.stringify({
		"hero_level": hero_level, "hero_xp": hero_xp,
		"potions": potions, "chapter": chapter, "flags": flags,
	}))

func load_game() -> bool:
	if not has_save():
		return false
	var data = load_json(SAVE_PATH)
	if data.is_empty():
		return false
	hero_level = int(data.get("hero_level", 1))
	hero_xp = int(data.get("hero_xp", 0))
	potions = int(data.get("potions", 3))
	chapter = str(data.get("chapter", FIRST_LEVEL))
	flags = data.get("flags", {})
	return true
