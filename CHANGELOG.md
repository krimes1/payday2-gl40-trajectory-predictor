# Changelog

All notable project changes are recorded here. The project is currently in beta.

## v1.0.0 Beta

- Retains a single estimated GL40 trajectory using speed 2500, gravity 981, drag 0.005, vertical boost 125, and an estimated 2-second fuse.
- Uses the `world_geometry` collision mask for estimated static geometry detection.
- Shows a separate dotted hypothetical ground projection after the fuse endpoint when a ground point is found.
- Adds an experimental counter for qualifying long-range GL40 kills.
- Documents known prediction and attribution limitations.

## Earlier development

The previous README described changes from v0.9: removing offset parallel trajectory strokes, using static world geometry for collision checks, and separating the fuse endpoint from a hypothetical dotted ground continuation. No earlier release notes were present in the repository.
