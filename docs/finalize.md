# Finalize

Step 11 of [the migration walkthrough](start.md): close out a batch — push in
what couldn't travel as code (secrets, state, module versions), then mark the
batch migrated so the next batch starts clean.

**Run the pushers before `finalize staged`.** `finalize sensitive`,
`finalize state`, and `finalize modules` act on **staged units only**, and
`finalize staged` is the transition that flips the batch *out of* staged. Flip
first and the pushers find nothing to move — the stacks come up marked migrated
holding no secrets and no state. So the order is: the pushers
([below](#the-other-finalize-steps)), then `finalize staged` last.

## The last step — finalize the batch

```bash
liftoff finalize staged
```

Run this **after** the pushers below. It flips every staged unit
`staged → migrated` — the explicit "this batch is live in Spacelift now"
transition. It's what lets the pipeline be iterative and additive: once a batch
is `migrated`, the next `discover` preserves it, `generate` keeps its files (and
**never regenerates them** — they're the customer's now), and `batch list` shows
it as done.

Because flipping the batch out of staged is what strands unpushed secrets and
state, `finalize staged` **refuses** until every captured secret and state in the
batch has been pushed. There is no override — pushing the data is the only way
through, so the batch cannot be marked done while anything is still stranded. Run
the pushers first (below); once each captured value has been pushed, `finalize
staged` proceeds.

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

Any sensitive value still empty in the store is reported as skipped rather than pushed — set those in Spacelift directly.
Variable-set (context) secrets need `mutate --allow-mutation context-secrets` to have run; without it they arrive empty and are skipped here.
Every skip is **named**: the report lists each skipped value (kind, id, name) and why it was skipped, so "N skipped" is never a number you have to bisect.

`finalize state` pushes each staged stack's Terraform state — captured locally by
`mutate --allow-mutation state` at cutover — into its live Spacelift stack: the
raw state is uploaded to
Spacelift storage, then imported onto the stack (briefly locked for the import,
as Spacelift requires), addressed by the same name-derived id. Stacks never
applied at the source have no state and are skipped — each named in the report,
with why. It needs the same Spacelift credentials as above:

```bash
liftoff finalize state
```

```text
Pushed  4

Skips (2)
  ┌───────┬─────────────────────┬────────────────┬─────────────────────────────────────────────────────────────────────┐
  │ Kind  │ Id                  │ Name           │ Reason                                                                │
  ├───────┼─────────────────────┼────────────────┼─────────────────────────────────────────────────────────────────────┤
  │ stack │ ws-7YopKPAktoDmhFXW │ legacy-network │ no captured state — never applied at the source, or `liftoff mutate   │
  │       │                     │                │ --allow-mutation state` has not run                                   │
  │ stack │ ws-RjHgP1J9E5vrpwSP │ sandbox        │ no captured state — never applied at the source, or `liftoff mutate   │
  │       │                     │                │ --allow-mutation state` has not run                                   │
  └───────┴─────────────────────┴────────────────┴─────────────────────────────────────────────────────────────────────┘

Notes (1)
  - 2 staged stack(s) had no captured state — never applied at the source, or `liftoff mutate --allow-mutation state`
    has not run (a source that captures no state never will)
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

## Dispose of the workspace when you're done

When the last batch is migrated and the estate is fully on Spacelift, one thing
is left: the `./.liftoff/` workspace. By now it is the most sensitive artifact
the migration produced, all of it **unencrypted on your disk**:

- **`config.yaml`** — the source and Spacelift settings, including any API token
  pasted in rather than kept as an environment reference.
- **`liftoff.db`** — the SQLite store. It holds every captured **sensitive
  variable value** (from `mutate --allow-mutation secrets` / `context-secrets`)
  and every captured **Terraform state blob** (from `mutate --allow-mutation
  state`) — the same production secrets and state your `finalize` steps just
  pushed into Spacelift, now sitting in a plain file with no password on it.
- **`data/generated/`** — the rendered OpenTofu. Not secret (secrets are never
  inlined), but it describes your whole estate.

Nothing about the kit protects this for you: it isn't encrypted, and the
`.gitignore` line from [setup](setup.md#step-1--initialize-the-workspace) only
keeps it out of git — not off backups, cloud sync, or a machine someone else can
reach. So while a migration is in flight, keep the directory somewhere only you
can read; once it's finished and everything is verified in Spacelift, **delete
it**:

```bash
rm -rf .liftoff
```

There is nothing to keep — Spacelift is now the system of record, and re-running
the kit from scratch would rebuild the workspace anyway. If your platform has a
secure-erase tool, prefer it, since the file held live secrets and state. Never
hand this directory to anyone as-is for support or sharing: it carries live
production secrets and state.
