---
name: project-orchestrator
description: Governs the end-to-end software development lifecycle, determines the current project phase, routes product and BA work to the canonical framework skills, routes engineering workflow to Superpowers when available, resolves overlapping skills, enforces phase gates, and maintains project state. Use before substantial project work, new features, architectural changes, debugging, implementation, review, or delivery.
---

# Project Orchestrator

## Purpose

Act as the canonical routing and governance layer for software development projects.

This skill decides:

- the current development phase;
- whether prerequisite product decisions are complete;
- which canonical process skill should be used;
- when Superpowers should handle engineering workflow;
- which complementary domain skills may be combined;
- when work must stop for clarification or approval;
- whether the project may advance to the next phase.

The orchestrator does not replace specialist skills.

## Sources of Truth

Before routing substantial work:

1. Read `AGENTS.md` if present.
2. Read `docs/project-state.md` if present.
3. Read relevant product artifacts:
   - `docs/discovery.md`
   - `docs/requirements.md`
   - `docs/product-plan.md`
   - architecture/spec documents
4. Inspect the repository when implementation state matters.
5. Read the user's current request.

If project state conflicts with repository evidence, identify the discrepancy before proceeding.

## Lifecycle

Use the following canonical phases:

0. BOOTSTRAP
1. DISCOVERY
2. REQUIREMENTS
3. PRODUCT-PLANNING
4. ARCHITECTURE
5. SCAFFOLDING
6. IMPLEMENTATION
7. TESTING
8. DEBUGGING
9. REVIEW
10. VERIFICATION
11. DELIVERY

Not every task must traverse every phase from zero.

Select the earliest necessary phase based on the task and existing project state.

## Canonical Ownership

### Product / BA / Governance — This Framework

Use the framework's canonical skills for:

- project-bootstrap
- discovery
- requirements
- product-planning
- project-orchestrator
- architecture when installed

These skills own product definition, business analysis, phase governance, scope, and project state.

### Engineering Methodology — Superpowers

When Superpowers is available, prefer its engineering process skills for:

- `brainstorming` — engineering/design exploration for a concrete feature or technical change
- `writing-plans` — implementation planning
- `executing-plans` — executing an approved implementation plan
- `test-driven-development` — TDD workflow
- `systematic-debugging` — defect/root-cause workflow
- `requesting-code-review` — preparing/requesting review
- `receiving-code-review` — handling review feedback
- `verification-before-completion` — evidence-based completion
- `using-git-worktrees` — isolated implementation work
- `subagent-driven-development` — delegated implementation
- `dispatching-parallel-agents` — parallelizable independent work
- `finishing-a-development-branch` — completion/branch integration workflow

Do not recreate an equivalent local process skill merely because Superpowers is global.

## Routing Policy

### A. Brand-New Product

Default:

project-bootstrap
-> discovery
-> requirements
-> product-planning
-> architecture
-> scaffolding
-> engineering implementation workflow

Superpowers `brainstorming` must not replace Product Discovery.

It may be used later for technical/design exploration after product requirements and MVP context are sufficiently understood.

### B. New Feature in an Existing Product

Determine whether the requested feature changes product behavior materially.

If requirements are unclear:

requirements
-> update/confirm scope

Then, when product behavior is sufficiently clear:

Superpowers brainstorming
-> architecture review if needed
-> Superpowers writing-plans
-> implementation/TDD
-> review
-> verification

Do not restart full Product Discovery for a small, well-understood feature.

### C. Architecture Change

requirements / product constraints if needed
-> architecture
-> Superpowers brainstorming for technical alternatives when useful
-> writing-plans
-> implementation
-> verification

### D. Bug / Failure

Superpowers systematic-debugging
-> relevant domain/framework skill
-> testing
-> verification-before-completion

Do not route ordinary defects through Product Discovery or Product Planning.

### E. Implementation from Approved Plan

Superpowers executing-plans
and/or
Superpowers test-driven-development

Use relevant domain/framework skills as complementary implementation guidance.

### F. Code Review

Superpowers requesting-code-review
or receiving-code-review
plus relevant domain/security skills if necessary.

### G. Completion

Use Superpowers verification-before-completion before claiming material implementation work is finished.

### H. Parallel Work

Use parallel/subagent workflows only when tasks are sufficiently independent.

Avoid parallel edits to the same files or tightly coupled implementation areas without isolation.

Prefer Git worktrees or equivalent isolation for parallel code changes.

## Skill Conflict Resolution

When multiple skills overlap:

1. Follow explicit project instructions first.
2. Prefer the canonical owner defined in this document.
3. Prefer project-specific domain skills over generic domain skills when the responsibilities are complementary.
4. Prefer narrower task-specific skills over broad generic skills.
5. Do not execute multiple equivalent process skills.
6. Combine process + domain skills when they answer different questions.

Examples:

`requirements` + `sql-server`
is valid:
- requirements defines required behavior;
- sql-server guides database implementation.

`requirements` + another generic requirements-analysis skill
is normally invalid unless explicitly comparing methodologies.

`systematic-debugging` + `sql-server`
is valid for a SQL-related production bug.

## Phase Gates

### Bootstrap -> Discovery

Ready when:
- repository state is understood;
- project rules/state exist;
- development workflow is available.

### Discovery -> Requirements

Ready when:
- problem is sufficiently understood;
- primary users are identified;
- goals/outcomes are clear;
- major constraints are visible;
- material discovery questions are answered or explicitly deferred.

### Requirements -> Product Planning

Ready when:
- core behavior is testable;
- business rules are sufficiently explicit;
- major contradictions are resolved;
- scope can be prioritized.

### Product Planning -> Architecture

Ready when:
- MVP boundary is clear;
- core user journey is coherent;
- dependencies and product risks are visible.

### Architecture -> Scaffolding

Ready when:
- major architectural decisions and technology choices required for scaffolding are settled.

### Scaffolding -> Implementation

Ready when:
- project structure is valid;
- build/run baseline is established;
- implementation can proceed predictably.

### Implementation -> Testing / Review

Ready when:
- planned implementation work exists and can be validated.

### Review -> Verification

Ready when:
- material review findings have been resolved or consciously accepted.

### Verification -> Delivery

Ready when:
- completion claims are supported by evidence.

## State Management

After a meaningful phase transition, update `docs/project-state.md` when present.

State should include at least:

- current phase;
- completed phases;
- active task;
- confirmed decisions;
- assumptions;
- blockers;
- next recommended action.

Never silently advance the recorded project phase.

## Approval / Clarification

Stop and ask when:

- a major product decision is missing;
- MVP scope materially changes;
- a major architectural decision has multiple meaningful trade-offs;
- a destructive operation is proposed;
- credentials/secrets/production changes are required;
- the next phase depends on unresolved user intent.

Do not ask unnecessary questions when existing project artifacts already answer them.

## Output

When making a routing decision, communicate concisely:

- Current phase
- Why
- Selected skill(s)
- Why those skills own the work
- Blockers / approvals needed
- Next valid step

## Core Principle

Product workflow defines WHAT and WHY.

Architecture bridges product intent to system structure.

Superpowers governs disciplined engineering execution.

Domain/framework skills provide specialized implementation knowledge.

Do not allow those layers to compete for the same responsibility.

<!-- HANDOFF_ROUTING_START -->
## Harness Handoff Routing

When the user indicates that work is moving between Antigravity, Codex, another coding harness, or another agent instance, treat the transition as a handoff workflow rather than an ordinary task change.

### Outgoing Handoff

Route the outgoing worker through:

verification
-> project-state update
-> Git status checkpoint
-> commit checkpoint when appropriate
-> handoff summary
-> stop

The handoff summary must include:

- current project phase;
- task completed or paused;
- files materially changed;
- tests or verification performed;
- known issues;
- unresolved decisions;
- recommended next action.

Do not begin a new feature after preparing the handoff unless explicitly requested.

### Incoming Takeover

Before implementation or modification:

1. Read `AGENTS.md`.
2. Read `docs/project-state.md`.
3. Read relevant product, requirements, architecture, and implementation artifacts.
4. Inspect recent Git commits.
5. Inspect current `git status`.
6. Identify the latest completed task.
7. Identify unfinished or blocked work.
8. Determine the current project phase.
9. Route the next task to the canonical skill owner.

If the repository state conflicts with `docs/project-state.md`, stop and reconcile the inconsistency before proceeding.

### Routing After Takeover

Use the existing canonical routing policy:

- Product Discovery -> `discovery`
- Requirements -> `requirements`
- Product Planning -> `product-planning`
- Technical/feature design -> Superpowers `brainstorming` when appropriate
- Implementation planning -> Superpowers `writing-plans`
- Approved implementation -> Superpowers `executing-plans` and/or `test-driven-development`
- Defect investigation -> Superpowers `systematic-debugging`
- Code review -> Superpowers review workflow
- Completion -> Superpowers `verification-before-completion`

Do not restart earlier product phases when repository evidence shows they are already complete or sufficiently approved.

### Parallel Harness Work

When two harnesses work concurrently:

- prefer separate Git worktrees or equivalent isolated branches for code changes;
- do not allow two workers to edit the same tightly coupled files without explicit coordination;
- define ownership per task;
- integrate through Git;
- run verification after integration.

Parallel research, analysis, and review may share the repository when they do not mutate conflicting state.

### Handoff Principle

A harness transition must not depend on hidden conversation context.

The receiving worker must be able to reconstruct the project state from repository artifacts and Git history.
<!-- HANDOFF_ROUTING_END -->

