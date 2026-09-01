# Migrating with liftoff

`liftoff` moves an infrastructure-as-code estate (Terraform Cloud and Enterprise, with more sources to come) onto Spacelift.

It pulls everything the source knows into a local store on your own machine, audits what it found, renders the whole estate as OpenTofu you can read before anything is created, and hands that to a Spacelift admin stack to apply. With `liftoff`, you'll have one static binary, no Docker, and safe re-runs for every step if needed.

There are three methods to use `liftoff`. They all run the same commands against the same local workspace, so you can move between them mid-migration:

- **The CLI, driven by an AI agent** (recommended): Point an agent at these pages and it runs the same commands, stopping at every decision that is yours. Start at [Choosing a model](models.md), then read [Driving this as an agent](#driving-this-as-an-agent) below.
- **The browser UI** `liftoff ui --beta`: The same pipeline as a page, with the step rail and these guides beside each screen. It is in beta and needs the `--beta` flag; see [the browser UI](ui.md).
- **The CLI, by hand**: Type the commands yourself and read what each one reports.

## Walkthrough

Each migration step includes the command(s) to run, what the output looks like, and what you'll need to decide before moving to the next step. The `liftoff --help` command points to this page.

The only page that is not a step in the migration is **[Error codes](errors.md)**, which covers what the `code` on any error means, and what to do about it.

Migrations are **iterative**: discover once, then stage → audit → generate → apply → mutate → finalize a batch at a time, coming back for the next.

1. **[Set up and configure](setup.md)**: What you need before you start, then install `liftoff`, init the workspace, pick a source, set credentials, and validate before running anything (steps 1–4).
2. **[Discover](discover.md)**: Pull the whole estate into the local store, read-only (step 5).
3. **[Batch](batch.md)**: List what's there and stage the units to migrate in this batch (step 6).
4. **[Audit](audit.md)**: Findings over the staged set, repair keys, `--repair` (step 7).
   **[Model](model.md)**: Read the local store, and correct a value `--repair` cannot (any time).
5. **[Generate](generate.md)**: Render the OpenTofu module for the batch (step 8).
6. **[Publish](publish.md)**: Hand the module to Spacelift and apply it (step 9).
7. **[Mutate](mutate.md)**: Capture the staged workspaces' secret values, which touches the source again (step 10).
8. **[Finalize](finalize.md)**: Mark the batch migrated, then loop back to discover for the next batch (step 11).

After staging a batch, or after every batch is migrated,
**[Transform](transform.md)** can reshape the deployment — beginning with
converting the selected stacks and modules to OpenTofu — before `generate` and
`publish` apply that choice.

Migrations are **iterative**: discover once, then batch/stage → audit → generate → publish/apply → mutate → finalize a batch at a time before coming back for the next.

`liftoff skills <topic>` serves the relevant page with guidance for the configured source filled into it.
For example, an agent asking for `discover` gets [discover.md](discover.md) plus that source's discovery details.

If you're working with an agent, tell it to run `liftoff skills start` first, which will serve it this page.

## Driving this as an agent

Before anything else, make sure the model driving your migration is fully capable, since you don't want a migration that only _looks_ like it worked. [Choosing a model](models.md) covers what a model must be capable of and what goes wrong when it isn't.

Three rules bind every agent-driven migration:

**1\. Follow the walkthrough to the letter**

Run every numbered step in order, without skipping any. Include read-only steps, even when you already know what they would tell you. Each step feeds the next: `liftoff sources` is where the config keys come from, `configure validate` is what proves the config before discover.

Do **not** substitute example files, the samples on these pages, or prior knowledge for running the real command. Read a stage's entire page (`liftoff skills <topic>`) before running that stage's commands.

**2\. The user drives**

Before each stage, tell the user what you are about to run and why, and **wait for their go-ahead**, especially before anything that touches the source or Spacelift.

Every decision this walkthrough flags (secret capture, repair keys, exclusions, where the workspace lives, etc.) is the user's call. Present the options with their consequences and wait for the answer.

After each command, report what happened and what comes next.

**3\. Some steps hold you to those two rules**

An agent reading a page with `liftoff skills <topic>` prints a **proof token** at the end of it. Pass that back as `--proof-token` on the command that asked for it to proceed. The token is evidence you fetched the guidance, rather than guessing.

Do not harvest the token without reading the page **entirely**. If you run the command with `| tail`, the agent guidance will not be in your context. Run the command **unfiltered** to retrieve all the guidance.

Anything that changes the source needs the user's approval. `liftoff` refuses to record an approval when an assistant is driving. Only a person, in their own terminal (not within a coding assistant like Claude Code), can give it.

Don't recommend `! liftoff approve …`; it fails every time. So, for each step:

1. **Attempt the step**: Run the command, then wait for it to be refused **before** announcing what the user needs to approve.
2. **Read the refusal**: It tells you exactly what the user needs to do to approve the step.
3. **Stop and explain**: Tell the user plainly what the command you ran will do to their source system, then tell them what they need to do to approve the step. The user will run the approval command and read liftoff's description of the work, rather than yours.
4. **Re-run your original command unchanged**: Once the user has supplied their approval, the original command should work without issue.

Proof tokens and approvals both expire if unused, and an approval also expires once it has been spent on a run or if the staged batch changes. If the approval expires, the step refuses and the user will need to approve it again.

### Stay inside the CLI

`liftoff` is the entire surface. Do not leave it.

- Don't open the workspace SQLite store yourself. `liftoff model` reads every entity in it, and `status` and `audit` summarize it.
- Don't call the source's or Spacelift's APIs on the side for any reason. Manual SQL or direct API calls happen **only** when the user explicitly asks for them.
- Don't scrape the styled terminal view. Piped output is already `TOON`. If a command ever prints styled tables (for example, if your harness gave it a TTY), add `--output toon`.

## Reading the output

On a terminal, commands print styled text, trimmed to what a person needs. When output is piped (a script, CI, an agent), the full detail comes out as [TOON](https://github.com/toon-format/toon), and `--output json` gets you strict JSON.

The samples in these pages show the terminal view. The exception is `liftoff skills`, which prints verbatim, and only `--output json` wraps it in the envelope.

Wherever a result names an entity (such as a skip report, an audit finding, or an inventory), the piped output carries a `url` field linking to that entity at the source, so the agent or user can easily find it. If there is no relevant web address, that field will be omitted.

The styled terminal view shows the link at the decision points where it earns its place (skips, findings, `model get`), but leaves it out of the wide `batch list` / `model list` tables, where it's a column away in the piped output. They are clickable, if your terminal supports it.

Pass `--no-urls` to drop links from the piped output too, for a token-lean run over a large estate.

**Commands never prompt.** When something is missing, you get a structured error with a code and a remediation that says what to provide, and then the command exits non-zero. Most results end with a `Next` section listing the follow-up command, so you rarely need to remember what comes after what.

On a terminal the color of a `Next` command is a signal:

- **Green**: The normal path
- **Yellow**: Read the follow-up command before you run it, because it redoes work or touches the source.
- **Red**: The command has consequences beyond this machine.

## The pipeline

A migration is a local project, run **iteratively** in batches.

Everything lives in a `./.liftoff` folder at the project root. Commands will navigate up to it, so a subdirectory still hits the same workspace.

Only three commands reach the source: `configure validate` (a read-only auth check), `discover` (the read-only pull), and `mutate` (the one source-mutating step, opt-in and always reverted).
Everything else reads the local store.

| **step** | **command**                                            | **writes**                                        |
|----------|--------------------------------------------------------|---------------------------------------------------|
| 1        | `liftoff init`                                         | the `./.liftoff` workspace                        |
| 2        | `liftoff sources`                                      | nothing                                           |
| 3        | `liftoff configure --source <id> --set source.<key>=v` | `config.yaml`                                     |
| 4        | `liftoff configure validate`                           | nothing                                           |
| 5        | `liftoff discover`                                     | the store (the whole estate, read-only)           |
| 6        | `liftoff batch stage <units>`                          | the store (staging choices)                       |
| optional | `liftoff transform workflow-tool`                      | the store (staged entities only)                  |
| 7        | `liftoff audit [--repair]`                             | the store, under `--repair` only                  |
| 8        | `liftoff generate`                                     | the OpenTofu module (staged ∪ migrated)           |
| 9        | `liftoff publish`                                      | Spacelift (managed repo + admin stack)            |
| 10       | `liftoff mutate --allow-mutation <name>`               | the store (captured secrets; source reverted)     |
| 11       | `liftoff finalize staged`                              | the store (batch → migrated)                      |
| ↻        | back to `liftoff discover` for the next batch          | —                                                 |

**Every step is idempotent, so re-running is always safe.** A killed `discover` resumes where it stopped and preserves staging choices, a re-run with nothing new says so and changes nothing, `repair` converges (a second `--repair` writes nothing), and `generate` re-renders the same bytes from the same store while keeping every already-migrated file untouched.

When in doubt, run the command again.

## Commands that work at any point

### `liftoff status`

Inspect the store, read-only. See entity counts, where the database lives, and capture progress as `captured/capturable` (plus `pushed/captured` once finalize has written values live).

Entities that nothing can be captured for (stacks with no states, a module version with a tag that doesn't resolve) are recorded as **unresolvable** with the reason why. The command leaves the denominator and is counted beside it (`2 unresolvable`), so a complete capture reads complete instead of manufacturing a shortfall.

- Progress is reported twice: against the **batch** you have staged, which is what `mutate` and `finalize` act on, and against the whole **estate**.
- The batch is the one that tells you whether you can finalize now; the estate is how much migration is left.
- The quick "what do I have so far" check between steps — especially between `mutate` and `finalize`.

### `liftoff restore`

Put the source back if a `mutate` run was interrupted before it finished reverting.

This is almost never needed; when it is, `mutate` refuses to run and points you here. Details in [restore.md](restore.md).

### `liftoff ui --beta`

Serve a browser UI over this same workspace and open it, with the step rail, each step's screen, and these pages readable beside them. This is in beta, so it needs the `--beta` consent flag; the CLI stays the blessed path.

For people only: agents are refused, and the URL it prints is a session credential. Details in [ui.md](ui.md).

### `liftoff skills [topic]`

Print the guidance page for a topic (`start`, `models`, `setup`, `discover`, `batch`, `audit`, `model`, `generate`, `publish`, `publish-byo-git`, `mutate`, `finalize`, `transform`, `restore`, `ui`), plus anything source-specific.

This is built for agents; the content is these pages, starting with this one.

## When something goes wrong

Every failure is one structured error and a non-zero exit. There are no stack traces or prompts.

Here's an example of a failure from running `liftoff configure --source terraform` before setting a token:

```text
✗ Missing Config  source terraform still needs: api_token (everything else was saved)
  entity: terraform

Remediation
  set each missing key — quote env references like api_token='${TFC_TOKEN}' to keep secrets out of config.yaml

Missing (1)
  ┌───────────┬───────────┬──────────┬────────┬──────────────────┬─────────────────────────────────────────────────────┐
  │ Key       │ Label     │ Required │ Secret │ Used By          │ Help                                                │
  ├───────────┼───────────┼──────────┼────────┼──────────────────┼─────────────────────────────────────────────────────┤
  │ api_token │ API token │ ✓        │ ✓      │ liftoff discover │ Token used to authenticate with the Terraform API — │
  │           │           │          │        │                  │ must be a user token from an admin user (team and   │
  │           │           │          │        │                  │ organization tokens do not work)                    │
  └───────────┴───────────┴──────────┴────────┴──────────────────┴─────────────────────────────────────────────────────┘

Next
  $ liftoff configure --set source.api_token=…
```

Top to bottom:

- **The headline** is what happened; the muted line under it names the entity the error is about.
- **Remediation** tells you how to think about the fix (before you run the suggested command).
- **The middle sections** vary by error and carry the data behind it. In this example, it's the missing key's own metadata, the same shape `liftoff sources` shows.
  Many errors have none.
- **Next** is the command(s) to type, same as in any result.

Piped, the same error is one object: `{code, message, entity, remediation, next, details}`.

Scripts and agents branch on `code`; everything a human sees comes from the same fields.
