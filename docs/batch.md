# Batch

Step 6 of [the migration walkthrough](start.md): choose which units migrate in this batch.
Migrations are iterative — you don't move the whole estate at once, you stage a batch, migrate it, then come back for the next.

## `liftoff batch list` — see what's there

```bash
liftoff batch list
```

Lists every **migratable unit** — spaces, stacks, modules, contexts — with its current staging status.
Variables and mounted files aren't listed: they're far too many, and they ride along with their owner automatically.
Filter with `--status unstaged|staged|migrated` and `--kind space|stack|module|context`.

```text
Units (26)
  ┌─────────┬────────────────────────────────────┬────────────────────────────────────┬──────────┬──────────────────────┐
  │ Kind    │ Id                                 │ Name                               │ Status   │ Space                │
  ├─────────┼────────────────────────────────────┼────────────────────────────────────┼──────────┼──────────────────────┤
  │ space   │ Apollorion                         │ Apollorion                         │ unstaged │                      │
  │ space   │ prj-SVGtTCkFUripuBzK               │ Apollorion-Project                 │ unstaged │ Apollorion           │
  │ …       │ …                                  │ …                                  │ …        │ …                    │
  │ stack   │ ws-7YopKPAktoDmhFXW                │ with-var-set                       │ unstaged │ prj-SVGtTCkFUripuBzK │
  │ stack   │ ws-kosDPPzpEYkyxi8K                │ my-amazing-workspace-three         │ unstaged │ prj-VzQwHzLERRqQWNym │
  │ …       │ …                                  │ …                                  │ …        │ …                    │
  │ context │ varset-8NK3XU2nTY7qVmwR            │ Apollorion-test-variable-set       │ unstaged │ root                 │
  └─────────┴────────────────────────────────────┴────────────────────────────────────┴──────────┴──────────────────────┘
```

Everything lands `unstaged` after discover — "not yet triaged."
You stage the units you want in this batch, and re-run `list` (or `list --status staged`) to see the batch take shape.

## `liftoff batch stage` — pick the batch

```bash
liftoff batch stage stack:ws-7YopKPAktoDmhFXW
```

Selectors are `<kind>:<id>` (the `Kind` and `Id` columns from `list`); pass as many as you like, or `--all` for a full lift-and-shift.
**Staging cascades**: a staged stack pulls in the spaces it sits under and the contexts attached to it, so the batch always renders without dangling.
The result shows what changed and *why* each dependency came along:

```text
Status  staged

Changed (4)
  ┌─────────┬─────────────────────────┬──────────────────────────────┬────────────────────────────┐
  │ Kind    │ Id                      │ Name                         │ Via                        │
  ├─────────┼─────────────────────────┼──────────────────────────────┼────────────────────────────┤
  │ context │ varset-8NK3XU2nTY7qVmwR │ Apollorion-test-variable-set │ stack ws-7YopKPAktoDmhFXW  │
  │ space   │ Apollorion              │ Apollorion                   │ space prj-SVGtTCkFUripuBzK │
  │ space   │ prj-SVGtTCkFUripuBzK    │ Apollorion-Project           │ stack ws-7YopKPAktoDmhFXW  │
  │ stack   │ ws-7YopKPAktoDmhFXW     │ with-var-set                 │ requested                  │
  └─────────┴─────────────────────────┴──────────────────────────────┴────────────────────────────┘

Next
  $ liftoff audit
```

`Via` reads `requested` for a unit you named, and `<kind> <id>` for one pulled in by the cascade — here staging the stack brought its project space, that space's parent, and its attached context.

**Staging only ever pulls upward.**
It stages what a unit needs, never what a unit contains.
Spaces are where that catches people out, because staging one does not stage the stacks inside it:

```console
$ liftoff batch stage space:prj-SVGtTCkFUripuBzK
changed[2]{id,kind,name,via}:
  Apollorion,space,Apollorion,space prj-SVGtTCkFUripuBzK
  prj-SVGtTCkFUripuBzK,space,Apollorion-Project,requested
```

Two spaces changed, the requested one and its parent, and no stacks.
The stacks in that space are still `unstaged`, and `liftoff batch list` will show them that way.
To migrate them, name them.

Note that `unstage` is not the mirror image of this: it cascades downward, so unstaging a space *does* take the stacks in it (below).

## `liftoff batch unstage` — change your mind

```bash
liftoff batch unstage stack:ws-7YopKPAktoDmhFXW
```

Reverses a staging choice.
It cascades **down** (unstaging a space takes the stacks in it) and is refcount-aware: a shared parent space stays staged as long as any staged child still needs it, and is released only when nothing does.

There's no `skip` command — to leave something out of the batch, just don't stage it (or `unstage` it if you had).
Once the batch looks right, move on to [audit](audit.md).
