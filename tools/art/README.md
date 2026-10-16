# Original footballer art

`footballer_polished.glb` is an original, stylized athletic player. Its visible
geometry is rebuilt by `build_footballer.py`: shaped head and facial features,
layered swept hair, fitted jersey and contrasting panels, collar, cuffs, crest,
shorts, knee socks, detailed football boots, crossed laces and studs.

The existing `assets/characters/footballer.glb` supplies its rig and four actions
(`Idle`, `Walk`, `Run`, `Kick`) and is retained unchanged. All eighteen named bones
and their transforms are preserved. Skin weights on the new torso and knees
blend between the relevant bones. Finger geometry follows the hand bone.

Build from the repository root with Blender 4.3 or later:

```sh
blender --background --python tools/art/build_footballer.py
```

Add `-- --render` to produce a separate Blender look-development image in
`/workspace/scratch/character-art/footballer-lookdev.png`. Rendering is optional.
The playable project does not require Blender, Python or a runtime addon.

The exported GLB embeds its neutral micro-knit texture. Godot also extracts
`footballer_polished_micro_knit.png` at import. Kit, skin and hair tints are
applied by `player_view.gd` from each player's existing profile. The same script
attaches the shirt number to the chest bone and keeps the floating live-play
number small. No match rules depend on this art.

The model contains 7,415 authoring vertices and 14,207 triangles across sixteen
material surfaces, approximately 548 KiB. Godot generates its normal import LODs
and shadow mesh. Twenty-two full-resolution players total 312,554 triangles.
Materials use standard PBR features compatible with the OpenGL renderer.

This is an improved shared player model, with profile-dependent colors. It does
not add a facial animation rig or unique head/hair meshes for each squad member.
