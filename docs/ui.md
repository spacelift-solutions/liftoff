# The browser UI

A companion to [the migration walkthrough](README.md): the same pipeline, driven from a page.

Run this from your migration directory in your own terminal:

```sh
liftoff ui
```

The browser UI is included in the Liftoff binary. No separate runtime or installation is needed.
It opens directly into your workspace, with a step rail showing migration progress and the walkthrough beside each screen.
Every action runs the same commands as the CLI, against the same local configuration and encrypted store, so you can switch between the browser and terminal during a migration.
The `--beta` flag has been removed; omit it from launch commands.

At launch, Liftoff asks for the workspace password if it is not already available through `LIFTOFF_STORE_KEY`.
For a new workspace, it asks you to choose and confirm a password.
Keep the terminal running while you use the UI. Ctrl-C stops the server.
The UI is only reachable from the machine it runs on.
`--port` selects a port; the default is a free port chosen at launch.
`--no-browser` prints the session URL without opening a browser, so you can open it yourself.

## Review and apply admin stacks

After staging, auditing, and generating a batch, open **Publish**:

1. Choose **Plan admin stacks** to publish the generated code and view the first outstanding plan.
2. Review the plan and choose **Confirm and apply** for the named admin stack.
3. When that apply finishes, the next outstanding plan appears. Continue until the screen reports **All admin stacks applied**.

Parents apply before their children are planned. Each parent creates its immediate child spaces and the admin stacks inside them.
Plans and apply logs are grouped by admin stack, with links to the runs in Spacelift.
Results appear when each command finishes; for live logs, use Spacelift.

**Approve all admin stacks** opens a confirmation naming the destination account.
Confirming authorizes all remaining admin plans for the publish, including plans not yet generated and any creates, changes, or destroys they contain.
The operation stops on the first failure and keeps completed work and returned logs visible.
Run it again to resume; approving all requires confirmation again.
Choose individual plan confirmation when you want to read each plan before authorizing it.

If child-space management is disabled, **Review account setting** opens a separate confirmation for that account-wide permission change.
Canceling either confirmation makes no change.
See [Publish](publish.md) for registry-module reuse, prerequisites, and approval details.

Publishing creates the migrated workload stack configurations. It does not run those workloads.
Finish all admin stacks before continuing to secret capture and finalization.

## The URL is a credential

Actions taken in the UI count as you acting: a confirmation in the browser grants the same authority as running the corresponding command in your terminal.
The URL carries the session token that makes that true, so treat it like a password: do not share it, paste it anywhere, or give it to an AI agent.
Each launch creates a fresh token; stopping `liftoff ui` invalidates its URL.

## People only

Agents cannot start the UI; the command returns `ui_needs_a_person` before printing a session URL.
There is no proof token or approval that lifts this restriction. Agents use the CLI and its approval workflow.
If you are a person and were refused, run the command from your own terminal rather than from inside an agent session.

## Command explorer

Beyond the migration screens, **All commands** lists every Liftoff command with a generated form for its flags.
The UI reads the command definitions from the binary, so new commands appear there automatically.
