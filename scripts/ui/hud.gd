extends CanvasLayer

const Ui = preload("res://scripts/ui/ui_kit.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")

var screen: Control = null
var combat_box: Control = null
var hp_bar: ProgressBar = null
var energy_bar: ProgressBar = null
var stamina_bar: ProgressBar = null
var distortion_bar: ProgressBar = null
var hp_label: Label = null
var level_label: Label = null
var skills_label: Label = null
var title_label: Label = null
var objective_label: Label = null
var prompt_label: Label = null
var toast_label: Label = null
var boss_box: Control = null
var boss_bar: ProgressBar = null
var boss_label: Label = null
var toast_time: float = 0.0
var touch_controls = null

func _ready() -> void:
	layer = 5
	screen = Ui.root(self)
	combat_box = Ui.root(screen)
	hp_bar = Ui.bar(combat_box, Vector2(24, 24), Vector2(320, 22), Color(0.82, 0.18, 0.25))
	hp_label = Ui.label(combat_box, "", Vector2(32, 22), Vector2(300, 24), 15)
	energy_bar = Ui.bar(combat_box, Vector2(24, 52), Vector2(260, 12), Color(0.3, 0.65, 1.0))
	stamina_bar = Ui.bar(combat_box, Vector2(24, 68), Vector2(260, 12), Color(0.4, 0.85, 0.4))
	distortion_bar = Ui.bar(combat_box, Vector2(24, 84), Vector2(260, 12), Color(0.85, 0.1, 0.55))
	level_label = Ui.label(combat_box, "", Vector2(24, 102), Vector2(500, 24), 16)
	skills_label = Ui.label(combat_box, "", Vector2(24, 678), Vector2(1230, 30), 17)
	title_label = Ui.label(screen, "", Vector2(840, 18), Vector2(416, 30), 22, Color(1.0, 0.75, 0.8))
	objective_label = Ui.label(screen, "", Vector2(840, 52), Vector2(416, 90), 17)
	prompt_label = Ui.label(screen, "", Vector2(240, 610), Vector2(800, 30), 20, Color(1.0, 0.9, 0.5), true)
	toast_label = Ui.label(screen, "", Vector2(240, 150), Vector2(800, 70), 24, Color.WHITE, true)
	boss_box = Ui.root(screen)
	boss_label = Ui.label(boss_box, "", Vector2(340, 626), Vector2(600, 26), 18, Color(1.0, 0.6, 0.65), true)
	boss_bar = Ui.bar(boss_box, Vector2(340, 654), Vector2(600, 16), Color(0.75, 0.05, 0.2))
	boss_box.visible = false
	if OS.has_feature("mobile"):
		touch_controls = TouchControls.new()
		add_child(touch_controls)

func toast(text: String) -> void:
	toast_label.text = text
	toast_time = 3.0

func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		toast_label.modulate.a = clampf(toast_time, 0.0, 1.0)
		if toast_time <= 0.0:
			toast_label.text = ""

func _skill_state(title: String, cooldown: float, cost: float, energy: float) -> String:
	if cooldown > 0.0:
		return "%s %.1fс" % [title, cooldown]
	if energy < cost:
		return title + " (мало энергии)"
	return title + " ✓"

func refresh(hero, show_combat: bool, boss) -> void:
	combat_box.visible = show_combat
	if touch_controls != null:
		touch_controls.set_combat_enabled(show_combat)
	if show_combat:
		hp_bar.max_value = hero.max_hp
		hp_bar.value = hero.hp
		hp_label.text = "HP %d / %d" % [int(ceil(hero.hp)), int(hero.max_hp)]
		energy_bar.value = hero.energy
		stamina_bar.value = hero.stamina
		distortion_bar.value = hero.distortion
		level_label.text = "Ур. %d   Опыт %d/%d   Искажение %d%%" % [Game.hero_level, Game.hero_xp, Game.xp_to_next(), int(hero.distortion)]
		var echo = "R Отголосок Теи (спит)"
		if Game.flags.get("tea_awakened", false):
			echo = "R Отголосок Теи ✓" if hero.distortion >= 60.0 else "R Отголосок Теи (нужно 60)"
		skills_label.text = "ЛКМ комбо   |   Пробел/ПКМ уворот   |   %s   |   %s   |   %s   |   1 зелье x%d" % [
			_skill_state("Q Белая трещина", hero.cd_q, 30.0, hero.energy),
			_skill_state("E Алое искажение", hero.cd_e, 40.0, hero.energy),
			echo, Game.potions]
		skills_label.add_theme_font_size_override("font_size", 15)
	var has_boss = boss != null and is_instance_valid(boss) and boss.alive
	boss_box.visible = has_boss
	if has_boss:
		boss_label.text = str(boss.stats["title"]) + "  —  фаза %d" % boss.phase
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp
