# Attribute Modifier System Design

## Goal

Introduce an independent attribute subsystem that lets equipment affect other equipment without direct references between concrete effect types. The first interaction is gloves increasing the rotation speed of every rotating weapon. Global attack modifiers affect every equipment-created damage source.

## Scope

The first version supports fixed and percentage modifiers, attribute-name-based scope, runtime add/remove, and repeated `EquipmentHost` initialization. It does not support adjacency, conditional modifiers, persistent equipment instance IDs, or additional arithmetic operations.

## Module Layout

```text
scripts/game/module/attribute/
├── data/
│   └── attribute_modifier.gd
└── runtime/
    ├── attribute_container.gd
    └── attribute_calculator.gd
```

`AttrType` remains the shared attribute-key definition. Attribute names encode their scope: rotating weapons read rotation attributes, shooters read shooting attributes, and all equipment damage sources read global attack attributes. This removes the need for separate provider, consumer, and target abstractions.

`EquipmentHost` owns one shared `AttributeContainer`. Passive effects register modifiers in that container, while entity effects pass the same container to the runtime entities they create.

## Attribute Representation

Arithmetic behavior is encoded in paired attribute keys rather than a separate operation enum:

```text
ROTATE_SPEED      fixed rotation-speed value
ROTATE_SPEED_PER  percentage rotation-speed value
ATK               fixed global equipment-attack value
ATK_PER           percentage global equipment-attack value
```

Percentage values use decimals: `0.2` means 20 percent. The calculation rule is:

```text
final = (base + sum(fixed modifiers)) * (1 + sum(percentage modifiers))
```

For example, a base speed of `3.0`, a fixed modifier of `0.5`, and a percentage modifier of `0.2` produce `4.2`.

An entity equipment's `ATK` is its own base attack. A passive equipment's `ATK` and `ATK_PER` become global modifiers. Every rotating and shooting weapon calculates damage as `(equipment base ATK + global ATK) * (1 + global ATK_PER)`. More specific attack scopes can be added later if required.

## Modifier Identity and Ownership

Each modifier contains:

- `source_equipment: Equipment`
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
  -> EquipmentHost.attribute_container.add_modifier()
  -> attribute_changed
  -> RotateWeapon reads ROTATE_SPEED and ROTATE_SPEED_PER
  -> AttributeCalculator
  -> runtime rotation speed
```

A rotating weapon retains its configured speed as an immutable base value. It listens for relevant attribute changes and recalculates its runtime speed. Because every rotating weapon reads `ROTATE_SPEED` and `ROTATE_SPEED_PER`, one glove affects existing and subsequently created rotating weapons. Shooters do not read those keys and remain unchanged.

On unequip, `PassiveAttributeEffect.cleanup()` removes all modifiers associated with its `Equipment` reference. The container emits the corresponding change notification, and all rotating weapons recalculate. Host cleanup and reinitialization must be idempotent.

## Error Handling

Missing modifier totals are treated as zero. Invalid attribute keys and unsupported passive equipment configurations are ignored with a diagnostic warning rather than interrupting battle initialization.

## Verification

Automated integration coverage will verify:

- Fixed and percentage modifiers calculate `4.2` from `3.0`, `0.5`, and `0.2`.
- Two same-ID gloves remain independent by object reference.
- Removing one source preserves the other source's modifier.
- One glove affects every rotating weapon but not shooters.
- Global `ATK` and `ATK_PER` modifiers affect both rotating and shooting weapons.
- Weapons created after modifier registration receive the modifier.
- Removing a glove updates existing weapons immediately.
- Reinitializing the host does not duplicate or retain modifiers.
- A missing percentage attribute defaults to zero.
