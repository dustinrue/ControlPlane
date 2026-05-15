# Rules Engine Design

## Mental model

```
Sensor snapshot → RuleEngine.evaluate()
  → for each profile:
       confidence = Σ weight of each matching enabled rule
       if confidence >= profile.confidenceThreshold → candidate
  → ProfileActivationManager resolves candidates → active profiles → actions fire
```

A **Rule** is a single condition. A profile can have many rules. Multiple matching
rules are additive — their weights sum toward the profile's threshold.

---

## Key types

### `Rule` (`Sources/ControlPlaneSDK/Rule.swift`)

```swift
struct Rule: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let name: String
    let profileID: UUID
    let sensorID: String        // e.g. "com.controlplane.sensors.wifi"
    let readingKey: String      // e.g. "ssid"
    let operatorID: String      // e.g. "equals"
    let comparand: ObservationValue
    let evaluatorID: String     // default: "com.controlplane.evaluator.basic"
    let weight: Double          // confidence points added when matched (default 1.0)
    let enabled: Bool
    let createdAt: Date
    let updatedAt: Date
}
```

### `Profile` (`Sources/ControlPlaneSDK/Profile.swift`)

```swift
struct Profile: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let confidenceThreshold: Double  // minimum Σ weight to activate (default 1.0)
    // ...
}
```

### `EvaluatorPlugin` (`Sources/ControlPlaneSDK/PluginProtocols.swift`)

```swift
public protocol EvaluatorPlugin: ControlPlanePlugin {
    func evaluate(reading: ObservationValue?,
                  operator operatorID: String,
                  comparand: ObservationValue) -> Bool
    func supportedOperators() -> [OperatorDescriptor]
}
```

Synchronous only. AI/ML evaluators can use cached results if needed.

### `OperatorDescriptor`

```swift
struct OperatorDescriptor: Codable, Sendable {
    let id: String              // e.g. "equals"
    let label: String           // e.g. "="
    let applicableTypes: [String]  // "string", "boolean", "number", "strings"
}
```

---

## Backend components (`Sources/ControlPlaneApp/`)

### `RuleStore.swift` (actor)
GRDB-backed CRUD for rules. Mirrors `ProfileStore`. Internal `RuleRecord` bridges
between the SQLite schema and the `Rule` SDK type.

### `EvaluatorRegistry.swift` (actor)
Stores `[String: any EvaluatorPlugin]`. Methods: `register(_:)`,
`list() -> [EvaluatorInfo]`, `evaluator(for:) -> (any EvaluatorPlugin)?`.

### `DefaultEvaluator.swift` (`Sources/Evaluators/Default/`)
Always-registered built-in evaluator. Supported operators:

| Operator | Symbol | Types |
|----------|--------|-------|
| `equals` | = | all |
| `notEquals` | ≠ | all |
| `greaterThan` | > | number, string |
| `lessThan` | < | number, string |
| `greaterThanOrEqual` | ≥ | number, string |
| `lessThanOrEqual` | ≤ | number, string |
| `contains` | contains | string, strings |
| `notContains` | does not contain | string, strings |
| `startsWith` | starts with | string |
| `endsWith` | ends with | string |
| `isTrue` | is true | boolean |
| `isFalse` | is false | boolean |

### `RuleEngine.swift` (actor)
Called by `SensorCoordinator` on every snapshot change.

Evaluation loop:
1. Fetch all enabled rules from `RuleStore`
2. For each rule, find the snapshot for `rule.sensorID`
3. Find the reading for `rule.readingKey` in that snapshot
4. Look up `rule.evaluatorID` in `EvaluatorRegistry`; call `evaluate(reading:operator:comparand:)`
5. Accumulate weight per `profileID`
6. Fetch all profiles; filter to those where `confidence >= profile.confidenceThreshold`
7. Return `[ActiveProfile]` to `ProfileActivationManager`

---

## Database schema

### Migration v1 (initial)

```sql
CREATE TABLE profiles (
    id                  TEXT PRIMARY KEY,
    name                TEXT NOT NULL,
    confidenceThreshold REAL NOT NULL DEFAULT 1.0,
    exclusive           INTEGER NOT NULL DEFAULT 0,
    parentId            TEXT REFERENCES profiles(id) ON DELETE SET NULL,
    createdAt           TEXT NOT NULL,
    updatedAt           TEXT NOT NULL
);
```

### Migration v2 (rules)

```sql
CREATE TABLE rules (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    profileId       TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    sensorId        TEXT NOT NULL,
    readingKey      TEXT NOT NULL,
    operator        TEXT NOT NULL,
    comparandType   TEXT NOT NULL,   -- ObservationValue type tag
    comparandValue  TEXT NOT NULL,   -- JSON-encoded inner value
    evaluatorId     TEXT NOT NULL DEFAULT 'com.controlplane.evaluator.basic',
    weight          REAL NOT NULL DEFAULT 1.0,
    enabled         INTEGER NOT NULL DEFAULT 1,
    createdAt       TEXT NOT NULL,
    updatedAt       TEXT NOT NULL
);
```

---

## cpctl commands

```
cpctl rules list [--profile <name|uuid>]   # shows match status (✓/✗) for each rule
cpctl rules add  --profile <name|uuid> \
                 --sensor <sensorID> \
                 --key <readingKey> \
                 --op <operator> \
                 --value <comparand> \
                 [--name <label>] \
                 [--weight <n>] \
                 [--evaluator <id>]
cpctl rules delete <uuid> [--force]
cpctl rules enable  <uuid>
cpctl rules disable <uuid>

cpctl profiles active                      # live confidence scores
cpctl evaluators list                      # operators per evaluator
```

---

## Example

```bash
# Activate "Home" profile when connected to home WiFi
cpctl profiles add "Home"
cpctl rules add \
  --profile Home \
  --sensor com.controlplane.sensors.wifi \
  --key ssid \
  --op equals \
  --value "MyHomeSSID" \
  --name "Home WiFi"

# Verify
cpctl profiles active
# → CONFIDENCE  NAME   ID
# → 1.00        Home   <uuid>
```
