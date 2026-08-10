<!-- comprehension: models -->
# Choosing a model to drive a migration

*Last reviewed: 2026-08-07. Model quality moves fast — weigh this page's age, and see [the floor](#the-floor-what-a-model-must-be-able-to-do) rather than any single name.*

liftoff is agent-first: the recommended way to run a migration is to point an AI at the walkthrough and let it drive.
That makes the model a real dependency of the tool — the same kind of dependency as OpenTofu or a network path, and the one you choose rather than install.
This page says what that model has to be capable of, and what goes wrong when it isn't.

## Why the choice matters

A weak model driving a migration does not crash.
It produces a migration that **looks** like it worked — and that is the dangerous outcome, because the next thing you do is retire the source system.

The consequences are concrete, and none of them announces itself:

- **A half-migrated estate** — batch 1 lands, the thread is lost partway through batch 2, and some stacks exist in Spacelift while others were never migrated at all.
- **Stacks pointed at the wrong code** — a stack comes up in Spacelift holding real Terraform state but tracking a repository that is not its own. The first confirmed run plans a destroy of everything that state describes.
- **A gate routed around** — the consent gates are the last line of defence before an irreversible action. A model that reaches for direct database or API access when the CLI refuses, or that tries to approve its own step, has removed that line of defence.
- **An anomaly papered over** — the source told the truth, the model smoothed it into a plausible answer, and the operator never saw the thing that should have stopped them.

Every one of these passes a casual look. The migration reads as a success, the operator decommissions their old system, and the problem surfaces on the first apply — when it is expensive to undo.

## The floor: what a model must be able to do

Judge a model by behaviour, not by size.
Parameter count is the weakest available proxy: a smaller model with strong tool use and instruction-following will out-drive a larger one without them, and the failures that matter here are behavioural.
A model fit to drive a migration must be able to do all four of these:

1. **Sustain a long, ordered sequence.**
   A migration is 30-plus ordered steps across two or more batches, with re-reads after the context is compacted.
   Losing the thread partway is the dominant risk — the model has to hold the plan across the whole run, not just the current step.
2. **Re-read guidance on demand instead of working from memory.**
   Each stage's page (`liftoff skills <topic>`) is the operating manual, and the model must actually re-read it rather than acting on a summary or a half-remembered earlier read.
   A model that shortcuts the read holds guidance it has not actually taken in.
3. **Use tools reliably and stay inside the gates.**
   It must call the CLI correctly and consistently, and it must treat a refusal as a stop — not as a puzzle to route around with direct SQL, a side API call, or a self-approval.
   Reaching around a gate is disqualifying no matter how well the model does everything else, because the gates are exactly what protect the irreversible steps.
4. **Follow instructions it has reason to disagree with — and surface anomalies rather than smoothing them.**
   The most valuable thing a driving model does is contradict a wrong assumption: check a claimed repository rename against reality and flag that it is only half-true, rather than pointing working stacks at repositories that do not exist.
   A model that agrees pleasantly and papers over the discrepancy is worse than useless here.

If a model cannot clear all four, it is below the floor for this work — whatever its reputation on other tasks.
You can check your own setup against the list above without anyone naming your model for you: run a small, throwaway migration against a source you don't mind touching, watch for these four behaviours, and if any one of them fails, don't drive a real migration with it.

## What we recommend

Drive a migration with a **current frontier general-purpose model** — the top tier from a major lab, the class of model built for long, tool-using, agentic work.
As of this page's review date the models we have driven a full migration with successfully are in the **Claude Opus / Sonnet frontier tier**; frontier models of the same class from other major labs are the expected shape of that list, judged against the floor above rather than the name.

We deliberately do **not** publish a list of models that must not be used.
Such a list ages badly and reads as a swipe at other vendors.
The floor protects you just as well: a small local model, an older generation, or a lightweight assistant can be checked against the four behaviours and will fail at least one — you will reach the right conclusion without us naming it.

Two honest notes on the strength of this recommendation:

- It is grounded in a blind, end-to-end customer-simulation migration driven by a single capable frontier model — the same run that produced most of this documentation — not yet in a comparative harness that scores many models against one another. The floor is derived from where that run's model succeeded and where it slipped.
- Model quality changes month to month. The review date at the top is there so you can weigh how current this is; when it is old, trust the behavioural floor over any specific name.

## If you have no capable model

You do not need an AI to migrate.
Every `liftoff` command works from a human operator's terminal, and the walkthrough reads the same whether a person or an agent runs it.
If the only model you can run falls below the floor, drive the migration yourself rather than trusting it to a model that will produce a confident, wrong result — a hands-on migration is slower, not less safe.
