# GuildOps

A modern guild management addon for World of Warcraft, initially targeting **WoW Forever**.

## Why

WoW's "new" Guild UI is widely disliked by the community: it lost persistent officer notes (breaking DKP systems that depended on them), broke online-status sorting, and introduced guild chat latency. Meanwhile the small addon ecosystem that has tried to patch this is fragmented — mostly single-maintainer, retail-only, or closed-source projects with no evidence of broad adoption. Mail tooling (Postal) has similarly fallen behind, with the community keeping it alive via ad-hoc compatibility forks rather than a real feature overhaul.

GuildOps aims to be the addon that actually fixes this: a maintained, cross-version guild management tool with persistent officer notes, sane roster sorting, and a real guild bank transaction ledger.

## Goals (v1)

- **Persistent officer notes** that survive Blizzard UI updates and aren't wiped by client patches.
- **Roster sorting/filtering** that actually works (online status, rank, note contents, last-online).
- **Guild bank transaction ledger** — a searchable, exportable log of deposits/withdrawals per item/gold.
- Built primarily for **WoW Forever**, Blizzard's new standalone product (beta as of late 2026), with an eye toward Classic Era/SoD and Retail support once the core is stable.

## Non-goals (for now)

- Full guild bank UI replacement (we augment the existing UI, not replace the whole window, until the ledger/notes core is solid).
- Mail overhaul (a real gap identified in research, but a separate addon/scope — see `CONTEXT.md`).
- DKP calculation/loot council logic — GuildOps stores the *data* (notes, ledger) that DKP systems need; it doesn't implement DKP itself.

## Status

🚧 Early planning / research phase. See the [project plan issue](../../issues) for current progress and `CONTEXT.md` for the domain model and known limitations.

## Contributing

See `AGENTS.md` for how automated agents (and humans) should work in this repo — coding conventions, addon-development constraints, and workflow expectations.

## License

TBD (likely MIT — WoW addon ecosystem convention). To be finalized before first public release.
