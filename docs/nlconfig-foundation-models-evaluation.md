# NL Config — Apple Foundation Models Evaluation

## What we tried

Issue #536 proposed letting users configure ControlPlane in plain English — type
"Start Chrome when I connect my LG monitor" and have the app produce the correct
profile, rules, and actions automatically.

To evaluate feasibility we built a standalone test harness:
`experiments/NLConfig/` — a SwiftUI app that sends user input to Apple's
on-device Foundation Models framework and attempts to decode the response as a
`ParsedConfig` (profile + rules + actions). The harness also generates `cpctl`
commands from the decoded output so results can be applied immediately.

The harness is on branch `feature/536-nlconfig-experiment` (PR #537, not merged).
Read that branch if you want to understand the full prompt and schema design.

---

## Build / toolchain challenges

Before we could even test quality, we hit a cascade of toolchain problems:

- `@Generable` and `@Guide` macros (the idiomatic Foundation Models structured
  output API) require the `FoundationModelsMacros` compiler plugin, which only
  ships inside Xcode — not the standalone Command Line Tools. `swift build` and
  `swift run` from the terminal fail with "plugin not found" even on a machine
  that has the macOS 26 SDK. We replaced the macros with plain `Decodable` structs
  and raw string response parsing as a workaround.

- `.macOS(.v15)` in Package.swift requires `swift-tools-version: 6.0`.
  `.macOS(.v26)` requires `swift-tools-version: 6.2`. The system `swift` binary
  (from Command Line Tools) may be 5.9-era and reject the manifest entirely. The
  Makefile in `experiments/NLConfig/` uses `xcrun swift` to route through Xcode's
  toolchain instead.

- When launched via `swift run`, the app window opens but the terminal retains
  keyboard focus. The fix requires `NSApplication.shared.setActivationPolicy(.regular)`
  in `init()` and `activate(ignoringOtherApps: true)` in `applicationDidFinishLaunching`
  via an `NSApplicationDelegate`. Without both, the window is visible but unresponsive
  to keyboard input.

---

## Model quality issues

This is the core reason we did not proceed. We tested iteratively against realistic
user prompts and encountered the following problems.

### 1. Persistent action hallucination

The most frequent failure: the model adds actions that were never requested.

- Prompt: *"create a rule that when I am connected to megahertz to activate my
  Work profile. It should have 100% confidence"*
- Expected actions: none (user asked for a rule, not any effects)
- Actual (repeated across multiple runs): the model added `com.controlplane.action.open`
  with Chrome, `com.controlplane.action.lockkeychain`, and on one run invented a
  completely fictional `com.controlplane.action.activateWorkprofile` ID.

We patched the system prompt multiple times — explicit "ONLY ADD WHAT WAS ASKED",
worked examples with `actions: [] ← EMPTY` annotations, moving the instruction
to immediately precede the actions section in the prompt. None of it reliably
stopped the behaviour.

### 2. Invented action IDs

The model fabricated action identifiers that don't exist in the vocabulary:
`com.controlplane.action.activateWorkprofile` is a representative example.
No amount of "this is the complete list, never invent IDs" instruction prevented
it across all prompts.

We added a post-decode filter that strips any `actionID` not in the known
vocabulary set. This was the point at which we recognised we were fighting the
model rather than working with it.

### 3. Rules vs. actions confusion

The model repeatedly treated effects (things ControlPlane should do) as
conditions (environmental state to detect):

- "Turn off Wi-Fi when screen locks" → model created a `wifi.connected isFalse`
  rule instead of a `togglewifi` action.
- "Lock my keychain" → model sometimes treated screen-lock state as both the
  trigger rule and the action simultaneously.

Extensive prompt engineering (a `CRITICAL DISTINCTION` section, concrete
examples of things that are actions not rules) reduced but did not eliminate
this.

### 4. Wrong config key names

The model invented config key names for actions:
- `lockkeychain` action (no config) received `keychainLock="true"`
- `togglewifi` action received `wifiDisconnect="true"` instead of `state="off"`

### 5. Invalid JSON syntax

On one run the model produced `"configEntries": ["state": "off"]` — Swift
dictionary literal syntax embedded in a JSON response. This is not valid JSON
and caused a decode failure. Added a `CORRECT/WRONG` example to the system
prompt and a brace-extraction fallback in the decoder.

### 6. Preamble / code fence pollution

Despite the instruction "Return ONLY the JSON. No prose. No markdown fences",
the model frequently:
- Prefaced the JSON with "Here is the JSON for the profile to start Chrome..."
- Wrapped the JSON in ` ```json ... ``` ` fences

We added a three-stage extraction pipeline (fence-strip → brace-scan →
decode) to handle this. It works, but is another layer of workaround.

---

## The core problem

Apple's on-device Foundation Models are a small, instruction-constrained model
optimised for Apple system tasks (summarisation, writing assistance, Siri
suggestions). What ControlPlane NL Config requires is:

- Precise mapping of free-form language to a specific structured vocabulary
- Reliable suppression of output that wasn't asked for
- Consistent JSON schema compliance
- Distinction between "conditions" and "effects" — a semantic reasoning task

Small models struggle with all of these when combined. Each prompt patch fixed
one test case and broke or failed to prevent another. By the time we stopped,
the harness had: a heavily annotated system prompt (~170 lines), a three-stage
JSON extraction pipeline, a post-decode vocabulary filter, and multiple worked
examples — and was still producing spurious actions on the primary test prompt.

---

## Why we did not merge

The post-processing filters introduced a correctness risk: if a user legitimately
asks to open Chrome when connecting to a network, the filter would pass it
through — but if the model adds Chrome unprompted alongside a legitimate action,
we can't distinguish them. The filters make the output look better in demos but
don't make the feature reliable for production.

Merging would imply the approach works. It doesn't, at this model scale.

---

## Recommended path forward

The concept is sound — the vocabulary design, the `cpctl` command generation,
the `createProfile` inference, and the UX are all good. The model is the weak
link.

**MLX with a selected model** is the right next evaluation step:
- Works on any Apple Silicon Mac running macOS 13+, no Apple Intelligence required
- A 7–8B instruction-tuned model (Llama 3.1 8B, Qwen2.5 7B) with JSON mode
  handles structured output constraints reliably
- Model is user-selectable — can benchmark quality vs. size trade-offs
- Native Swift via `mlx-swift` + `mlx-swift-examples`, no Python required
- Downside: user must download model weights (~4–8 GB for 4-bit quantised 8B)

Once proven with a capable model, the decision of whether to ship with MLX,
wait for Apple's models to improve, or offer both is a product decision —
not a technical unknown.

The harness in `experiments/NLConfig/` is worth keeping as the test bed for
that evaluation. The system prompt, vocabulary, and schema design carry over
directly.
