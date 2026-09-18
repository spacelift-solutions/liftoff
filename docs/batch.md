# Batch

Step 6 of [the migration walkthrough](README.md): choose which units migrate in this batch.
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
The result shows what changed and _why_ each dependency came along:

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

To land stacks in a space that already exists on the destination account instead
of recreating those source spaces, stage first, then run
[`liftoff transform space mv`](transform.md):

```bash
liftoff batch stage stack:ws-7YopKPAktoDmhFXW
liftoff transform space mv stack:ws-7YopKPAktoDmhFXW --to spacelift_space:<id>
```

`--to` accepts `root`, `spacelift_space:<id>`, or the raw id from
`liftoff model list --kind spacelift_space`. Source spaces that nothing staged
still needs are unstaged by the move. To remap after publish, restage with
`--restage-migrated`, then `transform space mv`, generate, publish, and
`finalize staged`.

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

Note that `unstage` is not the mirror image of this: it cascades downward, so unstaging a space _does_ take the stacks in it (below).

**Re-staging a migrated unit needs a person's explicit agreement.**
Staging normally moves an `unstaged` unit into the batch and is ungated.
But if the cascade would pull back a unit you've already _migrated_, staging drops it out of `migrated` — and the next [`generate`](generate.md) then rewrites its file, losing any hand-edits you made to it.
So that case refuses first, and the refusal names every migrated unit the cascade touches (not just the one you typed) with why it came along, so what you agree to is the real blast radius.
A person agrees by re-running with `--restage-migrated`; an agent cannot use the flag, and instead asks the user to run `liftoff approve stage:migrated` in a terminal of their own.
Staging fresh units is unaffected.

## `liftoff batch unstage` — change your mind

```bash
liftoff batch unstage stack:ws-7YopKPAktoDmhFXW
```

Reverses a staging choice.
It cascades **down** (unstaging a space takes the stacks in it) and is refcount-aware: a shared parent space stays staged as long as any staged child still needs it, and is released only when nothing does.

There's no `skip` command — to leave something out of the batch, just don't stage it (or `unstage` it if you had).
Once the batch looks right, move on to [audit](audit.md).

## Arrange a batch in the browser

The batch screen opens on the **Staging list**, where you choose the batch by
dragging units between Discovered and Staged. **Group by** folds each column into
groups: the source space a unit came from, the environment its name says (dev,
staging, production, test, sandbox), its kind, or the first word of its name.
Each group header carries **Stage all** or **Unstage all**, so a whole project or
every dev unit is one click, then **Apply**. **Arrange spaces** is the second
view. Arrange has two phases. In **Arrange**, the left pane lists units and opens
on the staged batch (**Not staged yet** and **All units** are a filter away);
tick units there to **Stage** or **Unstage** them without leaving the board, or
drag an unstaged unit straight onto a space, which stages it when you apply. The
right pane shows the destination space tree. Every unit card carries a colored tag and stripe for its kind: stack,
module, context, or provider. Drag a unit from the left pane into a folder, or select several
units and choose **Move here**. Each list is paged at 50 rows, so a large batch
stays responsive; use the filters and search suggestions to narrow it first.

The tree shows the space hierarchy; dropping units onto a space updates its
count and nothing else. Choose the **units** count on a row to open a scrolling
window of what that space holds and drag units back out, onto another space or
back onto the unit list to undo a queued move. The account root is a
valid destination, and units already there can be moved again later. Attached
contexts follow their stacks in the draft.

**Labels** adds a set of labels to every staged stack, the same thing as
`liftoff transform stack-labels`. Type them comma-separated; **Preview** is the
command's dry run and says how many staged stacks would change; **Add labels**
applies. When the labels depend on the destination, use the tag on a space row
instead. It has two boxes: labels for the stacks directly in that space, and
labels for that space and every subspace, so a team space can carry
`team:payments` for all of them while its Dev child gets `env:dev` on its own
row. Either box may stay empty. The space remembers what it was last given. Each stack card shows its labels. Labels the source
already had are kept. Discover restores the source labels, so run it again after
a re-discover.

**Tips** overlays a short yellow note on each part of the board: the unit list,
Suggest, the space tree, Add space, and Review. They show on the first visit;
**Got it**, Escape, or the Tips button hides them.

**Undo** reverses the last draft action, including a bulk move, a suggestion
batch, or **Discard all**, and restores any earlier destination. **History**
lists the recent steps, newest first; pick one to rewind through it and
everything after it in one go. Up to 30 actions are kept while this view is
open. Applied changes are not part of this history.

The unit list can be grouped the same way as the Staging list (space,
environment, kind, name prefix). Each group header has **Select all**; one
**Move here** on a space, or one drag, then moves the whole group.

Each card says where the unit sits: **from** a source space it was discovered
in, or **in** a destination space it has already been placed in.

**Suggest by name** matches whole words in a unit's name and ID against space
names, with common environment abbreviations (`prod`, `dev`, `stg`) and
separator variations. Select units to suggest placements for that selection,
including units inside destination folders. With no selection, suggestions use
the filtered available units. When two spaces share a name, the unit's own name
(`payments-prod-api` picks Payments / Production) or the space it currently
sits in breaks the tie. What still ties is left for you, and the message says
which names collided; filter the destination tree to one branch and suggest
again, since Suggest only considers the spaces shown. It keeps existing manual
moves and skips a suggestion when a context attached to several stacks would
be pulled into two spaces; place those stacks together instead. Everything
Suggest skipped is listed above the units with the reason (which spaces tied,
or which shared context is pulled where by which stack) and a **Select** action
that picks the affected units so you can drop them on one space. Each skipped
unit also carries the reason on its card. Review suggested moves before
applying them; Undo reverses the suggestion batch together.

Units tagged **migrated** were published and finalized in an earlier batch. Both
views show them locked in place. Moving one from Arrange spaces re-stages it,
which Review asks you to confirm, because the next generate rewrites its files.

**+ Add space** either plans a new space in the local model, or re-reads the
account (`discover --destination-only`) to bring in a space you created in
Spacelift after the last discover. The **+** on a row plans a subspace under it. Planned spaces carry a **planned** tag and a **Delete**
button, which removes an empty planned space from the plan. A space that
already exists in the account cannot be deleted here. Planned spaces are
created in Spacelift when the generated configuration is applied.

A draft that cannot be applied says so above the units, one row per conflict:
a context attached to stacks headed for different spaces, a unit that is no
longer staged, or a space that left the tree. Each row explains the cause and
offers to undo the moves involved or select the stacks to place together.

Choose **Review changes** when the draft is ready. **Review and apply** shows
the affected units and conflicts. Applying stages unstaged units (including
their dependencies), asks for explicit consent before re-staging migrated
units, then previews and applies each destination move. These steps update the
local model; run audit, generate, publish, confirm the publish plan, and
finalize afterward.
