# CONTEXT.md — GuildOps Domain Model & Constraints

This document captures the problem space, domain vocabulary, and known technical limitations for GuildOps, plus how we plan to work around each limitation. Update this file as assumptions are validated or invalidated during prototyping.

## Problem Space (research summary)

Source: internal research pass (session research report, Sept 2026) citing official Blizzard forum threads:

- The "new Guild UI" wiped **persistent officer notes**, breaking guild DKP/loot-tracking systems that stored data there (forum: "Classic Era Guild Tab and Guild Chat Issues").
- Players report entire guilds disbanding over the UI change; requests for a legacy `/groster`-style toggle exist but are unfulfilled (forum: "New Guild UI is terrible and broken").
- Guild chat latency increased alongside the UI change.
- The addon ecosystem response is small and unproven: ~9-21 total GitHub repos touch "guild roster" or "guild bank" tooling. The most complete option found (Guild-Paragon) is retail-only, closed-source, and has no confirmed adoption metrics.
- Mail's incumbent addon (Postal) has lost primary-author maintenance; the community keeps it alive via narrow compatibility-patch forks, not feature overhauls. (Related problem, tracked separately — not in GuildOps v1 scope.)

## Domain Vocabulary

| Term | Meaning |
|---|---|
| **Officer Note** | A short free-text field per guild member, historically used by officers to track DKP balances, loot history, or behavioral notes. Wiped/unreliable in the new Guild UI. |
| **Roster** | The list of guild members with rank, class, level, online status, and notes. |
| **Guild Bank Ledger** | A chronological record of deposits/withdrawals of items and gold from the guild bank, attributable to a specific member and timestamp. |
| **DKP** | "Dice/Dragon Kill Points" — a loot-priority point system many guilds run *on top of* officer notes or external spreadsheets. GuildOps stores data DKP systems need; it does not implement DKP logic itself. |
| **SavedVariables** | WoW's addon persistence mechanism — a Lua table serialized to disk per-account/per-character. This is our only durable storage; there is no addon-side network/database access. |

## Known Technical Limitations (WoW Addon API)

WoW addons run in a sandboxed Lua environment with deliberate restrictions. These directly shape what GuildOps can and cannot do:

1. **No direct read/write access to Blizzard's native guild officer-note storage guarantees.** The API (`GuildRosterSetOfficerNote` / `C_GuildInfo` equivalents) is guild-rank-permission-gated and historically has been the exact surface that broke. **Workaround:** GuildOps maintains its *own* parallel, addon-owned note store in SavedVariables, synced opportunistically when officers are online, rather than depending solely on Blizzard's native note field surviving.
2. **SavedVariables are per-account or per-character, not shared in real time across guild members.** There is no built-in addon-to-addon network layer beyond the game's own addon-message channels (chat-based, rate-limited, and restricted in size). **Workaround:** Use in-game addon channel messages (e.g., guild chat addon-message channel) to broadcast/sync note and ledger updates between officers running GuildOps, with conflict resolution by "last write wins + timestamp" and manual review for conflicts. This means sync only happens when multiple officers are online simultaneously — an accepted v1 limitation.
3. **No native guild-bank transaction API access beyond what Blizzard exposes via the guild bank log UI (limited history depth, rate-limited queries).** **Workaround:** GuildOps polls/scrapes the existing Blizzard guild-bank-log UI when a user with bank access opens it, and appends new entries to our own persistent ledger — extending effective history depth beyond Blizzard's built-in limit over time, rather than replacing the query mechanism.
4. **Addon API surface is actively being restricted in current patches** (e.g., 12.1 changes to filtered aura data, in-combat addon messaging) — this is a combat-addon-specific restriction from our broader research, but signals Blizzard's general direction of tightening addon capabilities. **Workaround:** avoid designing GuildOps around any addon-messaging behavior that resembles automation/combat assistance; keep our addon-message usage narrowly scoped to social/roster data sync, which is a lower-risk category historically.
5. **WoW Forever is a new client/build (beta as of Sept 2026)** with its own reported bugs: SavedVariables not persisting across restarts (a client bug, since patched by Blizzard per community reports), Lua errors in certain UI interactions, and a modern/retail-style addon API rather than the old Classic Era one. **Workaround:** target WoW Forever's addon API directly (do not assume Classic Era API compatibility); track Blizzard's beta known-issues threads and build defensively (e.g., write-then-verify SavedVariables patterns) until the platform stabilizes post-launch (targeted Nov 2026).
6. **No cross-version guarantee.** Classic Era, Retail, and WoW Forever have diverging Guild UI APIs and versions. **Workaround:** v1 targets WoW Forever only (see README goals); abstract any Blizzard API calls behind a thin compatibility layer from day one so Classic Era/Retail support later doesn't require a rewrite.

## Bootstrap Template Research (issue #2 resolution)

### Framework survey

- **Ace3 remains the most practical full-stack addon framework** for GuildOps' likely needs: `AceAddon-3.0` for lifecycle/modules, `AceDB-3.0` for profile-backed SavedVariables, `AceConfig-3.0` + `AceGUI-3.0` for options UIs, and `AceComm-3.0` for addon-message sync.
- **Lighter alternatives exist, but the template ecosystem is weaker there.** Native Blizzard APIs plus hand-rolled SavedVariables/slash-command code are viable for a small bootstrap, and author-specific libraries/frameworks exist, but none of the starter repos surveyed showed stronger WoW Forever alignment than a selective Ace3 approach.
- **Implication for GuildOps:** start with the smallest addon skeleton that preserves folder/TOC/package discipline, then add only the Ace3 pieces we actually need instead of inheriting a large retail-focused boilerplate wholesale.

### Template comparison

| Repo | Project layout / TOC conventions | SavedVariables / versioning pattern | Options / slash boilerplate | Maintenance / client notes | WoW Forever note | GuildOps fit |
|---|---|---|---|---|---|---|
| `layday/wow-addon-template` | Single `Addon/` folder containing `Addon.toc` + `Addon.lua`; `pkgmeta.yaml` pulls `LibStub` and `AceAddon-3.0` into `Addon/libs`; TOC loads libs before core. | No `SavedVariables` entry in the sample TOC, so there is no schema, version field, or migration example yet. | No options panel or slash-command boilerplate; sample only creates an `AceAddon` and prints in `OnInitialize()`. | Mature packaging/release-oriented template, but the sample TOC still targets interface `90002`, so it is a dated retail baseline rather than a current-client skeleton. | No explicit WoW Forever support found; compatibility is unverified. | **Best reference for minimal structure**, but it needs GuildOps-specific persistence, slash commands, and sync scaffolding added manually. |
| `tshallenberger/wow-addon-template` | `src/` folder with `WowAddonTemplate.toc`, `embeds.xml`, XML/UI stub, and a committed `src/Libs/` tree containing Ace3 plus extras such as `LibDataBroker` and range-check libraries. | Declares `## SavedVariables: WowAddonTemplateDB` and initializes `AceDB-3.0` profile defaults, but does not include a schema version or migration path. | Loads `AceConsole`, `AceEvent`, and `AceHook`, but ships no ready-made options table/panel and no actual slash-command registration. | Updated in 2026, but still a generic placeholder template with `{{INTERFACE}}`/`{{VERSION}}` tokens and a heavier embedded-lib bundle than GuildOps needs on day one. | No explicit WoW Forever support found; compatibility is unverified. | Useful as an **Ace3 embed/AceDB reference**, but probably too heavyweight to copy directly. |
| `kimgod1142/wow-addon-template` | Named addon folder with separate core/UI/options/localization files and a straightforward `.toc`; includes `.pkgmeta` and GitHub release workflow. | Declares a single flat `ADDON_NAMEdb` table and applies defaults manually; no schema version or migration example. | Strongest boilerplate of the three for a custom options window and slash commands (`/NAME`, `/NAME config`, `/NAME test`, `/NAME reset`). | Active in 2026 and more feature-complete, but clearly aimed at a retail-style spell/UI addon (`## Interface: 120001`, `C_Spell`, row-pool UI helpers) rather than guild-data tooling. | No explicit WoW Forever support found; compatibility is unverified. | Good **native-API options/slash reference**, but too UI-specific to adopt wholesale. |

### Recommendation

Use a **minimal from-scratch bootstrap modeled after `layday/wow-addon-template`'s folder/package discipline**, then selectively add only the Ace3 modules GuildOps clearly benefits from:

- `AceAddon-3.0` for lifecycle/module structure
- `AceDB-3.0` for SavedVariables defaults/profiles
- `AceComm-3.0` when officer-note / ledger sync begins

Defer `AceConfig-3.0` / `AceGUI-3.0` until we know whether GuildOps should expose a Blizzard Settings panel, a custom guild-frame augmentation, or both.

This gives us a clean starting point while preserving the project-specific requirements that none of the surveyed templates solve yet:

- a **versioned SavedVariables schema with explicit migrations**
- a **thin Blizzard API compatibility layer** for WoW Forever-specific guild APIs
- a **guild-data-first architecture** rather than a combat/UI-heavy sample addon

No surveyed template advertised **explicit WoW Forever compatibility**, so the bootstrap spike must still validate the final TOC/interface value and guild-related API calls against the WoW Forever client directly.

## Open Questions (to resolve during research/prototyping sub-issues)

- Does WoW Forever's Guild UI expose different/broken officer-note APIs than Classic Era, or does it inherit Retail's version wholesale?
- What is the practical addon-message rate limit for guild-wide roster/ledger sync at scale (e.g., 200+ member guilds)?
- What does a minimal, non-intrusive UI look like — a standalone panel, or an overlay/augmentation of the existing Blizzard Guild UI frame?

## Non-Functional Constraints

- **No external network calls** — WoW addons cannot make HTTP requests. All "sync" is via in-game addon-message channels only.
- **Performance:** must not cause noticeable frame hitches when opening guild UI/bank frames, especially in large guilds.
- **Data safety:** SavedVariables corruption or reset must not silently lose officer notes — always keep an internal versioned backup/migration path.
