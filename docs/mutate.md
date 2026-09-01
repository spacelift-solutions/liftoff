<!-- comprehension: mutate -->
# Mutate

Step 10 of [the migration walkthrough](README.md): run the steps that reach the source for something other than reading its estate.
Each is a **capability the configured source declares**, each is opt-in, and nothing runs unless you name it — so this step runs late, only for the batch you've committed to.

Run `liftoff sources` to see what the configured source offers.

<!-- liftoff:skill terraform -->
Terraform Cloud and Terraform Enterprise declare four capabilities: `secrets`, `context-secrets`, `state`, and `module-git-versions`.

A typical capture runs its three data-recovery capabilities together:

```bash
liftoff mutate --allow-mutation secrets,context-secrets,state
```
<!-- liftoff:skill /terraform -->

## Step 10 — run capabilities for the staged batch

```bash
liftoff mutate --allow-mutation <name>
```

`--allow-mutation` accepts a comma-separated list or repeated flags, so name every capability this run should use.

When discover reports empty sensitive values, use the capture capabilities the configured source declares.
They act on the **staged batch only**.

<!-- liftoff:skill terraform -->
Terraform Cloud and Terraform Enterprise hide sensitive values on workspace variables and variable-set variables.
Liftoff captures these two kinds of values separately.

`--allow-mutation secrets` captures values from staged workspaces.
Liftoff temporarily switches each workspace to agent execution mode, reads the values through the agent protocol, and restores the original settings.

`--allow-mutation context-secrets` captures values from staged variable sets.
A normal workspace run cannot identify these values reliably because a workspace variable with the same name takes precedence.
Liftoff instead creates temporary workspaces with no variables of their own.
It attaches each variable set, captures the values, then removes the attachment and deletes the temporary workspace.
Global variable sets already apply to the temporary workspace and do not need to be attached.

Capture time grows with the number of staged workspaces and variable sets that contain sensitive values.
If a variable set and a global variable set define the same name, Liftoff leaves the value empty rather than risk capturing the wrong one.

Multiline sensitive values are converted to mounted files when they are captured.
Liftoff also adds hooks to the owning stack or context so the file contents are exported under the original variable name.
Run `liftoff generate` and `liftoff publish` again before `liftoff finalize sensitive`.
Otherwise, the file is uploaded without the hooks that expose it to runs.
<!-- liftoff:skill /terraform -->

Captured values live only in the local store — never logged, never printed (it reports counts, never values).

<!-- liftoff:skill terraform -->
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
<!-- liftoff:skill /terraform -->

**Run the finalize pushers before `finalize staged`, in that order.**
The pushers (`finalize sensitive`, `finalize state`) act on **staged units only**, and `finalize staged` is the transition that flips the batch _out of_ staged (to migrated).
Flip first and the pushers find nothing to push — the stacks come up marked migrated but holding no secrets and no state, with no error to tell you.
So push, then flip: `finalize staged` refuses until every captured secret and state in the batch has been pushed — pushing them is the only way through.
(`finalize modules` belongs to the same before-`staged` window when you captured module versions — see below.)

`Captured` is what this run filled for the staged batch; the counts that remain `Empty` are for units you haven't staged — stage them and re-run to capture those too.

<!-- liftoff:skill terraform -->
A value can also stay empty when it cannot be attributed to one owner.
If an organization-wide variable set and a staged one both define the same name, only one value reaches the run, so the kit reports the collision and leaves that variable empty rather than risk storing the wrong secret.
Set those in Spacelift directly.
<!-- liftoff:skill /terraform -->

## When some units can't be captured

`mutate` captures everything it can and reports the rest.
One entity the source refuses does not end the run: the units after it are still captured, and each failure comes back naming what it was and why.

<!-- liftoff:skill terraform -->
This capture shows failures from the Terraform source.

```text
Source  terraform

Capabilities
  Context-secrets
    Captured  41
    Skipped   2

Failures (2)
  ┌─────────────────┬─────────────────────────┬────────────────────┬───────────────────────────────────────────────────┐
  │ Capability      │ Entity                  │ Code               │ Reason                                            │
  ├─────────────────┼─────────────────────────┼────────────────────┼───────────────────────────────────────────────────┤
  │ context-secrets │ varset-2MRjRdWjyy6b6Y3p │ source_rejected    │ Terraform API returned HTTP 422: invalid          │
  │                 │                         │                    │ attribute: Workspace(s) [ws-KgRB9nEvqiUxY8RZ] not │
  │                 │                         │                    │ found                                             │
  │ secrets         │ ws-7QpLm4XbHt2c9Y1a     │ extraction_timeout │ no agent job arrived for workspace ws-            │
  │                 │                         │                    │ 7QpLm4XbHt2c9Y1a                                  │
  └─────────────────┴─────────────────────────┴────────────────────┴───────────────────────────────────────────────────┘
```
<!-- liftoff:skill /terraform -->

`Captured` plus `Skipped` always accounts for everything the staged batch put in scope, and `Failures` names the units that need another go.
Re-run the same `mutate` command to retry just those; what was already captured is not captured twice.
A retry needs a fresh approval, because an approval is spent by the run it was given to.

The run stops early only when a failure would hit every remaining unit anyway: a rejected credential, a source that cannot be reached, a cancelled run, or a backup that could not be written.
The last of those is deliberate: nothing is changed at the source without a recorded way back.

Because a partial run is still a run that did work, `mutate` reports it as a result rather than an error.
Read `failures` to decide what is left, not the exit code.

A few things worth knowing:

- **The opt-in is per run.**
  With no `--allow-mutation`, `mutate` does nothing and says so — absence is the safe path, never a prompt.
  It is a flag, not a setting: there is no config key that grants it, so consent belongs to the run in front of you rather than to whoever last edited `config.yaml`.
<!-- liftoff:skill terraform -->
- **`state` is opt-in too, though it changes nothing at the source.**
  It reaches the source and pulls each staged stack's whole state blob — your infrastructure data — so it asks first.
  `liftoff finalize state` has nothing to push without it.
  Each staged stack is re-checked at the source as it is captured, not trusted from `discover`'s snapshot: a stack applied after `discover` is captured all the same, and one with no state at the source is recorded as such — so run it at cutover and the store reflects the source as it is, not as it was.
  A workspace the source holds no state for is **named in the notes**, with its source URL: the report lists each one so you can open it, and you do not have to rerun the capture to find out which.

```text
Capabilities
  State
    Captured  10
    Skipped   2

    Notes (3)
      - 2 staged workspace(s) have never been applied, so the source holds no state to capture
      - never-applied (ws-legacy) — https://app.terraform.io/app/acme/workspaces/never-applied
      - sandbox (ws-sandbox) — https://app.terraform.io/app/acme/workspaces/sandbox
```
<!-- liftoff:skill /terraform -->

- **Every mutation is reverted, and reconcilable.**
  Each flip is backed up before it happens, so a crash mid-run is recoverable: `mutate` refuses to start while restore points are pending and points you at [`liftoff restore`](restore.md), which puts the source back exactly as it was.
  Nothing stacks, nothing is left half-flipped.
- **Run it after the stacks exist.**
  The generated code carries secret _references_ and no state, so the Spacelift stacks stand up from discover's read-only data alone ([publish](publish.md)); `mutate` and the finalize pushers configure them afterward.

## When a captured value turns out to be multi-line

A Spacelift variable value is single-line, so no value carrying a newline is ever stored as a variable.
The kit translates it instead: the value becomes a **mounted file** at `liftoff/<owner-id>/<NAME>` under `/mnt/workspace/` on its owning stack or context, and that owner gets `export <NAME>="$(cat /mnt/workspace/liftoff/<owner-id>/<NAME>)"` in **both** its `before_init` and `before_apply` hooks (both, because the phases up to apply share init's container while apply may get a fresh one).
Inside the run it is an ordinary environment variable of the same name — it just isn't a Spacelift variable, and it is never also created as one. It is one or the other.

[`discover`](discover.md) already does this for values the source hands over in the clear.
When a capability captures a **sensitive** value, `mutate` does the same translation; any newlines only surface once the plaintext reaches the local store.
A captured multi-line value becomes a **sensitive** mounted file — the content stays in the local store, never written into generated code, and [`liftoff finalize sensitive`](finalize.md) is what pushes it.

**A mounted capture costs one extra lap through generate and publish.**
Hooks are stack and context arguments, so they live in the generated OpenTofu — but `mutate` is step 10, after [`generate`](generate.md) (step 8) and [`publish`](publish.md) (step 9).
The moment `mutate` mounts a captured value, the module the admin stack already applied is stale: it carries no export hooks for that file.
So re-run `liftoff generate` and `liftoff publish` to get the hooks into Spacelift, then `liftoff finalize sensitive` to push the file contents.
`mutate` says so in its report notes whenever it happens, and counts the values it mounted.

Skip that lap and the failure is a quiet one: the file lands in Spacelift, nothing exports it, and the run sees no such variable.

<!-- liftoff:skill terraform -->
## Terraform Cloud / Enterprise: resolving module versions' commit SHAs

`mutate` is also where module version history is recovered, under a second opt-in capability:

```bash
liftoff configure --set vcs.token='${VCS_TOKEN}'
liftoff mutate --allow-mutation module-git-versions
```

`discover` records each private module's published version numbers and tags, but the source never exposes the git commit each version was published from.
This capability fills that gap: for the **staged modules**, it asks each module's VCS provider directly over the git protocol (one authenticated request per repository — no clone, no `git` binary) to resolve every tag to its commit SHA, and stores the SHA alongside the version.
[`finalize modules`](finalize.md) then pushes those from the store.

```text
Source  terraform

Module Git Versions
  Resolved  5

  Unrecoverable (1)
      Module   spacelift-stack
      Version  0.3.0
      Reason   no tag matching 0.3.0 among the 7 tag(s) at https://github.com/Apollorion/spacelift-stack.git
      URL      https://app.terraform.io/app/Apollorion/registry/modules/private/Apollorion/spacelift-stack/terraform
```

Unlike `secrets`, this **doesn't touch the source** — it reads from the VCS — so it takes no restore point and needs no revert.
It's additive: the rest of `mutate` runs as it always does, so the run also reports whatever it captured for the staged batch.
It needs a `vcs.token` (a PAT with read access to the module repositories); `liftoff` picks the right git username per provider.

The host usually needs no configuration: it comes from the module's own repository address, and is used only once one of your Spacelift VCS integrations reaches that same host — the token is never sent to a host only the source vouches for.
Set `vcs.host` when there is no such match, or to override the choice: a self-hosted instance whose repository addresses name a hostname you don't reach it on is the usual reason.

Azure DevOps needs one thing more, because it addresses a repository as `<organization>/<project>/_git/<repository>` and the source records only the project and the name.
The organization is read from the repository's own address, which is enough for almost every module; when a module carries none, set it on the host:

```bash
liftoff configure --set vcs.host=dev.azure.com/<organization>
```

An Azure DevOps Server collection goes in the same place — `vcs.host=ado.example.com/tfs/DefaultCollection` — and the legacy `<organization>.visualstudio.com` addresses need nothing, since they carry the organization in the hostname.

Versions whose module has no VCS connection, or whose tag no longer resolves, are reported here and surfaced by [`liftoff audit`](audit.md) — never silently dropped.
A reason names the address that was read and how many tags it held, so "the tag is gone" stays distinguishable from "that address is not the repository".
Each dead end is also **recorded on the version itself**, so [`liftoff status`](README.md#commands-that-work-at-any-point) counts it apart from a version not yet resolved and `liftoff model list --kind module_version` shows the reason; a later run that does resolve the tag clears the record.
<!-- liftoff:skill /terraform -->

Pushing the captured values into the live Spacelift stacks is a separate finalize step (see [finalize](finalize.md)).
