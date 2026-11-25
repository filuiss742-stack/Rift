# Rift project rules

## Engine baseline
- Pin the project to Godot 4.7.2 stable until an intentional upgrade is reviewed.
- Use standard Godot with GDScript; do not introduce the .NET runtime without a concrete need.
- Use the Compatibility renderer as the initial mobile-friendly baseline. Validate visual quality and performance on target hardware before changing renderers.

## Game architecture
- The world is 3D. Characters, monsters and selected entities are 2D sprites/billboards.
- Keep gameplay logic independent from presentation where practical.
- Use small scenes and focused scripts. Avoid global manager singletons unless there is a documented need.
- Prefer typed GDScript, explicit signals and clear ownership of scene nodes.
- Do not build a custom engine on top of Godot.

## Art pipeline
- Create and review every sprite pose/frame as a separate image file. Never ask an image model to draw several poses in one sheet.
- Hand-authored SVG is an approved fallback when image generation is unavailable; keep every direction/pose in its own SVG/PNG source file.
- Assemble approved frames into sprite sheets/atlases only after inspection. Keep source images; generated atlases must be reproducible.
- Directional character art should ultimately support eight viewing directions. The first Lisa idle set currently provides front, back and side views; diagonal views and animation frames remain to be made.

## Quality
- Never silently swallow errors.
- Distinguish confirmed defects from hypotheses in bug reports.
- Add a reproducible test or validation step for each important gameplay system.
- Do not claim Android/Windows builds or device performance are verified until they have actually been tested.
