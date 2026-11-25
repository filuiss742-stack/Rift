# Prologue — first playable draft

## Canonical sequence
1. The heroine is shown in a black void.
2. A thin white fracture appears; red distortion pushes through it.
3. A flash cuts to Lisa waking in her ordinary modern-world bedroom.
4. The player can inspect the phone, mirror and window.
5. Lisa goes to bed.
6. She wakes in the unfamiliar fantasy world, in Mira's body. The prologue ends before explaining the possession/sleeping-body mystery.

The modern-world sequence is intentionally ordinary. It should make the transition feel wrong by contrast, not explain the mystery too early.

## Current implementation
- The sequence is implemented in `scripts/prologue/prologue.gd`.
- `scenes/main.tscn` launches the sequence.
- The bedroom and ruined fantasy clearing are built from primitive 3D meshes at runtime.
- The protagonist is a procedural silhouette placeholder only. It is not final character art.
- Dialogue advances with a button. The bedroom supports keyboard movement (WASD), E/Space interaction and on-screen directional controls.

## Known limitations / next production passes
- No final Lisa/Mira sprite art, portraits, facial expressions or directional animation yet.
- No final textures, sound design, music, voice acting, cinematic camera animation or save system yet.
- Current room is a greybox, not final environment art.
- The mirror moment is atmospheric text only; no reflection rendering yet.
- The first fantasy awakening is a short scene, not the complete second-world level.
- Touch controls need physical-device usability testing.
- Run the Godot headless CI check and fix all parser/runtime errors before extending this scene.

## Art pipeline requirement
Create and inspect every character pose as an individual image. Only approved frames may be assembled into a sprite atlas. Do not ask an image model to generate a multi-pose sheet in one pass.
