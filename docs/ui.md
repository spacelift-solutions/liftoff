# The browser UI

A companion to [the migration walkthrough](README.md): the same pipeline, driven from a page.

**The UI is in beta.** The CLI is the blessed path (run by hand, or driven by an agent), and it is what every other page here documents.
The UI runs those same commands and can do nothing they cannot, but it is newer and rougher; when something looks wrong, the terminal is the answer.
That is what `--beta` below consents to, and the page repeats it on first open before it will let you in.

`liftoff ui` serves a browser UI for the workspace and opens it.
It is a window onto the same migration every other surface drives: the step rail on the left shows where the migration stands and unlocks steps as you reach them, each step carries its own screen (with the embedded walkthrough readable beside it), and every action the page takes runs a real `liftoff` command under the hood.
Anything the UI can do, the CLI can do; the UI can never do more.

```sh
liftoff ui --beta
```

`--beta` is the global consent flag for anything still in beta, and the UI is its first user.
Without it, the command refuses and says so:

```text
✗ Beta Only  the browser ui is in beta, and the cli is the blessed path
  entity: ui

Remediation
  re-run with --beta to consent to using a beta feature
```

Opening the page asks once more: the first screen states the same thing and will not let you past until you accept it.

The command prints a URL and keeps serving until you stop it (Ctrl-C).
The UI is only reachable from the machine it runs on.
`--port` picks the port (the default is an ephemeral free one), and `--no-browser` prints the URL without opening anything.
That's the option for a machine where no browser can open; you open the printed URL yourself.

## The URL is a credential

Actions taken in the UI count as *you* acting: steps that normally stop and ask for a person (approvals, consent to destructive operations) treat a click in the UI the way they treat you running the command in your terminal.
The URL carries the session token that makes that true, so treat it like a password: don't share it, don't paste it anywhere, and don't hand it to an AI agent.
Each run mints a fresh token; stopping `liftoff ui` invalidates its URL.

## People only

Agents are refused outright; this is the refusal as `liftoff ui --output json` prints it from inside an agent session:

```json
{"error":{"code":"ui_needs_a_person","message":"the ui is a person's surface, and this looks like an agent (no-tty env=AI_AGENT+CLAUDECODE+CLAUDE_CODE_ENTRYPOINT parent=claude)","remediation":"agents run liftoff commands directly instead; if a person wants the ui, they can run `liftoff ui --beta` in a terminal of their own"},"schema_version":1}
```

There is no proof token or approval that lifts this: an agent has the whole CLI and needs nothing from the UI.
If you are a person and were refused, run the command from a plain terminal rather than from inside an agent session.

## Command explorer

Beyond the curated screens, the UI lists every liftoff command with a generated form for its flags.
New commands appear there automatically; the UI reads the command surface from the binary itself rather than keeping its own copy.
