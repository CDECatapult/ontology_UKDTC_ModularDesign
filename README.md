# DTDL Modeling Tips

## 1. General Rules

Each model requires:

- `@id` → valid DTMI (e.g., `dtmi:ex:domain:RobotArm;1`)
- `@type` → always `"Interface"`
- `@context` → `"dtmi:dtdl:context;2"`

```bash
dtmi:ex:domain:RobotArm;1  

# almost like folder but then if you place them in seperate folder they cant communicate

/dtmi/ex/domain/robotarm-1.json

```

All `contents` name fields must be unique inside an interface.

Use `camelCase` or `snake_case` for `name`; spaces and special characters are not allowed.

Use `displayName` for human-readable names with spaces.

## 2. Types of Contents

- **Property**: persistent or stateful values
- **Telemetry**: live/streaming values
- **Command**: actions that can be invoked
- **Relationship**: links to independent twins
- **Component**: embedded models that are not independent

## 3. Enums

Used when property values are constrained to a fixed set.

Must define `valueSchema` and `enumValues`.

```bash
{
  "@type": "Property",
  "name": "status",
  "schema": {
    "@type": "Enum",
    "valueSchema": "string",
    "enumValues": [
      { "name": "Idle", "enumValue": "idle" },
      { "name": "Running", "enumValue": "running" },
      { "name": "Fault", "enumValue": "fault" }
    ]
  }
}
```

## 4. Relationships vs Components

**Use Relationship:**

- For devices/components that are independent entities
- When parts can be swapped, detached, or reused

**Use Component:**

- For embedded parts that do not exist independently
- When tightly coupled with the parent lifecycle

## 5. Multiplicity Rules

- `minMultiplicity` must always be `0`
- `maxMultiplicity` must be an integer between `1` and `500`

Example: a robot with up to 6 joints:

```bash
{
  "@type": "Relationship",
  "name": "hasJoint",
  "target": "dtmi:ex:domain:RobotJoint;1",
  "minMultiplicity": 0,
  "maxMultiplicity": 6
}
```

## 6. Ontology Patterns

**Container model (system)**

- Example: `ProjectCell`
- Relationships like `hasRobotArm`, `hasConveyor`

**Device model**

- Example: `RobotArm`, `StraightConveyor`
- Defines properties, telemetry, commands

**Part model**

- Example: `Joint`, `Gripper`
- Represented either as relationships or components

## 7. Twin Graphs

- **Models** = type definitions
- **Twins** = actual instances
- **Relationships** between twins form the graph

Example:

```bash
ProjectCell
 ├─ hasConveyor → StraightConveyor
 │                 └─ feeds → RobotArm
 └─ hasRobotArm → RobotArm
                   ├─ hasJoint → RobotJoint (x6)
                   └─ hasGripper → Gripper
```

Save this as `DTDL_TIPS.md` in your project directory for reference.
