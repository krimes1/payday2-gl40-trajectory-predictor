GL40 Trajectory Predictor v1.0 BETA

Install: Delete the previous PAYDAY 2/mods/GL40_Trajectory_Predictor folder, then place the included folder in mods.

Changes from v0.9:
- Removes offset parallel strokes, leaving one clean trajectory. This fixes likely branching/T artifacts; the line may look thinner.
- Keeps calibrated speed 2500, gravity 981, drag 0.005, vertical boost 125, and estimated 2.0 s fuse.
- Uses world_geometry collision mask first to reduce false positives from dynamic objects. This may miss props or rails; test in-game.
- After a fuse endpoint, displays a separate BLUE-GREY DOTTED hypothetical continuation to ground, if ground is found within 3 seconds.
- The real grenade trajectory STOPS at fuse. The dotted extension is not an actual projectile path.
- Collision marks are estimates; not guaranteed to match physical grenade collisions.

Limitations:
- This does NOT provide reliable through-wall rendering, nor verified thicker line drawing.
- Real grenade impacts may differ from static geometry raycasts.
- Counter is experimental and may differ from achievement progress.
- Not tested inside PAYDAY 2. Send screenshots or crash logs if needed.
