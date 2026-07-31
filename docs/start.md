# Migrating with liftoff

This is the walkthrough `liftoff --help` points at.
It goes through a migration step by step: the command to run, what the output looks like, and what to decide before moving on.
Each stage has its own page:

1. **[Set up and configure](setup.md)** — what you need before you start, then install `liftoff`, init the workspace, pick a source, set credentials, and validate before running anything (steps 1–4).
2. **[Discover](discover.md)** — pull the whole estate into the local store, read-only (step 5).
3. **[Batch](batch.md)** — list what's there and stage the units to migrate in this batch (step 6).
4. **[Audit](audit.md)** — findings over the staged set, repair keys, `--repair` (step 7).
5. **[Generate](generate.md)** — render the OpenTofu module for the batch (step 8).
6. **[Deploy](deploy.md)** — hand the module to Spacelift and apply it (step 9).
7. **[Mutate](mutate.md)** — capture the staged workspaces' secret values, the one step that touches the source again (step 10).
8. **[Finalize](finalize.md)** — mark the batch migrated, then loop back to discover for the next batch (step 11).

Migrations are **iterative**: discover once, then stage → audit → generate → apply → mutate → finalize a batch at a time, coming back for the next.

The same pages back `liftoff skills <topic>` — an agent asking for `discover` gets [discover.md](discover.md) verbatim, and `liftoff skills start` serves this page.
Working with an agent?
Tell it to run that first.

## Driving this as an agent

These pages are your operating manual, not background reading.
Three rules bind every agent-driven migration:

**Follow the walkthrough to the letter.**
Run every numbered step, in order, none skipped — read-only steps included, even when you already know what they would tell you.
Each step feeds the next: `liftoff sources` is where the config keys come from, `configure validate` is what proves the config before discover.
Don't substitute example files, the samples on these pages, or prior knowledge for running the real command, and read a stage's page (`liftoff skills <topic>`) before running that stage's commands.

**The user drives.**
Before each stage, tell the user what you are about to run and why, and wait for their go-ahead — always before anything that touches the source or Spacelift.
Every decision these pages flag — secret capture, repair keys, exclusions, where the workspace lives — is the user's call: present the options with their consequences and wait for the answer.
After each command, report what happened and what comes next.
A migration the user watched happen is a migration they can trust.

**Some steps hold you to those two rules.**
Reading a page with `liftoff skills <topic>` prints a **proof token** at the end of it.
Pass that back as `--proof-token` on the command that asked for it and the step proceeds.
That is all it is: evidence you fetched the guidance instead of guessing at it.

Anything that changes the source needs the user's approval, and that is the one thing you cannot supply.
`liftoff` refuses to record an approval when it can tell an assistant is driving — only a person, in their own terminal, can give it.
So:

1. **Attempt the step.**
   Don't announce an approval before you have been refused: until the step has asked, there is nothing to approve and the user just gets an error.
2. **Read the refusal.**
   It names what is missing and the exact command that supplies it.
3. **Stop and explain.**
   Tell the user plainly what the command you ran will do to their source system, then give them the command the refusal named.
   They run it themselves, and it reports what it covers, so they are reading liftoff's description of the work rather than yours.
4. **Re-run your original command unchanged.**

Proof tokens and approvals both expire, and an approval also stops applying once it has been spent on a run or if the staged batch changes underneath it.
You will not have to guess when that happens — the step refuses again, names what it needs, and the fix is the same as the first time.

**Stay inside the CLI.**
`liftoff` is the whole surface.
Don't open the workspace SQLite store yourself — `status` and `audit` are how you inspect it — and don't call the source's or Spacelift's APIs on the side, not to verify a token (`configure validate` covers it), not to double-check a revert (`mutate` refuses to run while one is pending; `restore` is the recovery path).
Manual SQL or direct API calls happen only when the user explicitly asks for them.

One output note: piped output is already TOON — never scrape the styled terminal view, and if a command ever prints styled tables (your harness gave it a TTY), add `--output toon`.

## Reading the output

On a terminal, commands print styled text, trimmed to what a person needs.
When output is piped (a script, CI, an agent), the full detail comes out as [TOON](https://github.com/toon-format/toon), and `--output json` gets you strict JSON.
The samples in these pages show the terminal view.
The one exception is `liftoff skills`: a page is markdown, so it prints verbatim whether piped or not — only `--output json` wraps it in the envelope.

Commands never prompt.
When something is missing you get a structured error with a code and a remediation that says what to provide, and the command exits non-zero.
Most results end with a `Next` section listing the follow-up command, so you rarely need to remember what comes after what.
On a terminal the color of a `Next` command is a signal: green is the normal path, yellow means read it before you run it (it redoes work or touches the source), red means it has consequences beyond this machine.

## The pipeline

A migration is a local project, run **iteratively** in batches.
Everything lives in a `./.liftoff` folder at the project root; commands walk up from wherever you stand to find it, so a subdirectory still hits the same workspace.
Only three commands reach the source: `configure validate` (a read-only auth check), `discover` (the read-only pull), and `mutate` (the one source-mutating step, opt-in and always reverted).
Everything else reads the local store.

| step | command                                     | writes                                        |
|------|---------------------------------------------|-----------------------------------------------|
| 1    | `liftoff init`                              | the `./.liftoff` workspace                    |
| 2    | `liftoff sources`                           | nothing                                       |
| 3    | `liftoff configure --source <id> --set source.<key>=v` | `config.yaml`                       |
| 4    | `liftoff configure validate`                | nothing                                       |
| 5    | `liftoff discover`                          | the store (the whole estate, read-only)       |
| 6    | `liftoff batch stage <units>`               | the store (staging choices)                   |
| 7    | `liftoff audit [--repair]`                  | the store, under `--repair` only              |
| 8    | `liftoff generate`                          | the OpenTofu module (staged ∪ migrated)       |
| 9    | `liftoff publish`                           | Spacelift (managed repo + admin stack)        |
| 10   | `liftoff mutate --allow-mutation <name>`    | the store (captured secrets; source reverted) |
| 11   | `liftoff finalize staged`                   | the store (batch → migrated)                  |
| ↻    | back to `liftoff discover` for the next batch | —                                           |

**Every step is idempotent — re-running is always safe.**
A killed discover resumes where it stopped and preserves staging choices, a re-run with nothing new says so and changes nothing, repair converges (a second `--repair` writes nothing), and generate re-renders the same bytes from the same store — keeping every already-migrated file untouched.
When in doubt, run the command again.

## Commands that work at any point

- **`liftoff status`** — inspect the store, read-only: entity counts, where the database lives, and capture progress as `captured/total` (plus `pushed/captured` once finalize has written values live).
  Progress is reported twice: against the **batch** you have staged, which is what `mutate` and `finalize` act on, and against the whole **estate**.
  The batch is the one that tells you whether you can finalize now; the estate is how much migration is left.
  The quick "what do I have so far" check between steps — especially between `mutate` and `finalize`.
- **`liftoff restore`** — put the source back if a `mutate` run was interrupted before it finished reverting.
  Almost never needed; when it is, `mutate` refuses to run and points you here.
  Details in [restore.md](restore.md).
- **`liftoff skills [topic]`** — print the guidance page for a topic (`start`, `setup`, `discover`, `batch`, `audit`, `generate`, `deploy`, `publish-byo-git`, `mutate`, `finalize`, `restore`), plus anything source-specific.
  Built for agents; the content is these pages, starting with this one.

## When something goes wrong

Every failure is one structured error and a non-zero exit — no stack traces, no prompts.
A specimen, from running `liftoff configure --source terraform` before setting a token:

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

Reading it top to bottom:

- **The headline** is what happened; the muted line under it names the entity the error is about.
- **Remediation** is prose to read: how to think about the fix.
- **The middle sections** vary by error and carry the data behind it — here, the missing key's own metadata, the same shape `liftoff sources` shows.
  Many errors have none.
- **Next** is commands to type, same as in any result.

Piped, the same error is one object: `{code, message, entity, remediation, next, details}`.
Scripts and agents branch on `code`; everything a human sees comes from the same fields.
