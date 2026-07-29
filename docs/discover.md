# Discover

Step 5 of [the migration walkthrough](start.md): pull the whole estate from the
source into the local store — **read-only**.

## Step 5 — discover the estate

```bash
liftoff discover
```

Pulls everything from the source into the local store. This is a **read-only**
pull and the only network-bound read — its duration scales with the estate. It
is idempotent and resumable: if it dies or you kill it, run it again and it picks
up where it left off, **preserving any staging choices you've already made**.
Progress goes to stderr: add `-v` to watch it work, and repeat for more detail
(`-vv`).

```text
Source  terraform

Sensitive Values
  Sensitive Variables  22
  Captured             0
  Empty                22

  Notes (2)
    - 19 sensitive stack variable value(s) are empty — stage the workspaces, then run `liftoff mutate --allow-mutation
      secrets` to capture them, or set them in Spacelift after the migration
    - 3 sensitive context variable value(s) are empty — set them in Spacelift after the migration

Counts
  Context Variables  6
  Contexts           3
  Modules            1
  Mounted Files      0
  Spaces             9
  Stack Variables    41
  Stacks             13

Next
  $ liftoff batch list
```

`Counts` is what actually landed in the store, read back after the run.
`Sensitive Values` is the report on the one thing discover cannot take: secret
values. Discover **never touches the source**, so sensitive values always come
over empty — the notes say exactly what that means and how to capture them later
(stage the workspaces, then [`liftoff mutate`](mutate.md)).

Discover is deliberately whole-estate and read-only: you can't choose what to
migrate until you can see everything, and pulling it all is safe because nothing
is mutated. From here you pick a batch with [`liftoff batch`](batch.md); the
heavy, source-touching work ([`mutate`](mutate.md)) runs later and only for what
you stage.

Two behaviors worth knowing:

- **Running discover again is always safe.** When there's nothing new it says so
  and changes nothing; it never resets the staging choices you've made. The
  `liftoff discover --clobber` hint it offers is the start-fresh option, colored
  as a caution because it throws away the local results *and* your staging.
- **Re-discovering after migrating a batch is additive.** It refreshes entity
  data, skips nothing you've staged or migrated, and picks up new source
  entities — so the next batch starts from a current picture.
- **Teams come over as audit-only data.** Discover records your TFC teams and
  their access, but the kit never generates Spacelift access from them — TFC
  RBAC doesn't map 1:1. [`audit`](audit.md) surfaces each team so you
  can recreate access deliberately; nothing is placed in a space.

From here, no command touches the network until the module is handed to
Spacelift: [batch](batch.md), [audit](audit.md), and [generate](generate.md)
all read the store you just filled.
