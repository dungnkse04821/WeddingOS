---
name: requirements
description: Converts validated product discovery into implementation-ready software requirements. Use when the problem, target users, goals, and constraints are sufficiently understood and the project needs functional requirements, business rules, user stories, acceptance criteria, validations, edge cases, permissions, and non-functional requirements.
---

# Requirements Analysis

## Objective

Transform validated Discovery outputs into requirements that are clear enough to plan and implement without silently inventing product behavior.

## Entry Conditions

Use this skill when:

- Discovery is sufficiently mature.
- The user wants requirements, user stories, acceptance criteria, business rules, or feature scope.
- A proposed feature needs clarification before design or implementation.

Do not use this skill as a substitute for Product Discovery when the underlying problem, audience, or goals are still materially unclear.

## Source of Truth

Before analyzing requirements:

1. Read `AGENTS.md` if present.
2. Read `docs/project-state.md` if present.
3. Read `docs/discovery.md` or equivalent product discovery artifact.
4. Read any existing product/specification documents relevant to the task.
5. Inspect the repository only when existing implementation affects the requirement.

## Information Discipline

Always distinguish:

- Confirmed facts
- Explicit product decisions
- Assumptions
- Recommendations
- Unknowns / open questions

Never convert an assumption into a requirement without clearly marking it.

## Analysis Model

For each capability, identify where applicable:

1. Actor / role
2. User goal
3. Trigger
4. Preconditions
5. Main flow
6. Alternative flows
7. Business rules
8. Validation rules
9. Permissions / authorization
10. Data requirements
11. Error conditions
12. Edge cases
13. Dependencies
14. Non-functional considerations
15. Acceptance criteria

## Functional Requirements

Write functional requirements that are:

- specific;
- testable;
- implementation-independent where possible;
- traceable to a user or business outcome.

Avoid vague statements such as:

- "The system should be user-friendly."
- "The page should be fast."
- "Support all wedding workflows."

Replace vague language with measurable or observable behavior.

## User Stories

Use user stories when they improve communication:

As a [role],
I want [capability],
so that [user/business value].

A user story is not sufficient by itself. Pair important stories with business rules and acceptance criteria.

## Acceptance Criteria

Use Given / When / Then when appropriate.

Example:

Given a couple has created a wedding,
When they add a guest with a valid name,
Then the guest is added to that wedding's guest list.

Acceptance criteria must describe externally observable behavior.

## Business Rules

Business rules should be explicit and individually identifiable.

Example format:

BR-001 — A guest belongs to exactly one wedding within the MVP.

Do not bury important rules inside prose.

## Non-Functional Requirements

Evaluate only relevant NFR categories:

- security;
- privacy;
- accessibility;
- performance;
- availability;
- reliability;
- responsiveness;
- localization;
- auditability;
- compatibility;
- maintainability.

Do not invent aggressive targets without evidence. Mark recommendations separately from confirmed constraints.

## Scope Control

Identify:

- In Scope
- Out of Scope
- Deferred / Future
- Dependencies

Prevent scope creep by identifying requests that belong outside the current MVP or feature.

## Quality Review

Before considering Requirements complete, check for:

- ambiguity;
- contradictions;
- duplicate requirements;
- missing actors;
- missing permissions;
- missing validation;
- missing failure cases;
- missing edge cases;
- untestable language;
- assumptions presented as facts;
- unresolved decisions that materially affect implementation.

## Required Output

Prefer creating or updating `docs/requirements.md` when the project uses a docs directory.

Recommended structure:

# Requirements

## Context

## Actors

## Functional Requirements

## User Stories

## Business Rules

## Validation Rules

## Permissions

## Data Requirements

## Non-Functional Requirements

## Acceptance Criteria

## Edge Cases

## Scope

### In Scope

### Out of Scope

### Deferred

## Assumptions

## Open Questions

## Traceability

Where practical, map major requirements back to Discovery goals or user outcomes.

## Phase Gate

Requirements may move to Product Planning only when:

- core MVP requirements are sufficiently clear;
- material contradictions are resolved;
- major business rules are explicit;
- critical open questions are resolved or consciously deferred;
- the requirements are testable enough to prioritize.

Do not silently advance the project phase.

When the phase changes, update `docs/project-state.md`.

## Completion Report

At the end, report:

- requirements added or changed;
- assumptions introduced;
- unresolved questions;
- scope changes;
- whether Requirements are mature enough for Product Planning.
