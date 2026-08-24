---
name: project-bootstrap
description: Prepare a new or existing repository for structured agentic development by inspecting the project, establishing project context and state, and preparing the development workflow. Use at the beginning of a new project or when an existing repository lacks project-level agent guidance.
---

# Project Bootstrap

## Objective

Prepare the repository for disciplined agentic development without implementing application features.

## Required Actions

1. Inspect the repository root.
2. Inspect existing documentation.
3. Inspect Git status and repository state.
4. Determine whether the project is:
   - empty/new;
   - partially initialized;
   - an existing application.
5. Read existing:
   - `README.md`
   - `AGENTS.md`
   - `GEMINI.md`
   - architecture documentation
   - package manifests
   - project/solution files
   - test projects
6. Preserve useful existing conventions.
7. Create or update the project state document when appropriate.
8. Ensure the project's development workflow is discoverable.

## Do Not

- implement business features;
- invent requirements;
- choose a technology stack without evidence;
- delete existing project documentation;
- overwrite valid project rules without review.

## For a New Project

Establish:

- project identity;
- current phase;
- known facts;
- assumptions;
- open questions;
- next phase.

## Completion Criteria

Bootstrap is complete when:

- repository state is understood;
- project rules are available;
- project state is recorded;
- the agent workflow is discoverable;
- no application feature has been implemented.

## Output

Report:

- repository condition;
- detected technologies, if any;
- files created/updated;
- current phase;
- open questions;
- recommended next action.
