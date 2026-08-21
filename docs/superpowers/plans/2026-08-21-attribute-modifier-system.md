# Attribute Modifier System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a source-aware equipment attribute container so passive gloves can increase the attack of all equipment and the speed of every rotating weapon.

**Architecture:** `EquipmentHost` owns one `AttributeContainer`; passive effects register modifiers before entity effects create weapons. Runtime weapon nodes keep immutable base values, calculate fixed-plus-percentage results through `AttributeCalculator`, and refresh when relevant modifier totals change.

**Tech Stack:** Godot 4.6, typed GDScript, headless scene integration tests

**Spec:** `docs/superpowers/specs/2026-08-21-attribute-modifier-system-design.md`

## Global Constraints

- Fixed and percentage attributes use paired `AttrType` entries such as `ROTATE_SPEED` and `ROTATE_SPEED_PER`; do not add an operation enum.
- Percentage values are decimals: `0.2` means 20 percent.
- Final values use `(base + fixed total) * (1.0 + percentage total)`.
- Runtime source identity uses exact `Equipment` object references.
- `ATK` and `ATK_PER` affect every equipment-created damage source.
- Attribute names define scope; do not add provider, consumer, or target abstractions.
- Preserve the existing `AttrContainer`, which continues to hold character/base values.

---

### Task 1: Source-Aware Attribute Primitives

**Files:**
- Modify: `scripts/game/module/battle/data/attray_type.gd`
- Create: `scripts/game/module/attribute/data/attribute_modifier.gd`
- Create: `scripts/game/module/attribute/runtime/attribute_calculator.gd`
- Create: `scripts/game/module/attribute/runtime/attribute_container.gd`
- Modify: `tests/equipment/equipment_runtime_test.gd`

**Interfaces:**
- Produces: `AttributeModifier.new(source: Equipment, type: AttrType.Type, amount: float)`
- Produces: `AttributeContainer.add_modifier(modifier: AttributeModifier) -> void`
- Produces: `AttributeContainer.remove_by_source(source: Equipment) -> void`
- Produces: `AttributeContainer.get_total(type: AttrType.Type) -> float`
- Produces: `AttributeContainer.calculate(base: float, flat_type: AttrType.Type, percent_type: AttrType.Type) -> float`
- Produces: `AttributeContainer.attribute_changed(type: AttrType.Type)`

- [ ] **Step 1: Add a failing calculation and source-identity test**

Add `_test_attribute_container()` and call it before scene tests in `_run()`:

```gdscript
func _test_attribute_container() -> bool:
	var glove_a := Equipment.new(23)
	var glove_b := Equipment.new(23)
	var container := AttributeContainer.new()
	container.add_modifier(AttributeModifier.new(glove_a, AttrType.Type.ROTATE_SPEED, 0.5))
	container.add_modifier(AttributeModifier.new(glove_a, AttrType.Type.ROTATE_SPEED_PER, 0.1))
	container.add_modifier(AttributeModifier.new(glove_b, AttrType.Type.ROTATE_SPEED_PER, 0.1))
	if not _assert(is_equal_approx(container.calculate(3.0, AttrType.Type.ROTATE_SPEED, AttrType.Type.ROTATE_SPEED_PER), 4.2), "fixed and percent modifiers should use the agreed formula"):
		return false
	container.remove_by_source(glove_a)
	return _assert(is_equal_approx(container.calculate(3.0, AttrType.Type.ROTATE_SPEED, AttrType.Type.ROTATE_SPEED_PER), 3.3), "same-ID equipment references should be independent")
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/backpack-survivor-equipment-test.log --path . tests/equipment/equipment_runtime_test.tscn
```

Expected: script parse failure because `AttributeContainer`, `AttributeModifier`, and `ROTATE_SPEED_PER` do not exist.

- [ ] **Step 3: Add paired percentage attribute types**

Add `ATK_PER` immediately after `ATK` and `ROTATE_SPEED_PER` immediately after `ROTATE_SPEED`. Add matching `TYPE_TO_KEY` entries and `0.0` defaults.

```gdscript
Type.ATK_PER: "ATK_PER",
Type.ROTATE_SPEED_PER: "ROTATE_SPEED_PER",
```

- [ ] **Step 4: Implement the modifier and calculator**

```gdscript
class_name AttributeModifier
extends RefCounted

var source_equipment: Equipment
var attribute: AttrType.Type
var value: float

func _init(source: Equipment, type: AttrType.Type, amount: float) -> void:
	source_equipment = source
	attribute = type
	value = amount
```

```gdscript
class_name AttributeCalculator
extends RefCounted

static func calculate(base: float, flat: float, percent: float) -> float:
	return (base + flat) * (1.0 + percent)
```

- [ ] **Step 5: Implement the source-aware container**

Store `Array[AttributeModifier]`, sum matching attributes in `get_total()`, remove modifiers with `modifier.source_equipment == source`, and emit `attribute_changed` once for every affected type. `calculate()` delegates to `AttributeCalculator.calculate(base, get_total(flat_type), get_total(percent_type))`. `clear()` removes all modifiers and emits each affected type once.

- [ ] **Step 6: Run the equipment test and commit**

Expected: all existing tests plus `_test_attribute_container()` pass.

```bash
git add scripts/game/module/battle/data/attray_type.gd scripts/game/module/attribute tests/equipment/equipment_runtime_test.gd
git commit -m "Add equipment attribute modifier primitives"
```

---

### Task 2: Passive Equipment Registration and Two-Phase Activation

**Files:**
- Modify: `scripts/game/module/equipment/data/equipment_effect_type.gd`
- Modify: `scripts/game/module/equipment/runtime/equipment_context.gd`
- Modify: `scripts/game/module/equipment/runtime/equipment_effect.gd`
- Modify: `scripts/game/module/equipment/runtime/equipment_effect_factory.gd`
- Modify: `scripts/game/module/equipment/component/equipment_host.gd`
- Create: `scripts/game/module/equipment/effects/passive_attribute_effect.gd`
- Modify: `config/equipments.csv`
- Modify: `tests/equipment/equipment_runtime_test.gd`

**Interfaces:**
- Consumes: Task 1 `AttributeContainer` and `AttributeModifier`
- Produces: `EquipmentEffect.setup(context: EquipmentContext, data: EquipmentData, sources: Array[Equipment]) -> void`
- Produces: `EquipmentEffectType.Type.PASSIVE_ATTRIBUTE`
- Produces: `EquipmentContext.attribute_container: AttributeContainer`

- [ ] **Step 1: Write failing passive-registration tests**

Update the legacy mapping assertion to expect `PASSIVE_ATTRIBUTE`. Add a host test using two distinct `Equipment.new(23)` instances and assert the host container totals `ATK == 20.0` and `ROTATE_SPEED_PER == 0.4`; after `cleanup()`, assert both totals are zero. Expose a read-only `attribute_container` property on `EquipmentHost` for this test.

- [ ] **Step 2: Run the test and verify the old JEWELRY mapping fails**

Run the equipment test scene. Expected: `JEWELRY` still maps to `ROTATE`.

- [ ] **Step 3: Add passive effect parsing and factory creation**

Add `PASSIVE_ATTRIBUTE` to the effect enum, map `JEWELRY` to it, and return `PassiveAttributeEffect.new()` from the factory. Preserve explicit `ROTATE`, `SHOOTER`, and unknown behavior.

- [ ] **Step 4: Preserve exact equipment sources through effect setup**

Replace `count` with `source_equipments: Array[Equipment]` in `EquipmentEffect`; add `get_count() -> int` returning `source_equipments.size()`. Update rotate and shooter effects to use `get_count()`. Extend `EquipmentContext.setup(...)` with an `attributes: AttributeContainer` parameter and assign `attribute_container`.

- [ ] **Step 5: Implement passive modifier registration**

For every source equipment and every key in `equipment_data.attr`, resolve the key with `AttrType.get_type(String(key))`. Ignore invalid types with `DebugUtility.warn`. Register `AttributeModifier.new(source, type, float(value))`. In `cleanup()`, call `remove_by_source()` for every source before calling `super.cleanup()`.

- [ ] **Step 6: Activate passive effects before entity effects**

Have `EquipmentHost` own one container. Group equipment by config ID into `Dictionary[int, Array]`, create all effects, then activate `PASSIVE_ATTRIBUTE` effects first and entity effects second. `cleanup()` cleans effects before clearing the container, making repeated cleanup safe.

- [ ] **Step 7: Configure the first glove interaction**

Correct equipment ID 23's malformed attribute and make it the reference glove:

```csv
23,铁片手套,"1;1;1",3,"ATK:10,ROTATE_SPEED_PER:0.2",20,"res://assets/res/entity/equipment/铁片手套.png",JEWELRY
```

- [ ] **Step 8: Run tests and commit**

Expected: passive modifiers register once per exact equipment reference, cleanup removes them, and legacy jewelry no longer creates rotating entities.

```bash
git add scripts/game/module/equipment config/equipments.csv tests/equipment/equipment_runtime_test.gd
git commit -m "Add passive equipment attribute effects"
```

---

### Task 3: Live Attribute Consumption by Equipment Entities

**Files:**
- Modify: `scripts/game/module/equipment/effects/rotate_weapon_effect.gd`
- Modify: `scripts/game/module/equipment/effects/shooter_effect.gd`
- Modify: `scripts/game/module/equipment/entity/rotate_weapon.gd`
- Modify: `scripts/game/module/equipment/entity/shooter.gd`
- Modify: `tests/equipment/equipment_runtime_test.gd`

**Interfaces:**
- Consumes: `EquipmentContext.attribute_container`
- Produces: `RotateWeapon.setup(base_damage, rotate_radius, base_rotate_speed, shape, texture, attributes)`
- Produces: `Shooter.setup(shoot_interval, bullet_speed, base_damage, radius, count, from, attributes)`

- [ ] **Step 1: Add failing runtime refresh tests**

Create a rotate weapon through the host with a base speed of `10`, then add glove modifiers from two distinct sources. Assert `_rotation_speed == 14.4` for fixed `ATK` tests separately and rotation speed `(10 + 0) * (1 + 0.4) == 14.0`. Remove one glove and assert the existing node changes to `12.0` without recreation. For a shooter with base damage `20`, assert two gloves with `ATK:10` produce `_bullet_damage == 40.0` while `ROTATE_SPEED_PER` does not change its timing.

- [ ] **Step 2: Run the test and verify runtime nodes remain unchanged**

Expected: modifiers exist in the host container, but existing rotate and shooter nodes still expose their base values.

- [ ] **Step 3: Make rotating weapons calculate and refresh runtime values**

Store `_base_attack_power`, `_base_rotation_speed`, and `_attribute_container`. During setup, connect `attribute_changed` to `_on_attribute_changed`. Recalculate damage for `ATK/ATK_PER` and speed for `ROTATE_SPEED/ROTATE_SPEED_PER`; ignore unrelated types. Keep radius as its configured base value.

- [ ] **Step 4: Make shooters calculate and refresh global attack**

Store `_base_bullet_damage` and `_attribute_container`. Recalculate `_bullet_damage` for `ATK` and `ATK_PER` changes. Do not read rotation keys. Ensure `shoot_timer.wait_time` is assigned from `_shoot_interval` during setup so unchanged timing remains explicit.

- [ ] **Step 5: Pass the shared container from both entity effects**

Update both effect setup calls to pass `context.attribute_container`. Preserve entity counts, anchors, textures, shapes, projectile counts, and positioning behavior.

- [ ] **Step 6: Run tests and commit**

Expected: all attribute, passive, rotate, shooter, cleanup, and reinitialize assertions pass.

```bash
git add scripts/game/module/equipment tests/equipment/equipment_runtime_test.gd
git commit -m "Apply passive attributes to equipment entities"
```

---

### Task 4: Project Import and Regression Verification

**Files:**
- Modify only files required to fix failures caused by Tasks 1-3.

**Interfaces:**
- Consumes: completed attribute and equipment runtime system
- Produces: import-clean, integration-tested feature

- [ ] **Step 1: Run the focused integration test**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/backpack-survivor-equipment-test.log --path . tests/equipment/equipment_runtime_test.tscn
```

Expected: exit code `0`; no script errors or failed assertions. Existing environment warnings about macOS CA certificates or the unregistered test scene may remain if unchanged from baseline.

- [ ] **Step 2: Run the project import check**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
```

Expected: exit code `0` and no resource or script parse failures.

- [ ] **Step 3: Check formatting and scope**

```bash
git diff --check
git status --short
```

Expected: no whitespace errors. Confirm the pre-existing deletion of `scripts/game/module/battle/view/entities/.gitkeep` remains outside feature commits unless the user explicitly requests it.

- [ ] **Step 4: Commit any verification-only corrections**

If Task 4 required corrections, stage only those exact files and commit:

```bash
git commit -m "Fix attribute system integration regressions"
```

If no corrections were required, do not create an empty commit.

