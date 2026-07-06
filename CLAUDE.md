@AGENTS.md

## Claude Code

Use the shared project guide above (`AGENTS.md`) as the source of truth for this repo.

Reminder of the two facts that most often trip up work here:

- This is the **MiSTer2MEGA65 framework** (upstream), not a core. Downstream cores copy the
  `M2M/` tree verbatim and treat it as read-only, so keep every `M2M/` interface
  **backward-compatible** — V2.1.0 is a non-breaking enhancement (see AGENTS.md §8).
- Verify QNICE assembly (`M2M/rom/*.asm`) in the **QNICE emulator** with a headless testbed
  before assuming it works — "it assembles" is not "it works" (AGENTS.md §5).
