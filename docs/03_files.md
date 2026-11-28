# Расположение файлов

```
rift_game/                      <- корень (res://)
├── project.godot               настройки, автозагрузка Game
├── icon.png
├── README.md
├── scenes/
│   └── main.tscn               единственная сцена: Node "Main" + main.gd
├── scripts/
│   ├── core/
│   │   ├── game.gd             автозагрузка: данные, клавиши, уровень героини, сохранения
│   │   └── main.gd             меню <-> этапы <-> RTS, пауза, смерть, победа
│   ├── world/
│   │   ├── level.gd            строит уровень из levels.json, волны, взаимодействия
│   │   ├── builder.gd          3D-здания из примитивов, 2D-спрайты, надписи
│   │   └── camera_rig.gd       камера сверху под углом
│   ├── actors/
│   │   ├── actor.gd            база: HP, спрайт, отбрасывание, анимация
│   │   ├── player.gd           героиня и весь её бой   <- наследует actor
│   │   ├── enemy.gd            ИИ врагов               <- наследует actor
│   │   └── boss.gd             фазы босса              <- наследует enemy
│   ├── combat/
│   │   ├── projectile.gd       снаряды
│   │   └── fx.gd               эффекты и красные зоны
│   ├── rts/
│   │   ├── rts_mode.gd         экономика, выделение, приказы, волны, победа
│   │   ├── rts_entity.gd       база юнитов и зданий
│   │   ├── rts_unit.gd         юниты                   <- наследует rts_entity
│   │   ├── rts_building.gd     здания                  <- наследует rts_entity
│   │   ├── rts_minimap.gd
│   │   └── rts_selection_box.gd
│   └── ui/
│       ├── ui_kit.gd  menu.gd  overlay.gd  dialogue.gd  hud.gd  rts_hud.gd
│       └── touch_controls.gd  сенсорные RPG-кнопки Android
├── data/                       <- баланс и сюжет, правятся без кода
│   ├── levels.json  dialogues.json  enemies.json  rts.json
├── assets/sprites/             PNG-атласы и SVG-направления Лизы
├── assets/textures/            SVG-материалы пола и окружения
├── tools/
│   ├── make_sprites.py         пересоздать временные спрайты (нужны Python и Pillow)
│   ├── check_project.py        проверка JSON и ссылок
│   └── pack_for_chatgpt.py     собрать код в один файл
└── docs/
```

Почти всё создаётся кодом, поэтому в редакторе сцена выглядит пустой — это нормально.
Мир появляется после F5.

## Формат спрайтов
- Большинство персонажей: 4 кадра в ряд одинакового размера: стоит, шаг A, шаг B, атака. Смотрит ВПРАВО.
- Для Лизы на земных этапах используются отдельные SVG-ракурсы спереди, сзади и сбоку; сторона зеркалится.
- Обычный персонаж 32×48 за кадр (лист 128×48); ловчий 48×64; страж 64×88.
- Предмет: один кадр. Фон прозрачный. Ноги или низ предмета — у нижнего края.
- Чтобы заменить арт, положи PNG с тем же именем. Размер на экране задаёт `pixel` в JSON
  (высота в метрах = высота кадра × pixel). Спрайт героини в RPG: `pixel` задан в player.gd.
- ВНИМАНИЕ: `make_sprites.py` перезаписывает PNG и icon.png. После замены арта не запускай его.
- Референс стиля — 2.5D экшен-RPG с видом сверху, но арт и дизайн должны быть своими:
  не копируй спрайты и персонажей из Guardian Tales и других игр.

## Как добавить контент
**Реплика:** `data/dialogues.json` → новый ключ со списком `{"who","text","screen"}`.
`screen`: "", "void", "white", "red".

**Враг:** блок в `data/enemies.json`. `attack`: "melee" (нужен `hit_radius`), "ranged" (`shot_speed`),
"charge" (`charge_speed`, `charge_time`). Затем укажи его id в волне уровня.

**Уровень:** блок в `data/levels.json`.
- `size` [ширина, глубина]; координаты [x, z] считаются от центра. +x вправо, +z вниз по экрану.
- `world`: "earth" (без боя, спрайт Лизы) или "mira".
- `waves`: список волн; `[]` или без ключа — мирный уровень.
- `interactables`: `id`, `sprite`, `pos`, `prompt`, `dialogue`; по желанию `requires`,
  `after_clear`, `locked`, `rest`, `exit`.
- Нужен ровно один выход `"exit": true`; `next` — id следующего уровня или "rts".
- Впиши новый id в `next` предыдущего уровня.
- Здания `kind`: house, ruin, tower, tent, wall, apartment, obelisk, heart, любое другое = простой блок.

**Юнит или здание RTS:** `data/rts.json`. Новому юниту нужен спрайт; добавь его в `produces` казармы.
(Новому ЗДАНИЮ, которое строит игрок, нужны ещё кнопка в `rts_hud.gd` и клавиша в `rts_mode.gd`.)

После правок: `python tools/check_project.py`.
