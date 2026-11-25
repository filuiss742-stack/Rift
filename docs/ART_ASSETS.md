# Art assets — first prologue pass

## Source assets

All files in this pass are original hand-authored SVG sources:

- `assets/textures/wood_floor.svg` — repeating wood floor tile.
- `assets/textures/wallpaper.svg` — subtle bedroom wall pattern.
- `assets/textures/rug.svg` — rug motif.
- `assets/textures/stone_ruins.svg` — repeating weathered masonry.
- `assets/textures/ashen_ground.svg` — cracked ash ground.
- `assets/sprites/lisa_idle_front.svg` — one front-facing idle pose.
- `assets/sprites/lisa_idle_back.svg` — one back-facing idle pose.
- `assets/sprites/lisa_idle_side.svg` — one side-facing idle pose (mirrored in-engine for the opposite side).

Godot imports SVG as a texture. The prologue applies the texture files to 3D meshes and displays Lisa as a Sprite3D billboard.

## Art-pipeline constraints

1. One pose and one direction per source image.
2. Inspect each source before creating an atlas.
3. Do not generate multi-pose sheets; they previously produced duplicate limbs and malformed anatomy.
4. Keep the SVG source editable. Export PNG only when an importer or external pipeline requires it.
5. The first pass is hand-authored placeholder-quality vector art, not final production illustration.
6. Next character-art tasks: diagonal directions, idle animation frames, walk frames, expressions and dialogue portraits. Create each frame separately, then assemble.

## Current limitations

- Lisa currently has three distinct idle views, not the final eight-direction set.
- The bedroom and ruins have first-pass repeating texture tiles; object-specific materials, normal/roughness maps, decals, lighting polish and texture variation are still outstanding.
- Touch controls use icon glyphs styled as translucent circular buttons; physical Android layout and touch behavior still need device testing.
