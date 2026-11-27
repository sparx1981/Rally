# Visual effects and performance research (27 Nov 2026)

Measured on a desktop software render at 1280x720 with the new `--perf` dev flag (draw calls / triangles per frame):

| Stage | Preset | Draw calls | Triangles |
| --- | --- | --- | --- |
| Chalk Valley circuit | Low / Medium / High | 84 / 120 / 143 | 113k / 178k / 243k |
| Autumn forest (stage 16) | Medium / High | 190 / 280 | 741k / 1.0M |
| Snow stage 24 | High | 141 | 364k |

Draw calls are low; triangle count on forest stages is the main load.

Ideas are in the chat summary of this date. Sources: Godot 4.4 "Optimizing 3D performance" and renderer docs, Arm Godot-on-Mali blog series.
