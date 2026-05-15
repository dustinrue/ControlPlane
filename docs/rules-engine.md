# Rules Engine Design

## Mental model

```
Sensor snapshot → RuleEngine.evaluate()
  → for each profile:
       unconfidence = ∏(1 − weight)  for each matching enabled rule
       confidence   = 1 − unconfidence
       if confidence >= profile.confidenceThreshold → candidate
  → ProfileActivationManager resolves candidates → active profiles → actions fire
```

A **Rule** is a single condition. A profile can have many rules. Multiple matching
rules combine using a **multiplicative inverse (unconfidence) model** — the same
algorithm as the original ControlPlane app.

The intuition: each unmatched rule leaves some residual doubt. Matching rules
eliminate doubt multiplicatively rather than summing weights, so two moderately
confident signals together give higher combined confidence than either alone:

```
AC power rule  (weight 0.6) matches → unconfidence: 1.0 × 0.4 = 0.40
Home WiFi rule (weight 0.7) matches → unconfidence: 0.4 × 0.3 = 0.12
Final confidence = 1 − 0.12 = 0.88  →  profile threshold 0.75 → ACTIVE

AC power alone: confidence = 1 − 0.4 = 0.60  →  below 0.75 → NOT active
```

A rule with `negate: true` has its raw evaluator result inverted before
contributing to confidence — it "matches" (adds weight) when the underlying
sensor condition is **absent**. Use this for disqualifying conditions:
"corporate VPN is NOT connected".

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
    let weight: Double          // confidence weight 0.0–1.0 (default 1.0)
    let negate: Bool            // invert match result (default false)
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
    let confidenceThreshold: Double  // minimum confidence to activate (default 1.0)
    // ...
}
```

### `EvaluatorPlugin` (`Sources/ControlPlaneSDK/Rule.swift`)

```swift
public protocol EvaluatorPlugin: ControlPlanePlugin {
    func evaluate(reading: ObservationValue?,
                  operatorID: String,
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
4. Look up `rule.evaluatorID` in `EvaluatorRegistry`; call `evaluate(reading:operatorID:comparand:)`
5. If `rule.negate` is true, invert the result
6. If matched, multiply the profile's running unconfidence by `(1.0 − rule.weight)`
7. After all rules: `confidence = 1.0 − unconfidence` per profile
8. Fetch all profiles; filter to those where `confidence >= profile.confidenceThreshold`
9. Return `[ActiveProfile]` to `ProfileActivationManager`

---

## Database schema

### Migration v1 — profiles

```sql
CREATE TABLE profiles (
    id        TEXT PRIMARY KEY,
    name      TEXT NOT NULL,
    parentId  TEXT REFERENCES profiles(id) ON DELETE SET NULL,
    exclusive INTEGER NOT NULL DEFAULT 0,
    createdAt TEXT NOT NULL,
    updatedAt TEXT NOT NULL
);
```

### Migration v2 — rules

```sql
ALTER TABLE profiles ADD COLUMN confidenceThreshold REAL NOT NULL DEFAULT 1.0;

CREATE TABLE rules (
    id             TEXT PRIMARY KEY,
    name           TEXT NOT NULL,
    profileId      TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    sensorId       TEXT NOT NULL,
    readingKey     TEXT NOT NULL,
    operatorId     TEXT NOT NULL,
    comparandType  TEXT NOT NULL,   -- ObservationValue type tag
    comparandValue TEXT NOT NULL,   -- serialised inner value
    evaluatorId    TEXT NOT NULL DEFAULT 'com.controlplane.evaluator.basic',
    weight         REAL NOT NULL DEFAULT 1.0,
    enabled        INTEGER NOT NULL DEFAULT 1,
    createdAt      TEXT NOT NULL,
    updatedAt      TEXT NOT NULL
);
```

### Migration v6 — rule negation

```sql
ALTER TABLE rules ADD COLUMN negate INTEGER NOT NULL DEFAULT 0;
```

---

## cpctl commands

```
cpctl rules list [--profile <name|uuid>]   # shows match status (✓/✗) and negate flag
cpctl rules add  --profile <name|uuid> \
                 --sensor <sensorID> \
                 --key <readingKey> \
                 --op <operator> \
                 --value <comparand> \
                 [--name <label>] \
                 [--weight <n>] \
                 [--negate] \
                 [--evaluator <id>]
cpctl rules delete <uuid> [--force]
cpctl rules enable  <uuid>
cpctl rules disable <uuid>

cpctl profiles active                      # live confidence scores
cpctl evaluators list                      # operators per evaluator
```

---

## Examples

### Single rule — full confidence

```bash
# One rule with default weight 1.0 → confidence 1.0 → meets default threshold 1.0
cpctl profiles add "Home"
cpctl rules add \
  --profile Home \
  --sensor com.controlplane.sensors.wifi \
  --key ssid \
  --op equals \
  --value "MyHomeSSID" \
  --name "Home WiFi"

cpctl profiles active
# → CONFIDENCE  NAME   ID
# → 1.00        Home   <uuid>
```

### Multiple weighted rules — require agreement

```bash
# Neither rule alone (0.6 or 0.7) meets the 0.75 threshold.
# Both together: 1 − (0.4 × 0.3) = 0.88 → ACTIVE.
cpctl profiles add "Work"
cpctl profiles update Work --threshold 0.75

cpctl rules add --profile Work \
  --sensor com.controlplane.sensors.power \
  --key source --op equals --value ac \
  --name "On AC power" --weight 0.6

cpctl rules add --profile Work \
  --sensor com.controlplane.sensors.wifi \
  --key ssid --op equals --value "CorpWiFi" \
  --name "Work WiFi" --weight 0.7
```

### Negated rule — disqualifying condition

```bash
# Matches (adds weight) only when the VPN is NOT connected.
cpctl rules add --profile Home \
  --sensor com.controlplane.sensors.networklink \
  --key utun0 --op equals --value true \
  --name "No VPN" --weight 0.5 \
  --negate
```
