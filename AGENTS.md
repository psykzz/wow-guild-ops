# AGENTS.md — Working Conventions for GuildOps

This file guides both human contributors and AI coding agents working in this repository.

## Project Summary

GuildOps is a World of Warcraft addon (Lua) for guild management: persistent officer notes, roster sorting, and a guild bank transaction ledger. Initial target platform is **WoW Forever**. See `README.md` for goals/non-goals and `CONTEXT.md` for domain model and known API limitations — read `CONTEXT.md` before making architectural decisions, since several design choices exist specifically to work around WoW addon API constraints.

## Repository Conventions

- **Language:** Lua (WoW addon API, likely Ace3 framework once selected — see planning issue for template research).
- **Addon folder/TOC naming:** The root folder name must match the `.toc` file name for WoW to load it (e.g., `GuildOps.toc` inside a `GuildOps/` folder, or `wow-guild-ops.toc` — finalize during setup and keep consistent).
- **SavedVariables schema:** Any change to the SavedVariables table structure must include a version number and a migration path (see `CONTEXT.md` non-functional constraints — never silently lose officer notes or ledger data).
- **No network calls:** Do not attempt HTTP/external requests — not supported by the WoW addon sandbox. All cross-client sync happens via in-game addon-message channels only.
- **Commit messages:** Concise, no co-author trailers, no AI-agent attribution.
- **Issues:** The master project plan lives in a pinned GitHub issue; work is broken into sub-issues linked from it. Keep sub-issues scoped (one investigation or one feature per issue).

## Development Workflow

1. Check the master plan issue and its open sub-issues before starting work.
2. Research/prototyping sub-issues should produce concrete findings (template repo comparisons, API behavior notes, screenshots/mockups) posted back to the issue — not just code.
3. Update `CONTEXT.md`'s "Open Questions" section as questions get resolved during research.
4. Validate any addon-API-dependent behavior against WoW Forever specifically first; note any Classic Era/Retail divergence as a follow-up rather than blocking v1.

## Testing / Validation

- No formal test framework is standard for WoW addons; validation is manual in-client (load addon in WoW Forever, verify via `/reload` and in-game actions).
- Use `BugSack`/`BugGrabber` (already present in this AddOns folder) to catch Lua errors during manual testing.
- Until in-repo tooling is set up, describe manual test steps taken in PR descriptions.

## Things to Avoid

- Don't design features that resemble combat automation/assistance (see `CONTEXT.md` limitation #4) — Blizzard is actively restricting that category of addon API access; GuildOps should stay clearly in the social/roster/economy category.
- Don't assume Classic Era and WoW Forever share identical Guild UI APIs — verify per-platform.
- Don't replace the entire Blizzard Guild UI frame outright in v1 — augment/overlay it until the core data layer (notes, ledger) is proven stable.
