---
name: product-planning
description: Converts validated requirements into a coherent MVP scope, priorities, dependencies, release slices, risks, and product roadmap. Use after Requirements when the project needs to decide what to build first and what to defer before architecture and implementation planning.
---

# Product Planning

## Objective

Turn validated requirements into a focused, coherent product plan.

The goal is not to maximize the number of features.

The goal is to define the smallest valuable product scope that solves the primary user problem while remaining internally coherent.

## Entry Conditions

Use this skill when:

- Discovery is complete enough.
- Requirements are sufficiently defined.
- The project needs an MVP, priorities, release scope, sequencing, or roadmap.

Do not use this skill to compensate for unclear requirements.

## Source of Truth

Before planning:

1. Read `AGENTS.md` if present.
2. Read `docs/project-state.md` if present.
3. Read `docs/discovery.md` if present.
4. Read `docs/requirements.md` or equivalent requirements artifacts.
5. Read relevant constraints and decisions.

## Planning Principles

### 1. Solve the Core Problem First

Every MVP feature should have a clear relationship to the primary user outcome.

### 2. Prefer Coherent Scope Over Feature Count

Do not select isolated features that cannot form a usable user journey.

### 3. Separate MVP From Future Vision

Long-term product vision may be broad.

MVP scope must remain intentionally narrow.

### 4. Do Not Prioritize by Technical Convenience Alone

User value, risk, dependency, and learning value matter.

### 5. Avoid Premature Architecture

Product Planning may identify technical constraints and dependencies, but it must not choose a detailed technical architecture without entering the Architecture phase.

## Prioritization

Classify capabilities using:

- Must Have
- Should Have
- Could Have
- Out of Scope for current release

Use MoSCoW as a communication aid, not as an automatic scoring algorithm.

For important decisions, also consider:

- user value;
- business value;
- dependency;
- implementation risk;
- uncertainty;
- validation / learning value;
- operational complexity.

## MVP Definition

An MVP should:

- serve the primary target user;
- solve the primary problem;
- support at least one complete core user journey;
- be small enough to deliver and validate;
- exclude capabilities that do not materially contribute to that core journey.

For each MVP capability, document why it is necessary.

## Dependency Analysis

Identify dependencies between capabilities.

Example:

Guest invitation sharing
depends on:
- wedding creation;
- guest management;
- share/access model.

Dependencies may determine sequencing even when two capabilities have similar priority.

## Release Slicing

Where useful, define slices such as:

### Foundation
Minimum product structure required for meaningful use.

### MVP
Smallest externally useful release.

### Post-MVP
High-value capabilities intentionally deferred.

### Future
Ideas that belong to the long-term vision but should not influence current implementation unnecessarily.

## Risk Analysis

Identify product risks such as:

- unclear user behavior;
- domain complexity;
- regulatory/privacy constraints;
- dependency on external services;
- high operational cost;
- assumptions not yet validated.

Do not convert risks directly into engineering solutions. Carry significant risks into Architecture for technical treatment.

## Required Output

Prefer creating or updating `docs/product-plan.md`.

Recommended structure:

# Product Plan

## Product Goal

## Primary User

## MVP Definition

## Prioritized Capabilities

### Must Have

### Should Have

### Could Have

### Out of Scope

## Core User Journey

## Dependencies

## Release Slices

## Risks

## Assumptions

## Open Decisions

## Future Backlog

## Architecture Inputs

List product decisions and constraints that Architecture must account for without prescribing the technical solution.

## Phase Gate

Product Planning may move to Architecture only when:

- the MVP boundary is clear;
- the primary user journey is coherent;
- critical dependencies are understood;
- explicitly out-of-scope capabilities are documented;
- product-level risks and unresolved decisions are visible.

Do not silently advance the phase.

When the phase changes, update `docs/project-state.md`.

## Completion Report

At the end, report:

- MVP scope;
- major deferred items;
- dependencies;
- risks;
- remaining decisions;
- whether the product plan is mature enough for Architecture.
