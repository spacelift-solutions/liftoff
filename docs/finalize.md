# Finalize

Step 11 of [the migration walkthrough](start.md): mark the staged batch
migrated, closing the loop so the next batch starts clean.

## Step 11 — finalize the batch

```bash
liftoff finalize staged
```

Flips every staged unit `staged → migrated` — the explicit "this batch is live
in Spacelift now" transition. It's what lets the pipeline be iterative and
additive: once a batch is `migrated`, the next `discover` preserves it,
`generate` keeps its files (and **never regenerates them** — they're the
customer's now), and `batch list` shows it as done.

```text
Status  migrated

Migrated (8)
  ┌─────────┬─────────────────────────┬──────────────────────────────┐
  │ Kind    │ Id                      │ Name                         │
  ├─────────┼─────────────────────────┼──────────────────────────────┤
  │ context │ varset-8NK3XU2nTY7qVmwR │ Apollorion-test-variable-set │
  │ module  │ mod-AJu96tYoVyzKPEjw    │ module                       │
  │ space   │ Apollorion              │ Apollorion                   │
  │ space   │ prj-CZQPUuzATP7Evo7G    │ Default Project              │
  │ space   │ prj-SVGtTCkFUripuBzK    │ Apollorion-Project           │
  │ stack   │ ws-7YopKPAktoDmhFXW     │ with-var-set                 │
  │ stack   │ ws-RjHgP1J9E5vrpwSP     │ terraform-1-8-5-test         │
  │ stack   │ ws-gGvHKjJkkG6dQhxE     │ terraform                    │
  └─────────┴─────────────────────────┴──────────────────────────────┘
```

The database — not git — is the authority on what's migrated. After this, you're
back at the top: run [`liftoff discover`](discover.md) to refresh the picture and
[`liftoff batch`](batch.md) to stage the next batch. Repeat until the estate is
migrated.

## The other finalize steps

`finalize sensitive` pushes the sensitive values `mutate` captured into the live
Spacelift stacks and contexts as write-only environment variables and mounted
files — the one moment those values leave the local store, and unreadable once
set. It resolves each target by the Spacelift id derived from its name — the same
derivation Spacelift itself performs when the entity is created (lowercased,
transliterated to ASCII, spaces and punctuation collapsed to dashes) — so it
needs the stacks already standing in
Spacelift (the deploy step) and the
Spacelift destination credentials in your config:

```bash
liftoff configure \
  --set spacelift.endpoint=https://<account>.app.spacelift.io \
  --set spacelift.api_key_id='${SPACELIFT_KEY_ID}' \
  --set spacelift.api_key_secret='${SPACELIFT_KEY_SECRET}'
liftoff finalize sensitive
```

Variable-set (context) secrets can't be captured, so those are reported as
skipped rather than pushed — set them in Spacelift directly.

`finalize state` pushes each staged stack's Terraform state — captured locally by
`mutate --allow-mutation state` at cutover — into its live Spacelift stack: the
raw state is uploaded to
Spacelift storage, then imported onto the stack (briefly locked for the import,
as Spacelift requires), addressed by the same name-derived id. Stacks never
applied at the source have no state and are skipped. It needs the same Spacelift
credentials as above:

```bash
liftoff finalize state
```

`finalize modules` backfills each staged module's **published versions** into
Spacelift — Spacelift won't recreate a module's version history on its own. It's
a pure push from the local store: for each version whose commit SHA was resolved
earlier by [`liftoff mutate --allow-mutation module-git-versions`](mutate.md), it
calls Spacelift's `versionCreate` at that commit. Like `finalize sensitive` and
`finalize state`, it never reaches the VCS itself — that resolution happened in
`mutate` — so it needs only the Spacelift credentials:

```bash
liftoff finalize modules
```

```text
Created 5
Skipped 1

Notes
  1 version(s) had no resolved commit SHA — run `liftoff mutate --allow-mutation module-git-versions`, or see `liftoff audit` for the unmigratable ones
```

A version is `Skipped` when its commit SHA was never resolved — either you
haven't run the `module-git-versions` mutation yet, or the SHA couldn't be
recovered (the module has no VCS connection, or its tag no longer resolves).
The unrecoverable ones are surfaced by [`liftoff audit`](audit.md) as
`module-version-unmigratable`; create those in Spacelift by hand, pointing each
at its tag's commit.

`finalize staged` above is the lifecycle transition.
