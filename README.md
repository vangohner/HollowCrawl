# HollowCrawl

HollowCrawl is a first-person horror prototype built with Godot 4.2. You wake up inside an endless grid of concrete maintenance tunnels where a disfigured, hyper-aware predator stalks you from the dark. Sprinting, splashing through puddles, or even breathing too loudly will draw it near as it hides behind the maze-like walls until it can pounce.

## Getting started

1. Install [Godot 4.2](https://godotengine.org/download) (standard edition).
2. Open the project folder (`HollowCrawl/`) from the Godot project manager.
3. Run the main scene (`scenes/main.tscn`) or press <kbd>F5</kbd> to play.

## Controls

| Action | Default |
| --- | --- |
| Move | <kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd> |
| Sprint | <kbd>Shift</kbd> |
| Toggle flashlight | <kbd>F</kbd> |
| Interact (reserved) | <kbd>E</kbd> |
| Mouse look | Move mouse |

## Gameplay notes

- Your stamina drains quickly while sprinting, causing vision sway and heavy breathing that the creature can hear.
- The tunnels are generated from a dense grid map lined with concrete walls, pipes, and jets of steam to create liminal, claustrophobic sightlines.
- The monster listens for noise, darts between cover to stay out of the flashlight, and lunges once you are cornered. If it reaches you, the run ends.

## Project structure

```
scenes/
  main.tscn        # main game scene (level, player, monster, HUD)
  player.tscn      # first-person controller prefab
  stalker.tscn     # long-limbed hunter prefab
scripts/
  main.gd          # scene orchestration and UI
  player.gd        # movement, stamina, flashlight, camera sway
  stalker.gd       # creature AI (stalking, chasing, lunging)
  level.gd         # grid-map generation, walls, pipes, fog
project.godot      # Godot project configuration
```

Feel free to tweak the map layout, creature speeds, or environmental effects to push the experience in an even more unsettling direction.
