# Equipment Attribute Aggregation Design

## Goal

Reuse the existing `AttrContainer` to maintain the current total of passive equipment attributes. Keep the system small: no modifier objects, source tracking, second attribute container type, or dedicated attribute-change signal.

## Ownership

`BackpackManager` is already an autoload and owns the backpack equipment collection. It therefore owns one public aggregate container:

```gdscript
var equipment_attrs: AttrContainer = AttrContainer.new()
```

No additional autoload is introduced. `AttrContainer` continues to provide its existing dictionary-based `set_value()`, `get_value()`, `has()`, and `reset()` APIs.

## Recalculation

Every successful backpack equipment change rebuilds the aggregate from the current `backpack_equip` collection:

1. Reset `equipment_attrs`.
2. Iterate all equipment currently in the backpack.
3. Load each `EquipmentData` configuration.
4. Skip equipment whose effect type is not `PASSIVE_ATTRIBUTE`.
5. Resolve each configured attribute key with `AttrType.get_type()`.
6. Add the configured value to the aggregate.

Because `AttrContainer.get_value()` falls back to type-specific defaults, callers must check `has(type)` before reading an additive equipment value. A missing equipment modifier is `0.0`; the container is not pre-populated with zero values.

```gdscript
var old_value := 0.0
if equipment_attrs.has(type):
	old_value = equipment_attrs.get_value(type)
equipment_attrs.set_value(type, old_value + value)
```

The backpack contains few items, so a complete rebuild is preferred over incremental bookkeeping. This makes removal and replacement correct without retaining equipment identity or subtraction history.

## Change Notification

The existing `BackpackManager.equip_changed` signal is reused. Every mutation path calls one internal method that recalculates first and emits second:

```gdscript
func _notify_equipment_changed() -> void:
	recalculate_equipment_attrs()
	equip_changed.emit()
```

Consumers therefore receive the signal only after `equipment_attrs` contains the latest totals. Initialization must also leave the aggregate correct when the new backpack has no equipment.

## Equipment Runtime

`PASSIVE_ATTRIBUTE` remains an `EquipmentEffectType` so configuration rows can be classified, but passive equipment does not create an `EquipmentEffect` at runtime. `EquipmentHost` skips passive entries and creates only entity effects such as rotating weapons and shooters.

`RotateWeapon` and `Shooter` read `BackpackManager.equipment_attrs` directly and listen to `equip_changed`. Each lookup checks `has()` before `get_value()` and treats a missing key as zero.

The calculation rule remains:

```text
final = (base + flat equipment total) * (1 + percentage equipment total)
```

`ATK` and `ATK_PER` affect every equipment-created damage source. `ROTATE_SPEED` and `ROTATE_SPEED_PER` are read only by rotating weapons. Attribute names encode their scope.

## Removed Components

The refactor removes:

- `attribute_modifier.gd`
- the new equipment-specific `attribute_container.gd`
- `attribute_calculator.gd`
- `passive_attribute_effect.gd`
- `EquipmentContext.attribute_container`
- `EquipmentHost` attribute-container ownership and passive activation phase

The original `scripts/game/module/battle/data/attray_container.gd` remains the only attribute container implementation.

## Data Flow

```text
Backpack add/remove/move succeeds
  -> BackpackManager._notify_equipment_changed()
  -> reset and rebuild equipment_attrs from all passive backpack equipment
  -> equip_changed.emit()
  -> RotateWeapon and Shooter refresh
  -> has(type), then get_value(type)
  -> calculate runtime value from immutable base value
```

## Error Handling

Missing equipment configuration and unknown attribute keys are skipped with diagnostic warnings. Missing aggregate attributes are treated as `0.0`. Recalculation must not interrupt backpack operations or battle initialization.

## Verification

Tests will verify:

- Multiple passive items add their attributes during a full rebuild.
- Removing one passive item and rebuilding produces the correct remaining total.
- An empty backpack clears previous totals.
- Entity equipment attributes are not added to the passive aggregate.
- `equip_changed` is emitted after the aggregate is current.
- All rotating weapons receive the same rotation-speed bonus.
- Global attack bonuses affect rotating and shooting equipment.
- Missing flat or percentage keys behave as zero.
- Repeated host initialization does not create passive entities or duplicate bonuses.
