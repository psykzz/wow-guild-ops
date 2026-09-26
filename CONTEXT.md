# CONTEXT.md — GuildOps Domain Model & Constraints

This document captures the problem space, domain vocabulary, and known technical limitations for GuildOps, plus how we plan to work around each limitation. Update this file as assumptions are validated or invalidated during prototyping.

## Problem Space (research summary)

Source: internal research pass (session research report, Sept 2026) plus WoW Forever beta/API follow-up (26 Sept 2026) citing official Blizzard forum threads, Blizzard UI/API source mirrors, and addon-maintainer notes:

- The "new Guild UI" wiped **persistent officer notes**, breaking guild DKP/loot-tracking systems that stored data there (forum: "Classic Era Guild Tab and Guild Chat Issues").
- Players report entire guilds disbanding over the UI change; requests for a legacy `/groster`-style toggle exist but are unfulfilled (forum: "New Guild UI is terrible and broken").
- Guild chat latency increased alongside the UI change.
- The addon ecosystem response is small and unproven: ~9-21 total GitHub repos touch "guild roster" or "guild bank" tooling. The most complete option found (Guild-Paragon) is retail-only, closed-source, and has no confirmed adoption metrics.
- Mail's incumbent addon (Postal) has lost primary-author maintenance; the community keeps it alive via narrow compatibility-patch forks, not feature overhauls. (Related problem, tracked separately — not in GuildOps v1 scope.)
- Current WoW Forever-targeted addons and Blizzard's generated API docs both use modern/retail-style namespaces such as `C_GuildInfo`, `C_ChatInfo`, and `C_GuildBank`, not a Classic-Era-only API surface ([GuildInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/GuildInfoDocumentation.lua), [ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua), [GuildBankDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/GuildBankDocumentation.lua), [Olympus roster/comm code](https://github.com/dnl-gentile/olympus-addon)).
- Officer-note reads still exist via roster APIs/permissions, but note writes on the modern branch moved to `C_GuildInfo.SetNote(guid, note, isPublic)` rather than the old index-based globals ([DEPRECATED_APIS.md](https://github.com/nate8282/GuildNoteUpdater/blob/main/DEPRECATED_APIS.md)).
- Addon authors currently report that `C_GuildInfo.SetNote` can be silently blocked/protected on WoW 12.x, making automated guild-note writes unreliable even when the UI still exposes note fields ([GuildNoteUpdater README](https://github.com/nate8282/GuildNoteUpdater/blob/main/README.md), [Blizzard feedback thread](https://eu.forums.blizzard.com/en/wow/t/feedback-guild-note-apis-guildrostersetpublicnote-cguildinfosetnote-and-secret-values/615202)).
- The default guild-bank UI still queries logs via `QueryGuildBankLog`, `GetNumGuildBankTransactions`, and `GetGuildBankTransaction`; current community ledger addons describe the *observed/current* retained history as only **about 25 entries per tab**, which rolls over quickly in active guilds, but that depth should still be re-verified in-client on Forever itself ([Blizzard_GuildBankUI.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GuildBankUI/Mainline/Blizzard_GuildBankUI.lua), [GuildBankLedger README](https://github.com/RussellFeinstein/guild-bank-ledger/blob/main/README.md)).
- Modern addon-message APIs on this branch expose explicit registration and send-result failures (duplicate/invalid prefix, throttle, not-in-guild, lockdown, target offline), so comms must be treated as a fallible transport rather than a fire-and-forget bus ([ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua), [ChatConstantsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatConstantsDocumentation.lua)).
- WoW Forever beta's SavedVariables reset bug was real during early beta, but current workaround repos now say Blizzard has fixed normal persistence on current builds; guild/UI permission bugs are still being reported, so the exact target build still needs verification ([WTFix README](https://github.com/eggntoast/WTFix-Public/blob/main/README.md), [ForeverSVFix README](https://github.com/nobewayo/ForeverSVFix/blob/main/README.md), [WoW Forever beta known issues](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-known-issues-september-17/2352687), [guild officer UI bug report](https://us.forums.blizzard.com/en/wow/t/guild-interface-possible-bug/2335073), [blank guild UI/permissions report](https://us.forums.blizzard.com/en/wow/t/no-permissions-and-blank-ui-for-guild-officers-and-gm/2207011)).

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

1. **Blizzard's native guild-note surface is still readable but not trustworthy for automated writes.** On modern/Forever-style clients, officer/public note reads are still exposed through guild-roster APIs and permission checks, but writes now route through `C_GuildInfo.SetNote(guid, note, isPublic)` and current 12.x addon evidence says those writes may be silently blocked from addon code. **Workaround:** GuildOps maintains its *own* parallel, addon-owned note store in SavedVariables, synced opportunistically when officers are online, rather than depending on Blizzard note writes succeeding.
2. **SavedVariables are per-account or per-character, not shared in real time across guild members.** There is no built-in addon-to-addon network layer beyond the game's own addon-message channels (chat-based, rate-limited, and restricted in size). **Workaround:** Treat addon messages as an eventually-consistent transport, not shared storage:
   - Addon-message prefixes are capped at 16 characters and each message payload is capped at 255 bytes. Anything larger must be chunked and reassembled; this is common enough that AceComm-3.0 already does it on top of `CHAT_MSG_ADDON`.
   - Bandwidth is explicitly throttled. ChatThrottleLib exists to avoid disconnects from over-sending, and its own conservative defaults assume roughly ~800 bytes/sec steady-state output with a ~4 KB burst cap before backing off. GuildOps should assume real throughput is lower whenever normal chat or other addons are active.
   - A full 200+ member officer-note baseline is feasible, but only as bootstrap/recovery traffic. Even a modest serialized snapshot (~12-20 KB once names, notes, and metadata are included) turns into dozens of 255-byte chunks and likely takes many seconds to tens of seconds to drain through chat throttles. Normal edits should therefore ship as tiny per-record deltas, not full-table rebroadcasts.
   - Compression is feasible inside the addon sandbox because pure-Lua libraries such as LibDeflate are commonly embedded by other addons. It is most useful for bulk snapshots and ledger catch-up, not single-note edits where chunk/header overhead dominates.
   - Prior art suggests keeping the steady-state protocol small. EPGP's `LibGuildStorage` uses guild-wide addon messages only as invalidation markers (`CHANGES_PENDING` / `CHANGES_FLUSHED`) and then re-reads the roster, while larger guild-sync systems such as Guild Paragon add explicit chunk numbering, full-state catch-up, missing-chunk repair, and bandwidth-aware pacing.
   - Refine conflict resolution: plain "last write wins + local timestamp" is too weak because of clock skew, equal timestamps, and officers coming back online after missing updates. v1 should prefer per-record deltas carrying `{updatedAt, authorId, authorSeq}` (or an equivalent Lamport-style tuple), use the timestamp only as the first ordering key, break ties deterministically by author/sequence, and trigger delta/full resync when a client rejoins with stale state. Manual review remains the fallback for truly simultaneous conflicting edits.
   - Sync still only happens while multiple officers are online simultaneously — an accepted v1 limitation — so offline officers must request catch-up from peers on login rather than assuming passive convergence.
3. **Guild-bank transaction visibility is limited to Blizzard's bank-log APIs and shallow retained history.** Forever's modern client still exposes `QueryGuildBankLog`, `GetNumGuildBankTransactions`, and `GetGuildBankTransaction` via the default UI, but current addon authors only *report/observe* retained history of roughly 25 entries per tab, and Blizzard does not publish a friendly high-frequency polling contract. **Workaround:** GuildOps captures logs when the bank UI is opened (and at a conservative re-scan cadence if needed), then appends new entries to our own persistent ledger to extend history depth over time rather than replacing Blizzard's query mechanism.
4. **Addon API surface is actively being restricted in current patches** (e.g., 12.1 changes to filtered aura data, in-combat addon messaging) — this is a combat-addon-specific restriction from our broader research, but signals Blizzard's general direction of tightening addon capabilities. **Workaround:** avoid designing GuildOps around any addon-messaging behavior that resembles automation/combat assistance; keep our addon-message usage narrowly scoped to social/roster data sync, which is a lower-risk category historically.
5. **WoW Forever is a new client/build (beta as of Sept 2026)** with its own reported bugs and branch-specific behavior: a SavedVariables persistence bug existed during beta but is now reported fixed on current builds, guild UI/officer permission regressions are still being reported, and the addon API surface is modern/retail-style rather than Classic Era's older shape. **Workaround:** target WoW Forever's addon API directly (do not assume Classic Era API compatibility); verify behavior on the exact Forever build we support; and build defensively around note-write failure, roster refresh timing, and SavedVariables verification until the platform stabilizes post-launch.
6. **No cross-version guarantee.** Classic Era, Retail, and WoW Forever have diverging Guild UI APIs and versions. **Workaround:** v1 targets WoW Forever only (see README goals); abstract any Blizzard API calls behind a thin compatibility layer from day one so Classic Era/Retail support later doesn't require a rewrite.
7. **Addon-message sends are explicitly throttleable/failable on the modern client branch.** The modern `C_ChatInfo` API reports failures such as invalid prefix, guild/group membership errors, chat lockdown, and transport throttling instead of guaranteeing delivery. **Workaround:** register prefixes early, check send results, batch/queue sync traffic, and treat guild sync as eventually consistent rather than real time.

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

- On the exact WoW Forever build targeted for v1, is `C_GuildInfo.SetNote` still silently blocked for addons, or has Blizzard restored any safe note-write path?
- What `QueryGuildBankLog` re-scan cadence is safe on Forever before UI hitching or delayed/dropped `GUILDBANKLOG_UPDATE` behavior becomes noticeable?
- What bootstrap/resync UX is acceptable if a full guild-state catch-up takes many seconds under normal addon-message throttling?
- What does a minimal, non-intrusive UI look like — a standalone panel, or an overlay/augmentation of the existing Blizzard Guild UI frame?

## Non-Functional Constraints

- **No external network calls** — WoW addons cannot make HTTP requests. All "sync" is via in-game addon-message channels only.
- **Performance:** must not cause noticeable frame hitches when opening guild UI/bank frames, especially in large guilds.
- **Data safety:** SavedVariables corruption or reset must not silently lose officer notes — always keep an internal versioned backup/migration path.
