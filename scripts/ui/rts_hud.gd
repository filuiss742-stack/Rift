extends CanvasLayer

const Ui = preload("res://scripts/ui/ui_kit.gd")
const Minimap = preload("res://scripts/rts/rts_minimap.gd")
const SelectionBox = preload("res://scripts/rts/rts_selection_box.gd")

var game = null
var screen: Control = null
var top_label: Label = null
var info_label: Label = null
var mode_label: Label = null
var toast_label: Label = null
var button_box: Control = null
var signature: String = "-"
var toast_time: float = 0.0

func _ready() -> void:
	layer = 5
	screen = Ui.root(self)
	var box = SelectionBox.new()
	box.game = game
	box.size = Vector2(1280, 720)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(box)
	Ui.rect(screen, Vector2.ZERO, Vector2(1280, 40), Color(0.04, 0.03, 0.08, 0.85), true)
	top_label = Ui.label(screen, "", Vector2(20, 7), Vector2(1240, 28), 18)
	Ui.rect(screen, Vector2(0, 570), Vector2(1280, 150), Color(0.04, 0.03, 0.08, 0.92), true)
	var minimap = Minimap.new()
	minimap.game = game
	minimap.position = Vector2(12, 578)
	minimap.size = Vector2(201, 134)
	screen.add_child(minimap)
	info_label = Ui.label(screen, "", Vector2(236, 584), Vector2(420, 130), 17)
	button_box = Ui.root(screen)
	mode_label = Ui.label(screen, "", Vector2(240, 536), Vector2(800, 28), 18, Color(1.0, 0.9, 0.4), true)
	toast_label = Ui.label(screen, "", Vector2(240, 70), Vector2(800, 70), 24, Color.WHITE, true)

func toast(text: String) -> void:
	toast_label.text = text
	toast_time = 3.0

func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		toast_label.modulate.a = clampf(toast_time, 0.0, 1.0)
		if toast_time <= 0.0:
			toast_label.text = ""

func refresh() -> void:
	var heart_hp = int(game.heart.hp) if game.is_valid_target(game.heart) else 0
	top_label.text = "Кристаллы: %d      Войско: %d / %d      Волна %d через %d с      Сердце Разлома: %d      Цель: уничтожить Сердце" % [
		game.crystal_stock, game.supply_used(), game.supply_cap(), game.wave_number + 1, int(ceil(game.wave_timer)), heart_hp]
	var picked = game.selection
	var next_signature = "none"
	info_label.text = "Никто не выделен.\nПробел — камера к героине."
	if not picked.is_empty():
		var first = picked[0]
		if first.is_building:
			next_signature = "b:%s:%s" % [first.key, str(first.is_complete())]
			info_label.text = "%s\nHP %d / %d" % [first.title, int(first.hp), int(first.max_hp)]
			if not first.is_complete():
				info_label.text += "\nСтроится: %d%%\n(рабочий должен быть рядом)" % int(first.progress * 100.0)
			elif not first.queue.is_empty():
				var names = []
				for unit_key in first.queue:
					names.append(str(Game.rts["units"][unit_key]["title"]))
				var total = float(Game.rts["units"][first.queue[0]]["time"])
				info_label.text += "\nНайм %d%%: %s" % [int(first.train_time / total * 100.0), ", ".join(names)]
		else:
			var has_worker = false
			var has_hero = false
			for unit in picked:
				has_worker = has_worker or unit.key == "worker"
				has_hero = has_hero or unit.key == "hero"
			next_signature = "u:%s:%s" % [str(has_worker), str(has_hero)]
			if picked.size() == 1:
				info_label.text = "%s\nHP %d / %d\nУрон %d" % [first.title, int(first.hp), int(first.max_hp), int(first.damage_value())]
			else:
				info_label.text = "Выделено юнитов: %d" % picked.size()
			if has_hero:
				info_label.text += "\nВолна искажения: " + ("готова" if game.skill_cooldown <= 0.0 else "%d с" % int(ceil(game.skill_cooldown)))
	if next_signature != signature:
		signature = next_signature
		_build_buttons(next_signature)
	if game.build_mode != "":
		mode_label.text = "Выбери место для постройки: ЛКМ — поставить, ПКМ/Esc — отмена"
	elif game.attack_mode:
		mode_label.text = "Атака по пути: ЛКМ по цели или земле"
	else:
		mode_label.text = ""

# Кнопки пересоздаются только при смене выделения, иначе клики терялись бы.
func _build_buttons(kind: String) -> void:
	for child in button_box.get_children():
		child.queue_free()
	var items = []
	var parts = kind.split(":")
	if parts[0] == "u":
		items.append(["Атака по пути (A)", game.start_attack_mode])
		items.append(["Стоп (S)", game.stop_selected])
		if parts[1] == "true":
			for pair in [["barracks", "B"], ["tower", "T"], ["tent", "H"]]:
				var data = Game.rts["buildings"][pair[0]]
				items.append(["%s (%s) — %d" % [data["title"], pair[1], int(data["cost"])], game.start_build.bind(pair[0])])
		if parts[2] == "true":
			items.append(["Волна искажения (Q)", game.hero_skill])
	elif parts[0] == "b" and parts[2] == "true":
		var data = Game.rts["buildings"][parts[1]]
		if data.has("produces"):
			for unit_key in data["produces"]:
				var unit = Game.rts["units"][unit_key]
				items.append(["%s — %d" % [unit["title"], int(unit["cost"])], game.train.bind(unit_key)])
			items.append(["Отменить найм", game.cancel_train])
	for i in range(items.size()):
		var pos = Vector2(672 + (i % 2) * 300, 580 + int(i / 2.0) * 45)
		var button = Ui.button(button_box, str(items[i][0]), pos, Vector2(290, 40), 16)
		button.pressed.connect(items[i][1])
