# Attribute Modifier System Design

## Goal

Introduce an independent attribute subsystem that lets equipment affect other equipment without direct references between concrete effect types. The first interaction is gloves increasing the rotation speed of every rotating weapon.

## Scope

The first version supports fixed and percentage modifiers, global target tags, runtime add/remove, and repeated `EquipmentHost` initialization. It does not support adjacency, conditional modifiers, persistent equipment instance IDs, or additional arithmetic operations.

## Module Layout

```text
scripts/game/module/attribute/
├── data/
│   ├── attribute_modifier.gd
│   └── attribute_target.gd
├── interfaces/
│   ├── attribute_provider.gd
│   └── attribute_consumer.gd
└── runtime/
    ├── attribute_container.gd
    └── attribute_calculator.gd
```

`AttrType` remains the shared attribute-key definition. `AttributeTarget` defines scopes such as `PLAYER`, `ROTATE_WEAPON`, and `SHOOTER`. Providers register modifiers; consumers query calculated values and react to relevant changes.

## Attribute Representation

Arithmetic behavior is encoded in paired attribute keys rather than a separate operation enum:

```text
ROTATE_SPEED      fixed rotation-speed value
ROTATE_SPEED_PER  percentage rotation-speed value
```

Percentage values use decimals: `0.2` means 20 percent. The calculation rule is:

```text
final = (base + sum(fixed modifiers)) * (1 + sum(percentage modifiers))
```

For example, a base speed of `3.0`, a fixed modifier of `0.5`, and a percentage modifier of `0.2` produce `4.2`.

## Modifier Identity and Ownership

Each modifier contains:

- `source_equipment: Equipment`
- `target: AttributeTarget.Type`
- `attribute: AttrType.Type`
- `value: float`

The `Equipment` object reference identifies a runtime equipment instance. Two gloves with the same configuration ID remain distinct sources. Removing one glove removes only modifiers whose `source_equipment` is that exact object. Persistent instance identity is deferred until mid-battle save restoration is required.

## Lifecycle and Data Flow

`EquipmentHost.initialize()` performs two phases:

1. Create passive attribute effects and register their modifiers.
2. Create entity effects such as rotating weapons and shooters.

This guarantees that a newly created rotating weapon sees all active glove modifiers immediately.

```text
Glove Equipment
  -> PassiveAttributeEffect
  -> AttributeModifier(target=ROTATE_WEAPON)
  -> AttributeContainer.add_modifier()
  -> attribute_changed
  -> RotateWeapon reads ROTATE_SPEED and ROTATE_SPEED_PER
  -> AttributeCalculator
  -> runtime rotation speed
```

A rotating weapon retains its configured speed as an immutable base value. It listens for matching attribute changes and recalculates its runtime speed. Because every rotating weapon uses the `ROTATE_WEAPON` target, one glove affects existing and subsequently created rotating weapons while leaving shooters unchanged.

On unequip, `PassiveAttributeEffect.cleanup()` removes all modifiers associated with its `Equipment` reference. The container emits the corresponding change notification, and all rotating weapons recalculate. Host cleanup and reinitialization must be idempotent.

## Error Handling

Missing modifier totals are treated as zero. Invalid attribute keys, missing targets, and unsupported passive equipment configurations are ignored with a diagnostic warning rather than interrupting battle initialization.

## Verification

Automated integration coverage will verify:

- Fixed and percentage modifiers calculate `4.2` from `3.0`, `0.5`, and `0.2`.
- Two same-ID gloves remain independent by object reference.
- Removing one source preserves the other source's modifier.
- One glove affects every rotating weapon but not shooters.
- Weapons created after modifier registration receive the modifier.
- Removing a glove updates existing weapons immediately.
- Reinitializing the host does not duplicate or retain modifiers.
- A missing percentage attribute defaults to zero.

