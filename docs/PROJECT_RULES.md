# Rift project rules

## Engine baseline
- Godot 4.7.2 Standard, GDScript only; no .NET dependency.
- Compatibility renderer is the baseline for Android.
- Do not replace the engine with a custom framework.

## Architecture
- 3D environments, buildings, props, lighting and collision.
- 2D character, monster and selected entity sprites/billboards.
- Gameplay data and story text stay in `data/*.json` where practical.
- Keep the current folder structure. Do not rewrite the project or remove systems without explicit approval.
- Autoload name is `Game`. Scripts are connected with `preload()`.

## Coding rules
- Godot 4 GDScript only.
- Tabs for indentation.
- Do not use `:=` or `class_name`.
- Read all related files before changing a system.
- Return complete changed files with `res://` paths; no ellipses, TODOs or omitted sections.
- Never claim the game was run unless a Godot runtime test actually completed.

## Art pipeline
- Create and inspect one sprite pose/frame at a time, then assemble approved frames into atlases.
- Keep each direction/pose as an individual source asset.
- Current Lisa idle set has front, back and side views; it is not a finished eight-direction animation set.
- SVG source art is editable and is a placeholder, not final production art.

## Quality
- Distinguish confirmed defects from hypotheses.
- Fix the cause shown by the error rather than guessing.
- Add reproducible checks for important systems.
- Android and Windows builds/device performance are not verified until tested on target devices.
