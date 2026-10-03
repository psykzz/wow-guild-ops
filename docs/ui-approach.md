# UI Approach: Overlay vs Standalone Panel (Issue #6)

## Observations from WoW Forever screenshots

The Guild frame is the modern "Guild & Communities" frame (`CommunitiesFrame`):

- **Chat tab**: guild chat with a small member list on the right (name only).
- **Roster tab**: columns Lvl / Class / Name / Zone / Rank / Note, with "Show Offline Members". Column headers are sortable, and there is a **Note** column that is empty/unused for officer notes.
- **Info tab**: Message of the Day, Guild Information, Guild News, "View Log".
- **Settings-style tab**: Preferred Play Settings (not relevant).
- **Member detail popout** (click a row): Zone, Rank, Last Online, public **Note**, **Officer's Note**, Remove, Group Invite.

Bank tab was not available in the captured frame; the bank UI is a separate `GuildBankFrame` and is handled by the ledger work.

## Option A: Overlay / augment (mockup)

- Roster: add a "GuildOps" column (or reuse the Note column area) showing a truncated GuildOps note; full note in the row tooltip.
- Member detail popout: add a "GuildOps Notes" edit box below Officer's Note, saved to the internal store (not `C_GuildInfo.SetNote`, which may be blocked).
- Roster header: add a sort/filter dropdown (e.g. by GuildOps note, last seen) next to "Show Offline Members".

Feasibility: hook lazily via `EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", ...)` and `hooksecurefunc` on the roster member list's `RefreshLayout`/`Update` and the member-detail frame's `DisplayMember`. Hooks are post-hooks only (no replacing Blizzard functions, avoiding taint). Row-level decorations are re-applied on each refresh, so Blizzard re-layouts do not break them. Risk: internal frame names/mixins may change between builds; mitigate with nil-guarded lookups in the compat layer and graceful fallback.

## Option B: Standalone panel (mockup)

A separate movable frame listing roster + notes with search/filter/sort and a ledger tab, opened via slash command / minimap button.

Pros: no dependency on Blizzard frame internals; full control over sort/filter and large-guild performance (own scroll list). Cons: duplicated roster UI, extra window to manage, not where officers already look.

## Recommendation

**Overlay for v1 (augment the Blizzard roster + member popout), with a thin standalone panel as a fallback** for features the Blizzard frame cannot host (ledger view, bulk search/filter). This matches the README non-goal of not replacing the Guild UI.

Rationale:
1. Officers already use the roster and member popout; notes appear in context.
2. Only post-hooks and added child frames are needed, minimising taint and breakage.
3. The data layer is UI-independent, so the standalone panel can be added later without rework.

Follow-ups: verify hook points in-client on WoW Forever, and note any Classic Era/Retail divergence.
