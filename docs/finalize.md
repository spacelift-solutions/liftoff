# Finalize

Step 11 of [the migration walkthrough](README.md): close out a batch — push in what couldn't travel as code (secrets, state, module versions), then mark the batch migrated so the next batch starts clean.
Non-sensitive variables never pass through here: [`generate`](generate.md) emits each one as a `spacelift_environment_variable` in its entity's file, readable in Spacelift rather than write-only, so only what can't be expressed as HCL is left to push.

**Run the pushers before `finalize staged`.**
`finalize sensitive`, `finalize state`, and `finalize modules` act on **staged units only**, and `finalize staged` is the transition that flips the batch _out of_ staged.
Flip first and the pushers find nothing to move — the stacks come up marked migrated holding no secrets and no state.
So the order is: the pushers ([below](#the-other-finalize-steps)), then `finalize staged` last.

## The last step — finalize the batch

```bash
liftoff finalize staged
```

Run this **after** the pushers below.
It flips every staged unit `staged → migrated` — the explicit "this batch is live in Spacelift now" transition, and the batch-closing one: it declares the batch done.
It's what lets the pipeline be iterative and additive: once a batch is `migrated`, the next `discover` preserves it, `generate` keeps its files (and **never regenerates them** — they're the customer's now), and `batch list` shows it as done.

**Treat this as a one-way door.** Once it flips, for that batch:

- `generate` stops rewriting its entity files (they're yours to hand-edit — see [generate](generate.md#additive-across-batches-migrated-files-are-yours)),
- the batch drops out of the staged set, so it no longer appears in `batch list` as stageable, and
- the pushers (`finalize sensitive`, `finalize state`, `finalize modules`) no longer act on it — they touch staged units only.

That last point is why the ordering above is not optional: run every pusher you need **first**, because after `finalize staged` there is no pusher left that will move this batch's secrets, state, or module versions. Re-staging a migrated unit is possible but takes a person's explicit agreement and names the full blast radius (see [batch](batch.md)); it is the deliberate exception, not the undo button.

Because flipping the batch out of staged is what strands unpushed secrets and state, `finalize staged` **refuses** until every captured secret and state in the batch has been pushed.
There is no override — pushing the data is the only way through, so the batch cannot be marked done while anything is still stranded.
Run the pushers first (below); once each captured value has been pushed, `finalize staged` proceeds.

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

The database — not git — is the authority on what's migrated.
After this, you're back at the top: run [`liftoff discover`](discover.md) to refresh the picture and [`liftoff batch`](batch.md) to stage the next batch.
Repeat until the estate is migrated.

## The other finalize steps

`finalize sensitive` pushes the sensitive values `mutate` captured into the live Spacelift stacks and contexts as write-only environment variables and mounted files — the one moment those values leave the local store, and unreadable once set.
It resolves each target by the Spacelift id derived from its name — the same derivation Spacelift itself performs when the entity is created (lowercased, transliterated to ASCII, spaces and punctuation collapsed to dashes) — so it needs the stacks already standing in Spacelift (the publish step) and the Spacelift destination credentials in your config:

```bash
liftoff configure \
  --set spacelift.endpoint=https://<account>.app.spacelift.io \
  --set spacelift.api_key_id='${SPACELIFT_KEY_ID}' \
  --set spacelift.api_key_secret='${SPACELIFT_KEY_SECRET}'
liftoff finalize sensitive
```

Some of those sensitive values arrive as **mounted files** rather than variables: a Spacelift variable value is single-line, so a captured value carrying a newline is translated into a mounted file on its stack or context plus export hooks on that owner (see [mutate](mutate.md#when-a-captured-value-turns-out-to-be-multi-line)).
`finalize sensitive` pushes the file the same way it pushes a secret — write-only, unreadable once set — but pushing the file is only half of it: **the export hooks have to already be live**, which means the `liftoff generate` and `liftoff publish` lap that `mutate` asks for must have happened first.
Push the file without the hooks and nothing reads it back, so the run finds no such variable.

Any sensitive value still empty in the store is reported as skipped rather than pushed — set those in Spacelift directly.
Variable-set (context) secrets need `mutate --allow-mutation context-secrets` to have run; without it they arrive empty and are skipped here.
Every skip is **named**: the report lists each skipped value (kind, id, name) and why it was skipped, so "N skipped" is never a number you have to bisect.
When captured state is still unpushed, `Next` names `liftoff finalize state` — not `finalize staged` — so the ordering the page warns about is also what the hint says.

`finalize state` pushes each staged stack's Terraform state — captured locally by `mutate --allow-mutation state` at cutover — into its live Spacelift stack: the raw state is uploaded to Spacelift storage, then imported onto the stack (briefly locked for the import, as Spacelift requires), addressed by the same name-derived id.
A skipped stack is named with why, and the two reasons are kept apart: a stack **recorded unresolvable** (say, one the source holds no state for) is nothing to push — its skip carries the recorded reason, not a gap, and [`liftoff status`](README.md#commands-that-work-at-any-point) doesn't count it as one — while a stack whose state is simply **not captured yet** names the `mutate` run that fixes it.
The notes repeat each skipped stack with its source URL, so you can open the ones missing state without reading the skip table.

A stack whose push **fails** — Spacelift refuses it, or the connection drops mid-import — costs only itself.
It is recorded under `failures` with the reason, what to do about it, and its source URL, and the run carries on to the next stack, so one bad moment on a big batch does not strand every stack behind it.
The notes repeat each failure the same way they repeat each skip.
Deal with what they name and run `liftoff finalize state` again: it retries the failures, and re-importing a state that already landed is harmless.
Only a failure that would hit every remaining stack the same way — credentials refused, a broken workspace — stops the run early, and the notes then say how many stacks were never attempted.

The import briefly locks the stack, and both the lock and the unlock are retried when the connection drops, because a stack left locked is one nobody can run.
If the retries are exhausted the failure says so — unlock that stack in Spacelift before its first run.
A lock Spacelift _refuses_ is not retried: something is already holding it, and that needs a person.
Progress goes to stderr — add `-v` to watch each stack go by, and `-vv` for each upload and import.

Stacks are pushed **five at a time** by default rather than one after another, which is what keeps a large batch moving at the last step of a cut-over.
The width is `spacelift.push_concurrency`, any whole number from 1 to 50:

```bash
liftoff configure --set spacelift.push_concurrency=10
```

Raising it finishes sooner and costs two things — a captured state is megabytes, and that many are held in memory at once, so peak memory scales with the width; and the account sees that many imports at a time, which a busy one may rate-limit (if pushes start failing with a rate-limit message, lower it).
Setting it to `1` restores the strictly sequential run.
Whatever the width, the report reads in the same order every time — the batch's order, not whichever stack happened to finish first.

It needs the same Spacelift credentials as above:

```bash
liftoff finalize state
```

```text
Pushed  1

Skips (2)
  ┌───────┬───────────┬─────────────┬──────────────┬───────────────────────────────────────────────────────────────────┐
  │ Kind  │ ID        │ Name        │ Reason       │ URL                                                               │
  ├───────┼───────────┼─────────────┼──────────────┼───────────────────────────────────────────────────────────────────┤
  │ stack │ ws-api    │ api-service │ the          │ http://tfe.localhost:18091/app/liftoff-e2e/workspaces/api-service │
  │       │           │             │ workspace    │                                                                   │
  │       │           │             │ has never    │                                                                   │
  │       │           │             │ been         │                                                                   │
  │       │           │             │ applied, so  │                                                                   │
  │       │           │             │ the source   │                                                                   │
  │       │           │             │ holds no     │                                                                   │
  │       │           │             │ state to     │                                                                   │
  │       │           │             │ capture —    │                                                                   │
  │       │           │             │ nothing to   │                                                                   │
  │       │           │             │ push, not a  │                                                                   │
  │       │           │             │ gap          │                                                                   │
  │ stack │ ws-legacy │ legacy      │ the          │ http://tfe.localhost:18091/app/liftoff-e2e/workspaces/legacy      │
  │       │           │             │ workspace    │                                                                   │
  │       │           │             │ has never    │                                                                   │
  │       │           │             │ been         │                                                                   │
  │       │           │             │ applied, so  │                                                                   │
  │       │           │             │ the source   │                                                                   │
  │       │           │             │ holds no     │                                                                   │
  │       │           │             │ state to     │                                                                   │
  │       │           │             │ capture —    │                                                                   │
  │       │           │             │ nothing to   │                                                                   │
  │       │           │             │ push, not a  │                                                                   │
  │       │           │             │ gap          │                                                                   │
  └───────┴───────────┴─────────────┴──────────────┴───────────────────────────────────────────────────────────────────┘

Notes (3)
  - 2 staged stack(s) are recorded unresolvable — nothing to push for them, not a gap
  - api-service (ws-api) — http://tfe.localhost:18091/app/liftoff-e2e/workspaces/api-service
  - legacy (ws-legacy) — http://tfe.localhost:18091/app/liftoff-e2e/workspaces/legacy

Next
  $ liftoff finalize staged
```

`finalize modules` backfills each staged module's **published versions** into Spacelift — Spacelift won't recreate a module's version history on its own.
It's a pure push from the local store: for each version whose commit SHA was resolved earlier by [`liftoff mutate --allow-mutation module-git-versions`](mutate.md), it calls Spacelift's `versionCreate` at that commit.
Like `finalize sensitive` and `finalize state`, it never reaches the VCS itself — that resolution happened in `mutate` — so it needs only the Spacelift credentials:

```bash
liftoff finalize modules
```

```text
Created  1
Skipped  0

Next
  $ liftoff finalize staged
```

A version is `Skipped` when its commit SHA was never resolved, and the report keeps the two cases apart: a version the mutation **recorded as unresolvable** (the module has no VCS connection, or its tag no longer resolves) is counted under `Unresolvable` — an explained dead end, not work outstanding — while the rest simply haven't been resolved yet, and the note names the `module-git-versions` run that fixes them.
`liftoff model list --kind module_version` shows each recorded reason, and [`liftoff status`](README.md#commands-that-work-at-any-point) counts the unresolvable ones apart from a real shortfall.
The unrecoverable ones are also surfaced by [`liftoff audit`](audit.md) as `module-version-unmigratable`; create those in Spacelift by hand, pointing each at its tag's commit.

`finalize staged` above is the lifecycle transition.

## What comes after

After state lands, the migration is complete: Spacelift runs plans against the same state the source last held, and the source can be retired on your schedule.
Migration is lift-and-shift by design: everything lands where it lived at the source.
The phase that follows is adoption: organizing spaces around how your teams actually work, tightening policies, and adopting Spacelift-native workflows.
The `liftoff space` command group (create, move, reshape; a move relocates a stack's file into the target space's directory and emits a `moved` block, so the admin stack re-parents it in place) is the tooling for that phase, and its shape is still being worked out with early users.
Expect this page to grow.

## Dispose of the workspace when you're done

When the last batch is migrated and the estate is fully on Spacelift, one thing is left: the `./.liftoff/` workspace.
By now it is the most sensitive artifact the migration produced, all of it **unencrypted on your disk**:

- **`config.yaml`** — the source and Spacelift settings, including any API token pasted in rather than kept as an environment reference.
- **`liftoff.db`** — the SQLite store.
  It holds every captured **sensitive variable value** (from `mutate --allow-mutation secrets` / `context-secrets`) and every captured **Terraform state blob** (from `mutate --allow-mutation state`) — the same production secrets and state your `finalize` steps just pushed into Spacelift, now sitting in a plain file with no password on it.
- **`data/generated/`** — the rendered OpenTofu.
  Not secret (secrets are never inlined), but it describes your whole estate.

Nothing about the kit protects this for you: it isn't encrypted, and the `.gitignore` line from [setup](setup.md#step-1--initialize-the-workspace) only keeps it out of git — not off backups, cloud sync, or a machine someone else can reach.
So while a migration is in flight, keep the directory somewhere only you can read; once it's finished and everything is verified in Spacelift, **delete it**:

```bash
rm -rf .liftoff
```

There is nothing to keep — Spacelift is now the system of record, and re-running the kit from scratch would rebuild the workspace anyway.
If your platform has a secure-erase tool, prefer it, since the file held live secrets and state.
Never hand this directory to anyone as-is for support or sharing: it carries live production secrets and state.
