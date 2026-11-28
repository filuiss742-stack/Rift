#!/usr/bin/env python3
"""Быстрая проверка проекта БЕЗ Godot: JSON, ссылки на файлы и диалоги, скобки, отступы.
Запуск из корня: python tools/check_project.py
Это не компилятор: ошибки GDScript показывает только сам Godot."""
import json, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
errors = []

def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()

data = {}
for n in ("levels", "dialogues", "enemies", "rts"):
    try:
        data[n] = json.loads(read(f"data/{n}.json"))
    except Exception as e:
        errors.append(f"data/{n}.json: {e}")
if errors:
    print("\n".join(errors)); sys.exit(1)

def sprite(n, where):
    if not os.path.exists(os.path.join(ROOT, "assets/sprites", n + ".png")):
        errors.append(f"{where}: нет спрайта {n}.png")

levels, dlg = data["levels"], data["dialogues"]
for lid, lv in levels.items():
    if lv["next"] != "rts" and lv["next"] not in levels:
        errors.append(f"{lid}: нет следующего уровня {lv['next']}")
    for key in ("intro", "clear_dialogue"):
        if key in lv and lv[key] not in dlg:
            errors.append(f"{lid}: нет диалога {lv[key]}")
    for p in lv.get("props", []):
        sprite(p["sprite"], lid)
    ids = {i["id"] for i in lv.get("interactables", [])}
    for i in lv.get("interactables", []):
        sprite(i["sprite"], lid)
        if i.get("dialogue") and i["dialogue"] not in dlg:
            errors.append(f"{lid}: нет диалога {i['dialogue']}")
        for need in i.get("requires", []):
            if need not in ids:
                errors.append(f"{lid}: requires несуществующий id {need}")
    if not any(i.get("exit") for i in lv.get("interactables", [])):
        errors.append(f"{lid}: нет выхода (exit)")
    for wave in lv.get("waves", []):
        for e in wave:
            if e["type"] not in data["enemies"]:
                errors.append(f"{lid}: неизвестный враг {e['type']}")
for e in data["enemies"].values():
    sprite(e["sprite"], "enemies.json")
for u in data["rts"]["units"].values():
    sprite(u["sprite"], "rts.json")
for b in data["rts"]["buildings"].values():
    for unit in b.get("produces", []):
        if unit not in data["rts"]["units"]:
            errors.append(f"rts.json: неизвестный юнит {unit}")
for g in data["rts"]["map"]["guards"]:
    if g["type"] not in data["rts"]["units"]:
        errors.append(f"rts.json: неизвестный охранник {g['type']}")

pairs = {")": "(", "]": "[", "}": "{"}
for folder, _, files in os.walk(ROOT):
    for f in files:
        if not f.endswith((".gd", ".tscn", ".godot")):
            continue
        rel = os.path.relpath(os.path.join(folder, f), ROOT)
        text = read(rel)
        for ref in re.findall(r'"\*?(res://[^"%]+\.\w+)"', text):
            if not os.path.exists(os.path.join(ROOT, ref[6:])):
                errors.append(f"{rel}: нет файла {ref}")
        for ref in re.findall(r'play_id\("(\w+)"', text):
            if ref not in dlg:
                errors.append(f"{rel}: нет диалога {ref}")
        if not f.endswith(".gd"):
            continue
        stack = []
        for no, line in enumerate(text.split("\n"), 1):
            if re.match(r"^\t* +\S", line) and not stack:
                errors.append(f"{rel}:{no}: пробелы в отступе (нужны табы)")
            code = re.sub(r'"(\\.|[^"\\])*"', '""', line).split("#")[0]
            if ":=" in code:
                errors.append(f"{rel}:{no}: не используем := в этом проекте")
            for ch in code:
                if ch in "([{":
                    stack.append((ch, no))
                elif ch in pairs:
                    if not stack or stack[-1][0] != pairs[ch]:
                        errors.append(f"{rel}:{no}: лишняя скобка {ch}")
                    else:
                        stack.pop()
        if stack:
            errors.append(f"{rel}:{stack[-1][1]}: незакрытая скобка")

print("\n".join(errors) if errors else "Проверка пройдена: JSON, ссылки, диалоги, спрайты, скобки, отступы.")
sys.exit(1 if errors else 0)
