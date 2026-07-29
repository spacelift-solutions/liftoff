# Deploy and finalize

Step 9 of [the migration walkthrough](start.md) and the steps that close out a
batch: hand the generated module to Spacelift, let the admin stack create
everything, then — once the stacks exist — capture secrets
([mutate](mutate.md), step 10), mark the batch migrated
([finalize](finalize.md), step 11), and move the last pieces that couldn't
travel as code (secret values, state, module versions) into place.

## Step 9 — publish the module and create the admin stack

`liftoff publish` hands the generated module to Spacelift over the API — no
external git required. It commits the module to a **Spacelift-managed
repo** (Spacelift hosts the git), creates the **admin stack** that applies it,
binds it a space-admin role, then watches the run the commit triggered and shows
you its plan:

```bash
liftoff publish
```

```text
Repo           liftoff
Stack          liftoff-admin
Revision Sha   10df81bc2585ac967ddb5ce4512c5efcd17c6068
Repo Created   yes
Stack Created  yes
Created        3
No Op          no

Plan
  Run Id       01K1P7QW3HXNVZ4M8DKR2YB6TC
  State        UNCONFIRMED
  Plan         +12 ~0 -0
```

The plan itself streams to your terminal as Spacelift produces it, the same
output the run page shows. Piped or under `--output json` it comes back inside
the result object instead (the plan phase only, not the `tofu init` preamble), so
stdout stays one parseable object an agent can read.

The admin stack is just a normal stack whose code happens to create your spaces
and stacks — a root module that calls one module per space — so you can read
every line of what it is about to do. Its `project_root` is the module root, its
provider is `SPACELIFT` (the managed repo), and it manages its own state.

Both the repo and the stack are labelled **`liftoff:managed`** when liftoff
creates them, and liftoff only touches what carries that label. If a repo or
stack already exists under the name it wants without the label, it stops and says
so rather than reconfiguring something that isn't its own — point it at a
different name with `liftoff configure`, or add the label yourself to hand the
entity over. liftoff won't add that label to anything it didn't create; taking
ownership of your entities is your call, not the tool's.

Publish is **idempotent and re-runnable**: it commits only the files that
changed (all of them the first time), and when nothing has changed since the
last publish it's a no-op — `No Op yes`, cheap enough to run any time to check
you're current. Re-generate after new repairs, then `liftoff publish` again to
push the delta.

Publish stops at the plan and **applies nothing**. The admin stack is created with
autodeploy off on purpose, so its run waits in `UNCONFIRMED` until someone has
read the plan and confirmed it — no plan applies unreviewed. Check the resource
count against the `Counts` your discover reported.

### Apply the plan you read

Publish ends by printing an **apply token**. It confirms that one plan:

```bash
liftoff publish --apply-token 9f2c1ab34de5f607
```

The token is derived from the run, the commit it planned, and the resource counts,
so it only confirms the plan it was issued for. Re-generate, publish again, or let
anything else change what would apply, and the old token is refused — you read the
new plan and use its new token. It's the same guarantee as handing `tofu apply` a
saved plan file, and the reason an agent can't apply a plan it never read.

Applying pushes nothing (a new commit would replan and retire the token). It
confirms the run and streams the apply the way the plan streamed, ending when the
run reaches a terminal state; a run that fails comes back as an error with its log.

From there the admin stack is **self-managing**: the next publish reconciles
Spacelift to match, moves included (in-place, never destroy-and-recreate).

Because that unconfirmed run holds the stack, a later `liftoff publish` would
queue behind it. Publish handles the common case itself: when its own newer push
supersedes a run still waiting for confirmation, it discards that stale run and
tells you which (`Discarded Runs`). It won't touch a run that's still working —
it stops and says which one to wait for — and it refuses to show you a plan that
isn't the one your module would apply, which happens when something else pushed
to the repo after you.

The generated code carries secret *references* and no state, so the stacks stand
up from discover's read-only data alone. Everything that couldn't travel as code
is moved in afterward, in the next steps.

**Prefer your own VCS?** The managed repo is the paved road, not a requirement —
`liftoff` only emits files. To commit the module to your own GitHub/GitLab/etc.
and wire the admin stack yourself, see
[bring your own git](publish-byo-git.md).

## Steps 10–11 — capture secrets, then finalize

With the stacks live, [`liftoff mutate`](mutate.md) (step 10) is the one step
that reaches the source again, and only for the capabilities you name: with
`--allow-mutation state` it captures each staged stack's current Terraform
**state**, and with `--allow-mutation secrets` their masked secret **values**,
both into the local store at cutover. Then
[`liftoff finalize staged`](finalize.md) (step 11) flips the batch
`staged → migrated`, closing the loop so the next `discover` preserves it and
`generate` keeps its files. Both have their own pages; run them in that order.

## Moving in what couldn't travel as code

The applied module creates the *shapes*. Non-sensitive variables already
travel as code — `generate` emits each one as a `spacelift_environment_variable`
in its stack's file — so only the pieces that can't be expressed as HCL are
left for `finalize`:

```bash
liftoff finalize sensitive
liftoff finalize state
liftoff finalize modules
```

- **`finalize sensitive`** pushes the secret values `mutate` captured into
  Spacelift as write-only environment variables and mounted files — for stacks
  and contexts alike, the only moment they leave the local store, and unreadable
  once set.
- **`finalize state`** migrates each staged stack's state into Spacelift. The
  state is captured locally in `mutate` at cutover, then pushed over the API —
  uploaded to storage and imported onto the (briefly locked) stack, with nothing
  temporary created in your account. Stacks never applied at the source have no
  state and are skipped.
- **`finalize modules`** recreates each private module's published versions in
  Spacelift, pushing the commit SHAs that [`mutate --allow-mutation
  module-git-versions`](mutate.md) resolved from the module's VCS (the source
  never exposes them). Versions with no VCS connection or no matching tag can't
  be recreated and are surfaced by [`liftoff audit`](audit.md). See
  [finalize](finalize.md) for the details.

After state lands, the migration is complete: Spacelift runs plans against
the same state the source last held, and the source can be retired on your
schedule.

## What comes after

Migration is lift-and-shift by design — everything lands where it lived at
the source. The phase that follows is adoption: organizing spaces around how
your teams actually work, tightening policies, and adopting Spacelift-native
workflows. The `liftoff space` command group (create, move, reshape — a move
relocates a stack's file into the target space's directory and emits a `moved`
block, so the admin stack re-parents it in place) is the tooling for that phase,
and its shape is still being worked out with early users. Expect this page to grow.
