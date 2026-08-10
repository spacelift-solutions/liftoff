<!-- comprehension: discover -->
# Discover

Step 5 of [the migration walkthrough](start.md): pull the whole estate from the source into the local store — **read-only**.

## Step 5 — discover the estate

```bash
liftoff discover
```

Pulls everything from the source into the local store.
This is a **read-only** pull and the only network-bound read — its duration scales with the estate.
It is idempotent and resumable: if it dies or you kill it, run it again and it picks up where it left off, **preserving any staging choices you've already made**.
Progress goes to stderr: add `-v` to watch it work, and repeat for more detail (`-vv`).

```text
Source  terraform

Sensitive Values
  Sensitive Variables  22
  Captured             0
  Empty                22

  Notes (2)
    - 19 sensitive stack variable value(s) are empty — stage the stacks, then run `liftoff mutate` with a capability
      that captures them (`liftoff sources` lists what this source declares), or set them in Spacelift after the
      migration
    - 3 sensitive context variable value(s) are empty — stage the contexts, then run `liftoff mutate` with a capability
      that captures them (`liftoff sources` lists what this source declares), or set them in Spacelift after the
      migration

Counts
  Context Variables  6
  Contexts           3
  Modules            1
  Mounted Files      0
  Spaces             9
  Stack Variables    41
  Stacks             13

Spacelift Counts
  VCS Integrations  4
  Worker Pools      1

Next
  $ liftoff batch list
```

`Counts` is what actually landed in the store, read back after the run.
`Spacelift Counts` is the other end of the pipe: what your Spacelift account has, which discover reads before it touches the source.
`Sensitive Values` is the report on the one thing discover cannot take: secret values.
Discover **never touches the source**, so sensitive values always come over empty — the notes say exactly what that means and how to capture them later (stage what you want, then [`liftoff mutate`](mutate.md)).

Discover is deliberately whole-estate and read-only: you can't choose what to migrate until you can see everything, and pulling it all is safe because nothing is mutated.
From here you pick a batch with [`liftoff batch`](batch.md); the heavy, source-touching work ([`mutate`](mutate.md)) runs later and only for what you stage.

Two behaviors worth knowing:

- **Discover reads your Spacelift account first, before it touches the source.**
  It records the VCS integrations and worker pools the account has, so a bad Spacelift key pair fails here rather than after a long walk through the estate, and the stacks it discovers can be bound to the integration that actually serves each repository.
  Where an account has more than one integration a repository could use, discover picks the one connected to the account or project that repository lives under, preferring a working integration over a broken one — so two GitHub Apps on the same host no longer need you to choose between them by hand.
  This is why the destination credentials are required from this step onward, not only at deploy time.
- **Running discover again is always safe — and it always re-reads your Spacelift account.**
  When there's nothing new in the source it says so and changes nothing (`note: nothing to discover…`); it never resets the staging choices you've made.
  But it still reads the destination first every time, and that is deliberate: the estate is cached in the store, the destination is not, because the destination can change while you work — and either way the read is read-only.
  A re-run's `Spacelift Counts` is a fresh look, not the cached one, so it catches the account moving underneath the migration.
  In practice that matters: `publish` creating the managed repository's VCS integration takes the account's integration count up by one between batches, and a re-discover is what notices, rather than binding the next batch's stacks against a stale inventory.
  The `liftoff discover --clobber` hint it offers is the start-fresh option, colored as a caution because it throws away the local results *and* your staging.
  Because clobber discards captured secret values and state — the work an approved, source-mutating [`mutate`](mutate.md) run went and got — it now asks a person to approve it, and the ask counts exactly what will be lost (captured sensitive values, captured state blobs, staged units, migrated units) so you approve a real number, not a warning.
  A workspace with nothing captured or staged still asks, but says the loss is nothing.
  One caveat it names for you: clobber resets the store, not the files you've already generated, so after a migrated batch those files stay on disk describing an estate the re-discover no longer matches — re-generate, or clobber the output too, to keep them in step.
- **Re-discovering after migrating a batch is additive.**
  It refreshes entity data, skips nothing you've staged or migrated, and picks up new source entities — so the next batch starts from a current picture.
- **Teams, agent pools, policies, and run tasks come over as audit-only data.**
  Discover records your TFC teams (and their access), agent pools, policies and policy sets, and run tasks, but the kit never generates from them — TFC RBAC doesn't map 1:1 onto Spacelift, a worker pool is stood up separately, policy bodies are Rego in Spacelift (a different language from Sentinel/OPA) so they don't translate automatically, and a run task's external callout is reconnected as a separately provisioned integration.
  [`audit`](audit.md) surfaces each so you can recreate them deliberately; nothing is placed in a space.

From here, no command touches the network until the module is handed to Spacelift: [batch](batch.md), [audit](audit.md), and [generate](generate.md) all read the store you just filled.
