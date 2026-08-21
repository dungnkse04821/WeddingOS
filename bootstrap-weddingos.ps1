$ErrorActionPreference = "Stop"

# ============================================================
# WeddingOS - Agentic Development Bootstrap
# ============================================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " WeddingOS Agentic Development Bootstrap" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# 1. Verify current directory
# ------------------------------------------------------------

$projectRoot = (Get-Location).Path
$projectName = Split-Path $projectRoot -Leaf

if ($projectName -ne "WeddingOS") {
    Write-Host "WARNING: Current folder is '$projectName', not 'WeddingOS'." -ForegroundColor Yellow
    $answer = Read-Host "Continue anyway? (y/N)"

    if ($answer -ne "y") {
        Write-Host "Cancelled." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Project root: $projectRoot" -ForegroundColor Gray
Write-Host ""

# ------------------------------------------------------------
# 2. Create directories
# ------------------------------------------------------------

$directories = @(
    ".agents",
    ".agents\agents",
    ".agents\agents\project-agent",
    ".agents\skills",
    ".agents\skills\project-bootstrap",
    ".agents\skills\project-orchestrator",
    ".agents\skills\discovery",
    "docs"
)

foreach ($directory in $directories) {
    $path = Join-Path $projectRoot $directory

    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "[CREATED DIR]  $directory" -ForegroundColor Green
    }
    else {
        Write-Host "[EXISTS DIR]   $directory" -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------
# Helper function: write file only if it does not exist
# ------------------------------------------------------------

function New-ProjectFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $fullPath = Join-Path $projectRoot $RelativePath

    if (Test-Path $fullPath) {
        Write-Host "[SKIPPED]      $RelativePath (already exists)" -ForegroundColor Yellow
        return
    }

    $parent = Split-Path $fullPath -Parent

    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Set-Content -Path $fullPath -Value $Content -Encoding UTF8

    Write-Host "[CREATED FILE] $RelativePath" -ForegroundColor Green
}

# ------------------------------------------------------------
# 3. AGENTS.md
# ------------------------------------------------------------

New-ProjectFile `
    -RelativePath "AGENTS.md" `
    -Content @'
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
'@

# ------------------------------------------------------------
# 4. Custom primary agent
# ------------------------------------------------------------

New-ProjectFile `
    -RelativePath ".agents\agents\project-agent\agent.md" `
    -Content @'
---
name: project-agent
description: Primary software development agent for WeddingOS. Use as the main project worker for substantial product, architecture, implementation, testing, and delivery tasks.
model: inherit
---

# Primary Project Agent

You are the primary software development agent for WeddingOS.

Your responsibility is to manage work according to the project's development lifecycle rather than immediately writing code.

## Mandatory Startup Behavior

Before any substantial task:

1. Inspect the repository.
2. Read `AGENTS.md`.
3. Read `docs/project-state.md`.
4. Determine the current project phase.
5. Consult the `project-orchestrator` skill.
6. Select only the specialist skills needed for the current phase.

## Workflow Discipline

Use this lifecycle:

1. Bootstrap
2. Discovery
3. Requirements
4. Product Planning
5. Architecture
6. Scaffolding
7. Implementation
8. Testing
9. Debugging
10. Review
11. Verification
12. Delivery

Do not skip a phase when doing so would create material uncertainty.

## Important

Do not treat the folder numbering of skills as workflow priority.

Workflow priority comes from:

- project state;
- project rules;
- orchestrator policy;
- current task.

## User Approval

Request clarification or approval when:

- requirements are materially ambiguous;
- scope is unclear;
- a major architecture decision is required;
- a technology choice materially affects the project;
- a destructive or high-risk operation is proposed.

## Completion

Never report success without evidence.

Always distinguish:

- completed work;
- assumptions;
- unresolved issues;
- next recommended step.
'@

# ------------------------------------------------------------
# 5. Project bootstrap skill
# ------------------------------------------------------------

New-ProjectFile `
    -RelativePath ".agents\skills\project-bootstrap\SKILL.md" `
    -Content @'
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
'@

# ------------------------------------------------------------
# 6. Project orchestrator skill
# ------------------------------------------------------------

New-ProjectFile `
    -RelativePath ".agents\skills\project-orchestrator\SKILL.md" `
    -Content @'
---
name: project-orchestrator
description: Coordinate the WeddingOS software development lifecycle and determine the current phase, required workflow, approvals, and specialist skills. Use before substantial project work, especially when starting a new feature, project phase, or end-to-end development task.
---

# Project Orchestrator

## Role

Act as the workflow routing layer for WeddingOS.

You do not replace specialist skills.

You determine:

- what phase the project is in;
- what must happen next;
- which specialist skills are relevant;
- whether the project may advance;
- whether the user must clarify or approve something.

## First Read

Before deciding what to do:

1. Read `AGENTS.md`.
2. Read `docs/project-state.md`.
3. Inspect the repository when the state may be stale.
4. Inspect the user's current request.

## Development Phases

### 0. BOOTSTRAP
Prepare project rules, state, and agent workflow.

### 1. DISCOVERY
Understand the user problem, target users, context, goals, constraints, and success criteria.

### 2. REQUIREMENTS
Convert discovery into implementation-ready requirements, business rules, user stories, acceptance criteria, validations, and edge cases.

### 3. PRODUCT-PLANNING
Define MVP scope, priorities, dependencies, risks, and future backlog.

### 4. ARCHITECTURE
Define system architecture, boundaries, integrations, technical decisions, and major trade-offs.

### 5. SCAFFOLDING
Create the project skeleton and development infrastructure according to approved architecture.

### 6. IMPLEMENTATION
Implement approved tasks and features.

### 7. TESTING
Execute the appropriate automated and manual validation.

### 8. DEBUGGING
Investigate failures using evidence and root-cause analysis.

### 9. REVIEW
Review correctness, maintainability, performance, security, and requirements compliance.

### 10. VERIFICATION
Confirm that the requested outcome is actually achieved and evidence supports completion.

### 11. DELIVERY
Prepare documentation, release, deployment, or handoff.

## Transition Rules

Typical gates:

- Discovery -> Requirements when the problem and target users are sufficiently understood.
- Requirements -> Product Planning when core requirements are sufficiently defined.
- Product Planning -> Architecture when MVP scope is sufficiently established.
- Architecture -> Scaffolding when major technical decisions are settled.
- Scaffolding -> Implementation when the project can build/run and structure is validated.
- Implementation -> Testing when the planned change is implemented.
- Testing -> Debugging when failures exist.
- Testing -> Review when relevant tests pass.
- Review -> Verification when material findings are resolved.
- Verification -> Delivery when completion evidence is sufficient.

## Skill Routing Policy

When multiple skills overlap:

1. Prefer a project-specific process skill.
2. Prefer an explicitly requested skill.
3. Prefer the narrower, more task-specific trigger.
4. Do not execute multiple equivalent process skills.
5. Combine skills only when their responsibilities are complementary.

## New Project Rule

For a brand-new project, do not jump directly to scaffolding.

Default sequence:

Bootstrap
-> Discovery
-> Requirements
-> Product Planning
-> Architecture
-> Scaffolding
-> Implementation

## State Management

After meaningful phase changes, update `docs/project-state.md`.

Never silently change the recorded project phase.

## Output

At each orchestration decision, state:

- Current phase
- Evidence
- Next action
- Required skill(s)
- Approval/clarification needed
'@

# ------------------------------------------------------------
# 7. Discovery skill
# ------------------------------------------------------------

New-ProjectFile `
    -RelativePath ".agents\skills\discovery\SKILL.md" `
    -Content @'
---
name: discovery
description: Explore and clarify a software product idea before detailed requirements are created. Use when a project is new, the product problem is vague, or the user needs to define users, goals, pain points, constraints, and success criteria.
---

# Product Discovery

## Objective

Transform an initial product idea into a clearly understood problem and opportunity.

## Do Not Start With Code

During Discovery, focus on understanding the product.

Do not:

- select frameworks merely by habit;
- design implementation details prematurely;
- invent requirements;
- scaffold application code.

## Explore

Identify:

1. Problem
2. Target users
3. User context
4. Current alternatives or workarounds
5. Pain points
6. Desired outcomes
7. Constraints
8. Assumptions
9. Success criteria
10. Open questions

## Distinguish Information

Clearly separate:

- facts provided by the user;
- assumptions;
- recommendations;
- unknowns.

Do not present assumptions as confirmed requirements.

## Question Strategy

Ask focused questions only where the answer would materially affect:

- product scope;
- target users;
- core workflow;
- business rules;
- architecture;
- security;
- data model;
- MVP definition.

Avoid asking unnecessary questions merely to collect detail.

## Output

Produce:

### Problem Statement
What problem the product solves.

### Target Users
Primary and secondary users.

### Goals
What success looks like.

### Pain Points
Current friction or unmet needs.

### Core User Outcomes
What users should be able to accomplish.

### Constraints
Business, technical, operational, or organizational constraints.

### Assumptions
Things currently believed but not yet validated.

### Success Criteria
How the product will be judged.

### Open Questions
Questions that must be resolved before Requirements or Planning.

## Transition

Discovery is complete when the problem, users, goals, major constraints, and core outcomes are sufficiently understood to begin Requirements analysis.

Update `docs/project-state.md` when the phase changes.
'@

# ------------------------------------------------------------
# 8. Project state
# ------------------------------------------------------------

New-ProjectFile `
    -RelativePath "docs\project-state.md" `
    -Content @'
# WeddingOS Project State

## Current Phase

BOOTSTRAP

## Project Status

New project repository. No application source code has been implemented yet.

## Product Understanding

Not started.

## Technology Stack

Not decided.

## Architecture

Not started.

## MVP

Not defined.

## Active Decisions

None.

## Open Questions

- What problem should WeddingOS solve first?
- Who are the primary users?
- What is the MVP?
- What business workflows must be supported?
- What technical constraints exist?
- Which technology stack should be selected?

## Constraints

- Do not implement application features during bootstrap.
- Do not lock in a technology stack before Discovery and technical evaluation.
- Preserve Git history and project rules.

## Next Phase

DISCOVERY

## Recommended Next Action

Start Product Discovery for WeddingOS.
'@

# ------------------------------------------------------------
# 9. Final validation
# ------------------------------------------------------------

Write-Host ""
Write-Host "Validating bootstrap structure..." -ForegroundColor Cyan

$requiredFiles = @(
    "AGENTS.md",
    ".agents\agents\project-agent\agent.md",
    ".agents\skills\project-bootstrap\SKILL.md",
    ".agents\skills\project-orchestrator\SKILL.md",
    ".agents\skills\discovery\SKILL.md",
    "docs\project-state.md"
)

$allValid = $true

foreach ($file in $requiredFiles) {
    $path = Join-Path $projectRoot $file

    if (Test-Path $path) {
        Write-Host "[OK] $file" -ForegroundColor Green
    }
    else {
        Write-Host "[MISSING] $file" -ForegroundColor Red
        $allValid = $false
    }
}

Write-Host ""

if ($allValid) {
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host " Bootstrap completed successfully!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
}
else {
    Write-Host "Bootstrap completed with missing files." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Reload/reopen WeddingOS in Antigravity."
Write-Host "2. Open the Agent panel."
Write-Host "3. Select the project-agent if it appears."
Write-Host "4. Ask the agent to verify the bootstrap."
Write-Host "5. Do not implement application code yet."
Write-Host ""