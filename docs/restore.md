# Restore

The contingency command of [the migration walkthrough](README.md): put the source back if a [`mutate`](mutate.md) run was interrupted before it finished reverting.
Every mutation reverts inline, including the ones belonging to a unit that failed, so most migrations never run this.

## When it matters

A mutate run (`liftoff mutate --allow-mutation <name>`) records a restore point before each change it makes to the source, and reverts everything before it finishes.
If such a run is killed partway — network drop, Ctrl-C, a crash — the un-reverted changes remain, and the next `liftoff mutate` refuses to start:

```text
✗ Pending Restore Points  the source has 1 pending restore point(s) from an earlier mutating run that did not finish reverting

Remediation
  run `liftoff restore` to put the source back, then re-run mutate
```

Mutations never stack: nothing else runs against the source until it is back to its original state.

## Preview, then confirm

```bash
liftoff restore
```

Read-only: lists every pending restore point and what reverting it will do, newest first.
Nothing pending reports exactly that.
To perform the reverts:

```bash
liftoff restore --confirm
```

This is source-mutating — it dispatches each pending restore point back to its capability's revert, most recent first, and clears the point once the source confirms.
A revert that fails is reported and kept for a retry; the rest still proceed.
When some fail, `restore` names every point it reverted and every one still pending, with the reason each failed, and exits non-zero: the source is not back to its original state until nothing is pending.

<!-- liftoff:skill terraform -->
Restoring a `secrets` capture returns each workspace to its original execution mode and agent pool, then deletes the temporary agent pool.

Restoring a `context-secrets` capture removes any remaining variable-set attachments, deletes the temporary workspaces, and deletes the temporary agent pool.
Liftoff restores the newest change first, so it removes attachments before deleting the workspaces they reference.

Secret capture makes no other changes to Terraform Cloud or Terraform Enterprise.
<!-- liftoff:skill /terraform -->

Once nothing is pending, re-run `liftoff mutate` and continue where you were.
