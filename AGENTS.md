# Repository Guidelines

## Project Structure & Module Organization

This is a Godot 4.6 project. Gameplay code lives under `scripts/game/`, grouped by feature modules such as backpack, battle, forge, main menu, map, and shop. Reusable scenes are in `scene/`, with matching feature subdirectories. Game data and CSV-backed configuration belong in `config/`; visual and audio resources belong in `assets/`. Global services are registered as autoloads in `project.godot`.

The `addons/` directory contains editor and runtime plugins. Treat third-party plugin code as vendored: modify it only when the change specifically targets that plugin. Godot-generated `.godot/` files and `*.uid` metadata should not be hand-edited.

## Build, Test, and Development Commands

- `godot --editor --path .` opens the project in the Godot editor.
- `godot --path .` runs the configured main scene.
- `godot --headless --editor --path . --quit` imports resources and checks that the project loads without editor startup errors.
- `git diff --check` detects whitespace errors before review.

If `godot` is not on `PATH`, use `/Applications/Godot.app/Contents/MacOS/Godot` on macOS.

## Coding Style & Naming Conventions

Follow existing Godot and GDScript conventions. Use tabs for GDScript indentation, `snake_case` for files, variables, functions, and signals, and `PascalCase` for `class_name` declarations. Prefix internal state and helper methods with `_`. Add static types and return types where practical, especially on public APIs and signal payloads. Keep scenes focused and communicate between modules through signals or autoload managers rather than brittle node-tree traversal.

## Testing Guidelines

No automated test framework or coverage threshold is currently configured. For every change, run the headless load check and exercise the affected flow in the editor. Test adjacent state transitions—for example shop to backpack, forge to inventory, or map to battle—and watch the debugger for errors. Document manual verification steps in the pull request.

## Commit & Pull Request Guidelines

Recent commits use concise, imperative summaries such as `Add forge system` and `Refactor: rename Weapon to RotateWeapon`. Keep each commit focused and describe the user-visible outcome; use a short body when migration or data changes need explanation.

Pull requests should include a clear summary, affected systems, verification steps, and linked issues when applicable. Attach screenshots or short recordings for scene, layout, animation, or asset changes. Call out edits to `project.godot`, autoloads, input actions, CSV schemas, or vendored addons because they can affect the whole project.
