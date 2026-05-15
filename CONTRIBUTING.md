# Contributing to ControlPlane

ControlPlane is in alpha. Contributions are welcome — please read this document
before opening issues or submitting pull requests.

---

## Branching model

| Branch | Purpose |
|--------|---------|
| `main` | Always stable and releasable. Direct commits are reserved for trivial changes (typos, docs). All feature work merges here via pull request. |
| `feature/<short-description>` | New features and enhancements, e.g. `feature/gui-profiles` |
| `fix/<short-description>` | Bug fixes, e.g. `fix/bluetooth-tcc-crash` |

Branch names should reference the issue number when one exists:
`feature/525-gui-profiles`, `fix/524-db-migration`.

Pull requests must target `main`. A PR is required even for maintainer commits
on anything beyond a trivial change — it creates a clear record of what changed and why.

---

## Issues

### Opening an issue

- **Bug** — describe what you did, what you expected, and what happened. Include
  macOS version and ControlPlane version.
- **Feature request** — describe the use case, not just the desired feature. Issues
  that explain *why* are much easier to prioritise.

### Label system

**Status labels** — applied to every issue:

| Label | Meaning |
|-------|---------|
| `needs-review` | Not yet accepted. Do not begin implementation. |
| `roadmap` | Accepted and committed. Officially planned work. |
| `wont-implement` | Explicitly decided against — not feasible, out of scope, or deliberately excluded. |

**Type labels:**

| Label | Meaning |
|-------|---------|
| `feature-request` | Request for new functionality |
| `bug` | Something is broken |

**Area labels** — describe which part of the codebase the issue relates to:

| Label | Scope |
|-------|-------|
| `area: sensors` | Evidence source / sensor plugins |
| `area: actions` | Action plugins |
| `area: rules` | Rules engine, confidence model, evaluation |
| `area: profiles` | Profile management and activation behaviour |
| `area: ui` | GUI, menu bar, preferences |
| `area: core` | Core engine, scheduling, socket server, database |

### Feature request lifecycle

1. Issue is opened → labelled `feature-request` + `needs-review` + an `area:` label.
2. Maintainer reviews it — three outcomes:
   - **Accept** → add `roadmap`, remove `needs-review`. Now committed work.
   - **Reject** → add `wont-implement`, close with a reason.
   - **Defer** → leave `needs-review`, add a comment. Revisit later.
3. Accepted issues can be picked up by contributors. Check the
   [open roadmap issues](https://github.com/dustinrue/ControlPlane/issues?q=is%3Aopen+label%3Aroadmap)
   for what is actively planned.

> **Important:** `feature-request` + `needs-review` does **not** mean the feature will
> be built. Do not begin implementation until `roadmap` has been applied.

---

## Building

Requires Xcode 15+ and Swift 5.9+. A Mac with both Apple Silicon and Rosetta is
recommended for building universal binaries.

```bash
# Build both products for the current arch (fast, for development)
swift build

# Build universal fat binaries (arm64 + x86_64)
make build

# Build, assemble .app bundle, and launch
make run
```

`make run` assembles `ControlPlane.app` in the project root, kills any running
instance, and relaunches. The `cpctl` binary is copied into the app bundle so the
auto-install path works end-to-end.

### First-time universal build

If `make build` fails with `lipo: can't open input file` for a new module, the
x86_64 cache needs priming:

```bash
swift build --arch x86_64 --product ControlPlane
make build
```

---

## Pull request checklist

- [ ] Branch targets `main`, named `feature/…` or `fix/…`
- [ ] Corresponds to an open `roadmap` issue (link it in the PR description)
- [ ] `swift build` passes cleanly with no warnings
- [ ] New sensor or action module added to `Package.swift` and registered in `Backend.swift`
- [ ] CLAUDE.md updated if any architectural convention changes
- [ ] No secrets, credentials, or `~/…` hardcoded paths committed

---

## Architecture

See [`CLAUDE.md`](CLAUDE.md) for a full architecture reference including plugin
conventions, the sensor/rule/action model, known traps, and implemented plugin tables.

See [`docs/rules-engine.md`](docs/rules-engine.md) for the rules engine design.
