# Equipment Attribute Aggregation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the source-aware modifier subsystem with one public `AttrContainer` rebuilt from passive equipment by `BackpackManager`.

**Architecture:** The existing `BackpackManager` autoload owns `equipment_attrs`, recalculates it from all backpack passive equipment before emitting its existing `equip_changed` signal, and exposes the existing `AttrContainer` API directly. Equipment entities preserve base values, listen to `equip_changed`, and read missing aggregate values as zero by checking `has()` before `get_value()`.

**Tech Stack:** Godot 4.6, typed GDScript, headless scene integration tests

**Spec:** `docs/superpowers/specs/2026-08-21-attribute-modifier-system-design.md`

## Global Constraints

- Reuse `scripts/game/module/battle/data/attray_container.gd`; do not introduce another container type.
- `BackpackManager.equipment_attrs` is public and stores only totals from `PASSIVE_ATTRIBUTE` equipment currently in `backpack_equip`.
- Every equipment mutation recalculates totals before emitting the existing `equip_changed` signal.
- Callers check `equipment_attrs.has(type)` before `get_value(type)`; absent equipment bonuses mean `0.0`.
- Final values use `(base + flat total) * (1.0 + percentage total)`.
- `ATK` and `ATK_PER` affect all player equipment damage; rotation attributes affect rotating weapons only.
- Preserve the existing shooter timer fix for positive equipment intervals and zero-interval enemy shooters.
- Preserve the user's unstaged `equipment_host.gd` array-initialization edit and the unrelated `.gitkeep` deletion; do not stage either as part of this feature.

---

### Task 1: Backpack-Owned Attribute Aggregate

**Files:**
- Modify: `scripts/game/module/backpack/sys/backpack_manager.gd`
- Modify: `tests/equipment/equipment_runtime_test.gd`

**Interfaces:**
- Produces: `BackpackManager.equipment_attrs: AttrContainer`
- Produces: `BackpackManager.recalculate_equipment_attrs() -> void`
- Produces: internal `_notify_equipment_changed() -> void`, which recalculates before `equip_changed.emit()`

- [ ] **Step 1: Write failing aggregate tests**

Add `_test_backpack_equipment_attributes()` before player-scene tests. Save the current backpack dictionaries, place two `Equipment.new(23)` instances in `backpack_equip`, call `recalculate_equipment_attrs()`, and assert `ATK == 20.0` and `ROTATE_SPEED_PER == 0.4`. Remove one instance and assert `10.0` and `0.2`; add entity equipment ID 1 and assert totals do not change; clear the backpack, rebuild, and assert both keys are absent. Restore the saved dictionaries before returning.

Add an ordering assertion by connecting a one-shot callback to `equip_changed`, performing a successful public backpack mutation, and checking the callback observes the already-rebuilt `ATK` total.

- [ ] **Step 2: Run the focused test and verify RED**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/backpack-survivor-aggregate-red.log --path . tests/equipment/equipment_runtime_test.tscn
```

Expected: parse/assertion failure because `BackpackManager.equipment_attrs` and `recalculate_equipment_attrs()` do not exist.

- [ ] **Step 3: Add the public aggregate and rebuild method**

Add:

```gdscript
var equipment_attrs: AttrContainer = AttrContainer.new()

func recalculate_equipment_attrs() -> void:
	equipment_attrs.reset()
	for equipment: Equipment in backpack_equip.values():
		var data: EquipmentData = GameConfig.equipment.get(equipment.id)
		if data == null:
			DebugUtility.warn("BackpackManager", "未找到装备配置: %s" % equipment.id)
			continue
		if data.type != EquipmentEffectType.Type.PASSIVE_ATTRIBUTE:
			continue
		for key in data.attr:
			var type := AttrType.get_type(String(key))
			if int(type) == -1:
				DebugUtility.warn("BackpackManager", "未知属性类型: %s" % key)
				continue
			var total := equipment_attrs.get_value(type) if equipment_attrs.has(type) else 0.0
			equipment_attrs.set_value(type, total + float(data.attr[key]))
```

- [ ] **Step 4: Centralize mutation notification order**

Add:

```gdscript
func _notify_equipment_changed() -> void:
	recalculate_equipment_attrs()
	equip_changed.emit()
```

Replace each successful `equip_changed.emit()` in add, remove, and move paths with `_notify_equipment_changed()`. During `init_backpack()`, reset the aggregate when clearing old equipment and ensure one final rebuild leaves empty and non-empty initial loadouts correct.

- [ ] **Step 5: Run GREEN tests and commit only Task 1 files**

Run the focused scene and `git diff --check`. Expected: exit `0`, aggregate/removal/empty/filter/order assertions pass.

```bash
git add scripts/game/module/backpack/sys/backpack_manager.gd tests/equipment/equipment_runtime_test.gd
git commit -m "Move equipment attributes into backpack manager"
```

---

### Task 2: Remove Modifier Runtime and Rewire Equipment Entities

**Files:**
- Delete: `scripts/game/module/attribute/data/attribute_modifier.gd`
- Delete: `scripts/game/module/attribute/runtime/attribute_calculator.gd`
- Delete: `scripts/game/module/attribute/runtime/attribute_container.gd`
- Delete: `scripts/game/module/equipment/effects/passive_attribute_effect.gd`
- Modify: `scripts/game/module/equipment/runtime/equipment_context.gd`
- Modify: `scripts/game/module/equipment/runtime/equipment_effect_factory.gd`
- Modify: `scripts/game/module/equipment/component/equipment_host.gd`
- Modify: `scripts/game/module/equipment/effects/rotate_weapon_effect.gd`
- Modify: `scripts/game/module/equipment/effects/shooter_effect.gd`
- Modify: `scripts/game/module/equipment/entity/rotate_weapon.gd`
- Modify: `scripts/game/module/equipment/entity/shooter.gd`
- Modify: `tests/equipment/equipment_runtime_test.gd`

**Interfaces:**
- Consumes: Task 1 `BackpackManager.equipment_attrs` and `equip_changed`
- Produces: `RotateWeapon.setup(base_damage, rotate_radius, base_rotate_speed, shape, texture)`
- Produces: `Shooter.setup(shoot_interval, bullet_speed, base_damage, radius, count, from, use_equipment_attrs := false)`

- [ ] **Step 1: Replace modifier-centric tests with failing end-to-end tests**

Remove tests that instantiate `AttributeModifier` or `AttributeContainer`. Initialize backpack contents with two ID 23 gloves plus rotating/shooting equipment, rebuild attributes, and create entities through `EquipmentHost`. Assert every rotating weapon starts with speed `14.0`, rotating damage includes global `ATK`, shooter damage includes global `ATK`, and no entity is created for passive equipment. Remove one glove through a backpack mutation and assert the same entity instances refresh to speed `12.0` and reduced damage after `equip_changed`.

Retain the real enemy-shooter smoke test and active timer countdown assertion from the timer regression fix.

- [ ] **Step 2: Run the focused test and verify RED**

Expected: tests still depend on the old host-owned container or entity signals and do not observe the `BackpackManager` aggregate path.

- [ ] **Step 3: Remove passive runtime construction**

Remove `attribute_container` and the fourth setup argument from `EquipmentContext`. Remove the passive branch from `EquipmentEffectFactory`. In `EquipmentHost.initialize()`, skip `PASSIVE_ATTRIBUTE` before calling the factory and activate only entity effects. Remove host container ownership, passive arrays, container clearing, and two-phase activation.

Keep the user's existing uncommitted array initialization lines unchanged:

```gdscript
if not equipment_groups.has(equipment.id):
	equipment_groups[equipment.id] = []
```

- [ ] **Step 4: Rewire rotating weapons**

Remove the `AttributeContainer` setup parameter and field. Connect `BackpackManager.equip_changed` once, then recalculate from `BackpackManager.equipment_attrs`. Each value must check `has()` before `get_value()`:

```gdscript
func _equipment_attr(type: AttrType.Type) -> float:
	var attrs := BackpackManager.equipment_attrs
	return attrs.get_value(type) if attrs.has(type) else 0.0

func _refresh_equipment_attributes() -> void:
	_attack_power = (_base_attack_power + _equipment_attr(AttrType.Type.ATK)) \
		* (1.0 + _equipment_attr(AttrType.Type.ATK_PER))
	_rotation_speed = (_base_rotation_speed + _equipment_attr(AttrType.Type.ROTATE_SPEED)) \
		* (1.0 + _equipment_attr(AttrType.Type.ROTATE_SPEED_PER))
```

- [ ] **Step 5: Rewire equipment shooters without affecting enemies**

Replace the optional container parameter with `use_equipment_attrs: bool = false`. `ShooterEffect` passes `true`; `EnemyShooter` retains its existing six-argument call and therefore remains unmodified. Only equipment shooters connect to `equip_changed` and apply `ATK/ATK_PER`. Preserve timer behavior:

```gdscript
if _shoot_interval > 0.0:
	shoot_timer.wait_time = _shoot_interval
	shoot_timer.start()
else:
	shoot_timer.stop()
```

- [ ] **Step 6: Delete obsolete files and run GREEN tests**

Run the focused scene, headless import, and `git diff --check`. Expected: exit `0`; no references to `AttributeModifier`, `AttributeContainer`, `AttributeCalculator`, `PassiveAttributeEffect`, or `context.attribute_container` remain.

- [ ] **Step 7: Commit without staging the user's pre-existing host hunk**

Stage deletions and all non-host files normally. For `equipment_host.gd`, construct/apply an index patch containing only Task 2 changes; verify `git diff --cached -- equipment_host.gd` excludes the pre-existing array-initialization hunk. Commit:

```bash
git commit -m "Simplify passive equipment attribute flow"
```

After commit, `git status --short` must still show the user's `equipment_host.gd` modification and the unrelated `.gitkeep` deletion.

---

### Task 3: Full Regression Verification

**Files:**
- Modify only files needed to correct failures caused by Tasks 1-2.

**Interfaces:**
- Consumes: completed backpack-owned aggregation and entity refresh flow
- Produces: import-clean, integration-tested result

- [ ] **Step 1: Run the focused equipment integration test**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/backpack-survivor-equipment-test.log --path . tests/equipment/equipment_runtime_test.tscn
```

Expected: exit `0`; no `equipment_runtime_test:` failure and no Timer zero-interval error.

- [ ] **Step 2: Run the project import check**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
```

Expected: exit `0`; no project script parse or resource-load failure. Existing macOS CA, SceneManager, editor-settings, and headless cleanup diagnostics may remain.

- [ ] **Step 3: Verify obsolete architecture is gone**

```bash
rg -n "AttributeModifier|AttributeContainer|AttributeCalculator|PassiveAttributeEffect|attribute_container" scripts tests
```

Expected: no matches.

- [ ] **Step 4: Verify formatting and protected worktree state**

```bash
git diff --check
git status --short
```

Expected: no whitespace failures. The user's pre-existing `equipment_host.gd` modification and unrelated `.gitkeep` deletion remain unstaged and uncommitted.

- [ ] **Step 5: Commit only if verification required a correction**

If a scoped correction was necessary, stage only its exact hunks and commit:

```bash
git commit -m "Fix equipment attribute aggregation regressions"
```

If no correction was necessary, do not create an empty commit.
