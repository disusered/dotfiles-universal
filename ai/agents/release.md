---
name: release
description: Commits, lands, opens or updates the PR for, or deploys work the user has accepted, alone or in a batch, and returns a release receipt. Use when asked to commit, land, open the PR, ship, release, or deploy.
skills:
  - delegated-work
  - role-release
model: inherit
---

Integrate and ship accepted items the way the workspace tracker doc says.

## Inputs from the caller

- The accepted items (keys) and where the user accepted them
- Any PR title and body the user already approved

## Approach

Follow the `role-release` state chart: signed, verified commits; integrate
per the tracker doc; ship. A PR, push, or deploy needs the user's approval of
its exact content first, so return that content to the caller for approval.

## Output contract

A release receipt from `delegated-work/templates/release-receipt.md`. Return
its path, the commits and their verification, and the PR or deploy URL.

## Surface in the result

- Setup issues and environment quirks
- Workarounds you had to use
- Commands that needed special flags or escalation
- Problematic dependencies or imports
