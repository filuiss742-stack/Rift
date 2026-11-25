# Rift

A story-driven action game built with **Godot 4.7.2 (stable)**.

## Project direction

- 3D environments, architecture, props, lighting and collision.
- 2D characters, creatures and entities using directional sprite sets.
- Sprite frames are created and reviewed individually before being assembled into animation atlases.
- Real-time action combat, dodge windows, enemy telegraphs and abilities.
- Narrative dialogue with choices and persistent consequences.
- A separate strategy/RTS mode later in the project.

## Open the project

1. Install Godot **4.7.2 Standard** (not .NET; the project uses GDScript).
2. In Godot Project Manager, choose **Import**.
3. Select this repository's `project.godot`.
4. Run the project (F6/F5).

Official download: https://godotengine.org/download/archive/4.7.2-stable/

## Structure

- `scenes/` — Godot scenes.
- `scripts/` — GDScript gameplay and systems.
- `assets/` — source art, textures, audio and other game assets.
- `docs/` — design, architecture and production notes.

Keep gameplay systems small and explicit. Prefer composition over giant manager scripts. Do not add engine code: Godot is the engine.

## Validation

GitHub Actions runs Godot headless import and project startup checks on pushes and pull requests.
