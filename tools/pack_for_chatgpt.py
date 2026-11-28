#!/usr/bin/env python3
"""Склеивает текстовые файлы проекта в CHATGPT_CONTEXT.txt.
Запуск из корня:  python tools/pack_for_chatgpt.py          (весь проект)
                  python tools/pack_for_chatgpt.py rts      (только файлы, где в пути есть 'rts')"""
import os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
needle = sys.argv[1] if len(sys.argv) > 1 else ""
files = ["project.godot"]
for top in ("scenes", "scripts", "data"):
    for folder, _, names in os.walk(os.path.join(ROOT, top)):
        for name in names:
            if name.endswith((".gd", ".json", ".tscn")):
                files.append(os.path.relpath(os.path.join(folder, name), ROOT).replace("\\", "/"))
files = [f for f in sorted(files) if needle in f]
with open(os.path.join(ROOT, "CHATGPT_CONTEXT.txt"), "w", encoding="utf-8") as out:
    out.write("СПИСОК ФАЙЛОВ:\n" + "\n".join(files) + "\n")
    for path in files:
        with open(os.path.join(ROOT, path), encoding="utf-8") as src:
            out.write(f"\n===== ФАЙЛ: res://{path} =====\n{src.read()}\n")
print(f"Записано файлов: {len(files)} -> CHATGPT_CONTEXT.txt")
