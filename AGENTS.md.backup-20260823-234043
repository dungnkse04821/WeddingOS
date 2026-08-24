# WeddingOS - Agent Development Rules

## 1. Project Mission

WeddingOS is a new software project.

The project must be developed through a deliberate product-to-production workflow:

Bootstrap
-> Discovery
-> Requirements
-> Product Planning
-> Architecture
-> Scaffolding
-> Implementation
-> Testing
-> Debugging
-> Review
-> Verification
-> Delivery

Do not jump directly from an initial idea to production implementation
when the required product or technical decisions have not been established.

## 2. Primary Development Rule

Before any substantial development task:

1. Inspect the current repository state.
2. Read this file.
3. Read `docs/project-state.md`.
4. Consult the `project-orchestrator` skill.
5. Determine the current development phase.
6. Select only the skills relevant to the current task.

## 3. Change Management

- Do not modify unrelated files.
- Prefer small, focused changes.
- Reuse established project patterns.
- Do not introduce dependencies without a clear reason.
- Do not rewrite existing code merely for stylistic preference.
- Do not change approved architecture without identifying the impact.

## 4. Requirements

- Do not invent important business requirements.
- Distinguish facts, assumptions, recommendations, and unknowns.
- Identify ambiguity, missing rules, edge cases, and open questions.
- Do not implement major functionality while its scope is materially unclear.

## 5. Architecture

- Architecture decisions must be explicit.
- Prefer the simplest architecture that satisfies actual requirements.
- Do not add infrastructure or abstractions speculatively.
- Document major architectural decisions before implementation.

## 6. Database

- Schema changes must be deliberate and migration-based.
- Do not modify production data directly unless explicitly authorized.
- Consider keys, constraints, relationships, indexes, and data integrity.

## 7. API

- Keep API contracts explicit and consistent.
- Validate inputs.
- Define meaningful error responses.
- Consider authentication and authorization requirements.

## 8. Testing

- New business logic should have appropriate automated tests.
- Run relevant tests after meaningful implementation changes.
- Never claim tests pass without actually running them.

## 9. Debugging

When something fails:

1. Reproduce the problem.
2. Collect evidence.
3. Identify the failure boundary.
4. Form a hypothesis.
5. Test the hypothesis.
6. Fix the root cause.
7. Run regression tests.

Avoid repeated guess-and-patch behavior.

## 10. Verification

A task is not complete merely because code has been written.

Before declaring completion, verify:

- requirements are satisfied;
- relevant tests were executed;
- important failures were resolved;
- no obvious regressions remain;
- documentation/state is updated when necessary.

## 11. Git

- Never commit secrets.
- Keep commits focused and meaningful.
- Do not rewrite history unless explicitly requested.
- Preserve a clean and understandable project history.

## 12. Security

- Never hardcode credentials or secrets.
- Treat user input as untrusted.
- Follow least-privilege principles.
- Do not expose sensitive information in logs or API responses.

## 13. Current Bootstrap Constraint

WeddingOS is currently being bootstrapped.

Until Discovery has started and the product/technical direction is sufficiently understood:

- do not implement application features;
- do not choose a technology stack based only on personal preference;
- do not scaffold production source code;
- focus on preparing the development workflow and project state.

## 14. Completion Behavior

At the end of substantial work, summarize:

- what was done;
- files created or changed;
- decisions made;
- validation performed;
- open questions;
- recommended next phase.
