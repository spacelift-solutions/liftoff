<!-- comprehension: mutate -->
# Mutate

Step 10 of [the migration walkthrough](start.md): run the steps that reach the
source for something other than reading its estate. Each is a **capability the
configured source declares**, each is opt-in, and nothing runs unless you name
it — so this step runs late, only for the batch you've committed to.

Run `liftoff sources` to see what the configured source offers.
Terraform Cloud/Enterprise declares four: `secrets`, `context-secrets`, `state`, and `module-git-versions`.

## Step 10 — capture the staged batch's secrets and state

```bash
liftoff mutate --allow-mutation secrets --allow-mutation context-secrets --allow-mutation state
```

The source masks sensitive values, so discover left them empty.
`mutate` recovers them for the **staged batch only**, and the two kinds of secret are separate opt-ins because they change different amounts at the source.

**`secrets`** covers values set on a workspace: it reads the batch back from the local store, briefly registers a temporary agent, flips each staged workspace to it to read the plaintext values, fills them into the store, and **restores every workspace before finishing**.

**`context-secrets`** covers values set on a variable set, which no real workspace can be trusted to reveal — a workspace variable of the same name takes precedence, so a value read there might not be the set's.
Instead it creates **one throwaway workspace per organization** with no variables of its own, attaches each staged variable set to it in turn, reads the plaintext, then detaches and deletes the workspace.
Your real workspaces are never touched, and a variable set never loses an attachment it already had.
A variable set that applies organization-wide is never attached at all, since it already applies.

Captured values live only in the local store — never logged, never printed (it reports counts, never values).

```text
Source  terraform

Sensitive Values
  Sensitive Variables  22
  Captured             9
  Empty                13

  Notes (1)
    - 13 sensitive stack variable value(s) are empty — stage the stacks, then run `liftoff mutate` with a capability
      that captures them (`liftoff sources` lists what this source declares), or set them in Spacelift after the
      migration

Capabilities
  context-secrets
    Captured  3

Next
  $ liftoff finalize sensitive
  $ liftoff finalize state
  $ liftoff finalize staged
```

**Run the finalize pushers before `finalize staged`, in that order.** The pushers
(`finalize sensitive`, `finalize state`) act on **staged units only**, and
`finalize staged` is the transition that flips the batch *out of* staged (to
migrated). Flip first and the pushers find nothing to push — the stacks come up
marked migrated but holding no secrets and no state, with no error to tell you.
So push, then flip: `finalize staged` refuses until every captured secret and
state in the batch has been pushed — pushing them is the only way through.
(`finalize modules` belongs to the same before-`staged` window when you captured
module versions — see below.)

`Captured` is what this run filled for the staged batch; the counts that remain `Empty` are for units you haven't staged — stage them and re-run to capture those too.

A value can also stay empty when it cannot be attributed to one owner.
If an organization-wide variable set and a staged one both define the same name, only one value reaches the run, so the kit reports the collision and leaves that variable empty rather than risk storing the wrong secret.
Set those in Spacelift directly.

A few things worth knowing:

- **The opt-in is per run.** With no `--allow-mutation`, `mutate` does nothing and
  says so — absence is the safe path, never a prompt. It is a flag, not a setting:
  there is no config key that grants it, so consent belongs to the run in front of
  you rather than to whoever last edited `config.yaml`.
- **`state` is opt-in too, though it changes nothing at the source.** It reaches
  the source and pulls each staged stack's whole state blob — your infrastructure
  data — so it asks first. `liftoff finalize state` has nothing to push without it.
- **Every mutation is reverted, and reconcilable.** Each flip is backed up before
  it happens, so a crash mid-run is recoverable: `mutate` refuses to start while
  restore points are pending and points you at [`liftoff restore`](restore.md),
  which puts the source back exactly as it was. Nothing stacks, nothing is left
  half-flipped.
- **Run it after the stacks exist.** The generated code carries secret
  *references* and no state, so the Spacelift stacks stand up from discover's
  read-only data alone ([deploy](deploy.md)); `mutate` and the finalize pushers
  configure them afterward.

## Resolving module versions' commit SHAs

`mutate` is also where module version history is recovered, under a second
opt-in capability:

```bash
liftoff configure --set vcs.token='${VCS_TOKEN}'
liftoff mutate --allow-mutation module-git-versions
```

`discover` records each private module's published version numbers and tags, but
the source never exposes the git commit each version was published from. This
capability fills that gap: for the **staged modules**, it asks each module's VCS
provider directly over the git protocol (one authenticated request per
repository — no clone, no `git` binary) to resolve every tag to its commit SHA,
and stores the SHA alongside the version. [`finalize modules`](finalize.md) then
pushes those from the store.

```text
Source  terraform

Module Git Versions
  Resolved  5

  Unrecoverable (1)
    ┌────────────────┬─────────┬───────────────────────────────────────────────┐
    │ Module         │ Version │ Reason                                        │
    ├────────────────┼─────────┼───────────────────────────────────────────────┤
    │ legacy-network │ 0.3.0   │ no tag matching 0.3.0 found in the repository │
    └────────────────┴─────────┴───────────────────────────────────────────────┘
```

Unlike `secrets`, this **doesn't touch the source** — it reads from the VCS — so
it takes no restore point and needs no revert. It's additive: the rest of
`mutate` runs as it always does, so the run also reports whatever it captured for
the staged batch. It needs a `vcs.token` (a PAT with
read access to the module repositories); `liftoff` picks the right git username
per provider, and `vcs.host` covers self-hosted providers (GitHub Enterprise, a
self-managed GitLab, Bitbucket Data Center). Versions whose module has no VCS
connection, or whose tag no longer resolves, are reported here and surfaced by
[`liftoff audit`](audit.md) — never silently dropped.

Pushing the captured values into the live Spacelift stacks is a separate
finalize step (see [finalize](finalize.md)).
