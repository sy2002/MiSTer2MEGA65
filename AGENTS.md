> # 🛑 AI CODING ASSISTANTS — READ THIS BEFORE ANYTHING ELSE
>
> **This `AGENTS.md` (and `CLAUDE.md`) describe the MiSTer2MEGA65 _framework_ — its internals,
> written for people improving the framework itself. If you are instead helping someone build
> _their own core_ from this template, this guide is WRONG for that job and must be replaced.**
>
> **Step 1 — determine which repository you are in. Run:**
> `git remote get-url origin`
>
> - Output contains **`sy2002/MiSTer2MEGA65`** → you are in the **upstream framework**. This file
>   is correct here. Ignore this banner and continue to the guide below.
> - **Anything else** — a different repo, a fork, or no remote at all → you are almost certainly in
>   a **downstream core** that was cloned from the template but never customised. **STOP and do this
>   before any other work:**
>   1. **Warn the user, prominently and unmistakably:** their `AGENTS.md` and `CLAUDE.md` are still
>      the MiSTer2MEGA65 _framework's_ own guide. Those files describe framework internals, not the
>      user's core, and will actively mislead every AI assistant used in this repo. They must be
>      replaced.
>   2. **Do NOT treat the guide below as a description of the user's core.** It is about developing
>      the framework, which is not what the user is doing.
>   3. **Offer to write a replacement** `AGENTS.md` that describes the user's core (keep `CLAUDE.md`
>      importing it via `@AGENTS.md`). The reference cores did exactly this — e.g. the C64 core ships
>      its own `AGENTS.md`. Section 4.10 below describes the porter journey worth capturing in it.
>
> _Framework maintainers: this banner is self-gating on the git remote, so it stays out of your way.
> It exists only to protect porters who forgot to replace this file._

---

# MiSTer2MEGA65 — Framework Project Guide for Coding Agents

This is the cold-start brief for coding agents working **on the MiSTer2MEGA65 (M2M)
framework itself**. Read it first: it covers what this repo *is*, how it is laid out,
the contracts downstream cores depend on, the QNICE subsystem, the build/test flow, the
conventions, and the current development target (V2.1.0). Spend your context on the task,
not on rediscovering the layout.

> **You are editing the upstream framework, not a core.** Every downstream port copies the
> `M2M/` tree into its own repo verbatim and treats it as read-only. So the prime directive
> for all V2.1.0 work is **backward compatibility of every `M2M/` interface** (see §8).

---

## 1. What is this project?

**MiSTer2MEGA65 (M2M)** is a framework that makes it dramatically easier to **port a
MiSTer FPGA core to the MEGA65 computer**. It reimplements, in pure FPGA, the services
that MiSTer normally offloads to its ARM+Linux host: an on-screen menu (OSM), a FAT32 file
browser, disk-image mounting, ROM/cartridge loading, settings persistence, video scaling,
HDMI/VGA output, audio, keyboard/joystick/mouse input, HyperRAM, and I2C/RTC. A porter
wraps their MiSTer core and fills in a handful of config files; M2M does the rest.

- Repo: https://github.com/sy2002/MiSTer2MEGA65 — a GitHub **template repository**
  ("Use this template"). Authored/maintained by **sy2002 and MJoergen** (since 2021-04-05).
  License **GPL v3**.
- The reference implementation is the **Commodore 64 for MEGA65** core (see §9).

### Background concepts (brief)

- **MEGA65** — open-source modern recreation of the never-released Commodore 65, a real
  purchasable product built around a **Xilinx Artix-7 FPGA**. Crucially it is a *pure-play*
  FPGA machine: **no ARM co-processor, no Linux**. That single constraint is M2M's whole
  reason to exist. Board revisions M2M targets: **R3/R3A, R4, R5, R6**. https://mega65.org
- **MiSTer** — open-source FPGA platform (Alexey "Sorgelig" Melnikov, org `MiSTer-devel`)
  running on the Terasic DE10-Nano (Cyclone V FPGA **+ ARM SoC running Linux**). Cores are
  VHDL/Verilog/SystemVerilog; the ARM+Linux "framework" handles I/O, menu, ROM loading,
  disk mounting. M2M replaces that framework in FPGA. https://github.com/MiSTer-devel
- **QNICE-FPGA** — sy2002's portable 16-bit CPU + full System-on-a-Chip (own "Monitor" OS,
  assembler, C compiler, FAT32/SD, VGA text). In M2M, QNICE is the embedded SoC that runs
  the **Shell** firmware — it is M2M's stand-in for MiSTer's ARM/Linux brain.
  https://qnice-fpga.com · https://github.com/sy2002/QNICE-FPGA

### The two realms (internalize this first)

| Realm | Directory | Depends on | Independent of | Role |
| --- | --- | --- | --- | --- |
| **Framework** | `M2M/` | the board | the core | The HAL + services. Copied verbatim into every core; **read-only from a core's POV**. |
| **Core / template** | `CORE/` | the core | the board | The porter-editable skeleton. In *this* repo it is a **demo/template** that a porter replaces. |

The single VHDL contract between them is the entity **`MEGA65_Core`** in
`CORE/vhdl/mega65.vhd`, which `M2M/vhdl/top_mega65-rX.vhd` instantiates side-by-side with
`M2M/vhdl/framework.vhd`.

> Because this is the *framework* repo, `CORE/` here is not a real core — it is a
> fill-in-the-blanks skeleton wired to a self-contained demo (`M2M/vhdl/democore/`, a
> Breakout-style game) so the whole thing synthesizes and runs stand-alone before any real
> MiSTer core exists. Lots of code in `CORE/` is explicitly flagged "delete before porting."

---

## 2. Repository layout

```
/
├── README.md            TL;DR + pointers to the Wiki
├── VERSIONS.md          framework changelog (newest on top; top entry = V2.0.1)
├── AUTHORS              CREDIT TEMPLATE (placeholders like "YOUR NAME"); shows the required credits
├── AGENTS.md  CLAUDE.md this guide (CLAUDE.md just imports AGENTS.md)
│
├── M2M/                 ← THE FRAMEWORK (board-dependent, core-independent). Copied into cores verbatim.
│   ├── MEGA65-R{3,4,5,6}.xdc   per-board pin constraints
│   ├── common.xdc              shared timing constraints
│   ├── vhdl/
│   │   ├── top_mega65-r{3,4,5,6}.vhd  FPGA synthesis roots, one per board; instantiate
│   │   │                              framework.vhd AND CORE's MEGA65_Core, and OR the resets
│   │   ├── framework.vhd       the HAL: instantiates QNICE, AV pipeline, reset mgr, clocks,
│   │   │                       keyboard, joystick debounce, HyperRAM arbiter+ctrl, I2C/RTC
│   │   ├── clk_m2m.vhd         framework clocks (QNICE 50 / HyperRAM 100 / audio 12.288 MHz …)
│   │   ├── reset_manager.vhd   reset button → short=core reset, long(≥1.5 s)=full M2M reset
│   │   ├── m2m_keyb.vhd        MEGA65 keyboard → (a) core key matrix, (b) fixed qnice_keys_n for Shell
│   │   ├── vdrives.vhd         virtual-drive / MiSTer-mount engine (RAM-disk cache, dirty interlock)
│   │   ├── ram_init.vhd, tdp_ram.vhd, 2port2clk_ram*.vhd   dual-port BRAM/ROM primitives
│   │   ├── cdc_{pulse,slow,stable}.vhd, debounce*.vhd, clock_counter.vhd   CDC + helpers
│   │   ├── qnice_wrapper.vhd, qnice_arbit.vhd, qnice_csr.vhd, qnice2hyperram.vhd  QNICE bus glue
│   │   ├── QNICE/              M2M's QNICE SoC: qnice.vhd, qnice_mmio.vhd, qnice_globals.vhd, sdmux.vhd
│   │   │                      (these SHADOW same-named files in the submodule — see §4.4 gotcha)
│   │   ├── av_pipeline/        the whole video+audio chain (ascal, analog/digital, OSM, modes)
│   │   ├── controllers/        HDMI/ (Tyto2), M65/ (raw board drivers), MiSTer/ (video toolbox),
│   │   │                       hyperram/ (MJoergen HyperRAM PHY)
│   │   ├── memory/             Avalon-MM arbiters/caches/FIFOs (avm_*.vhd, axi_fifo.vhd)
│   │   ├── i2c/                I2C master + real-time clock (per-board device tables)
│   │   └── democore/           the built-in demo core (Breakout) — the "core" behind the template
│   ├── QNICE/                  ← git submodule: sy2002/QNICE-FPGA, branch dev-V1.61 (see §4.4)
│   ├── rom/                    ← the M2M SHELL, in QNICE assembly (see §4.5)
│   │   ├── main.asm shell.asm  bootstrap + trunk (menu, browser, mounting, IO loop)
│   │   ├── menu.asm options.asm selectfile.asm dirbrowse.asm llist.asm vdrives.asm
│   │   ├── keyboard.asm screen.asm whs.asm filters.asm gencfg.asm crts-and-roms.asm
│   │   ├── coreinfo.asm tools.asm strings.asm  *_vars.asm  *_test.asm (emulator testbeds)
│   │   └── sysdef.asm          THE software↔hardware register contract (mirrors the VHDL MMIO map)
│   ├── tools/                  make_config.sh (SD settings file), optm_heap.py, bin2qnice.py
│   ├── video_filters/          polyphase FIR coefficient sources + convert.py (+ append-only README)
│   └── font/                   Anikki-16x16-m2m.* OSM font (.rom is the synthesizable artifact)
│
├── CORE/                ← THE TEMPLATE (core-dependent, board-independent). A porter replaces this.
│   ├── vhdl/
│   │   ├── mega65.vhd    entity MEGA65_Core — THE framework↔core contract (see §3.2)
│   │   ├── main.vhd      the core's main-clock-domain wrapper (drops in the MiSTer core; wraps democore)
│   │   ├── clk.vhd       core-owned MMCM (100 MHz → 54 MHz main_clk) + reset sync
│   │   ├── config.vhd    Shell config ROM: OSM menu + welcome/help text (see §4.9)
│   │   ├── globals.vhd   constants: firmware switch, clock speeds, video res, vdrives, ROMs, HyperRAM map
│   │   └── keyboard.vhd  MEGA65 keyboard → core-key adapter (template mirrors all 80 keys)
│   ├── m2m-rom/         core-side QNICE firmware: m2m-rom.asm (#includes the Shell + callback stubs),
│   │                    make_rom.sh (builds m2m-rom.rom), synth_pre.tcl (Vivado pre-synth hook)
│   ├── CORE-R{3,4,5,6}.xpr  one Vivado project per board (+ generated .cache/.runs/.hw/.sim dirs)
│   ├── CORE.xdc         optional core-specific constraints
│   ├── make_qasm.sh, load_bitstream.sh
│
└── doc/
    ├── m2m/             framework conventions: example-file-headers.md, exceptions.md, m2m_migration.md
    ├── temp/            scratch/design notes (NON-authoritative; verify against source)
    └── wiki/            image assets used by README/wiki
```

The Wiki (the actual user-facing documentation) lives in a **separate** repo, cloned
locally at `../MiSTer2MEGA65.wiki/`. Its status is mixed — see §10.

---

## 3. Architecture

### 3.1 Layered view

```
  M2M/vhdl/top_mega65-rX.vhd         (synthesis root, one per board; pins + reset-OR)
  ├── i_framework : framework.vhd    (HAL, G_BOARD generic)
  │     ├── clk_m2m           QNICE 50 MHz, HyperRAM 100 MHz (+200 MHz refclk, +90° clk), audio 12.288 MHz
  │     ├── video_out_clock   reconfigurable HDMI pixel + 5× TMDS clock (per video mode)
  │     ├── reset_manager     short press → core reset, long press → full M2M reset
  │     ├── m2m_keyb          keyboard → core matrix + fixed qnice_keys_n for the Shell
  │     ├── qnice_wrapper     QNICE SoC (Shell), UART, 2× SD, paddles, CSR, framework device bus
  │     ├── avm_arbit_general 3-master HyperRAM arbiter:  [2] ascal · [1] core · [0] QNICE
  │     ├── av_pipeline       scaler + OSM overlay + HDMI + VGA + audio
  │     ├── hyperram          HyperRAM PHY/controller (+ ISSI rev-D errata fix)
  │     └── rtc_wrapper       I2C master + real-time clock
  └── CORE : MEGA65_Core (CORE/vhdl/mega65.vhd, G_BOARD generic)
        ├── clk.vhd           CORE-OWNED main/pixel clock (100 → 54 MHz), looped back to framework
        ├── main.vhd          the core in its own clock domain (democore in the template)
        ├── config.vhd        menu/help text served to QNICE as a config ROM
        └── (core RAM/ROM/HyperRAM devices, OSM-bit decode, AV-mode outputs)
```

**Signal-flow contract:** framework → core = clocks, resets, debounced inputs, OSM/QNICE
state, RTC. core → framework = video (RGB+syncs+CE), audio (signed PCM), LED colors,
QNICE-device replies, HyperRAM master requests, AV-mode config.

### 3.2 The framework↔core contract: entity `MEGA65_Core`

Declared in `CORE/vhdl/mega65.vhd:21-219`. One generic `G_BOARD : string`
(`"MEGA65_R3"|R4|R5|R6"`). Ports are grouped by **clock domain** (heavy comments mark each).
"Framework provides" = a core *input*; "core provides" = a core *output*.

- **QNICE clock domain** (50 MHz) `mega65.vhd:31-64` — framework provides `qnice_clk/rst_i`,
  the 256-bit OSM state `qnice_osm_control_i`, `qnice_gp_reg_i`, and the QNICE MMIO device
  bus (`qnice_dev_{id,addr,data}_i`, `_ce_i`, `_we_i`). Core provides the AV-*mode* config
  outputs (`qnice_dvi_o`, `qnice_video_mode_o`, `qnice_scandoubler_o`, `qnice_audio_mute/filter_o`,
  `qnice_zoom_crop_o`, `qnice_ascal_{mode,polyphase,triplebuf}_o`, `qnice_retro15kHz_o`,
  `qnice_csync_o`, `qnice_flip_joyports_o`) plus device reply `qnice_dev_data_o`/`_wait_o`.
  Conventions: default reply is `x"EEEE"` (`mega65.vhd:451`); **core device IDs must be
  `>= 0x0100`** (`< 0x0100` is framework-reserved).
- **HyperRAM clock domain** (100 MHz) `mega65.vhd:70-82` — the core is an **Avalon-MM master**
  into the shared arbiter: `hr_core_{write,read,address(31:0),writedata,byteenable,burstcount}_o`
  out, `hr_core_readdata_i`/`_readdatavalid_i`/`_waitrequest_i` in, plus `hr_high_i`/`hr_low_i`
  ("core too fast / too slow" — the flicker-free feedback). Template ties outputs to `0`.
- **Video clock domain** `mega65.vhd:88-98` — core provides everything: `video_clk_o`,
  `video_rst_o`, `video_ce_o`, `video_ce_ovl_o`, 8-bit `video_{red,green,blue}_o`,
  `video_{vs,hs,hblank,vblank}_o`.
- **Core (main) clock domain** `mega65.vhd:104-162` — `clk_i` is the raw 100 MHz. Core
  provides `main_clk_o`/`main_rst_o` (its own 54 MHz + reset) **back to the framework**.
  Framework provides `main_reset_m2m_i` (hard), `main_reset_core_i` (soft), `main_pause_core_i`,
  the CDC'd `main_osm_control_i`/`main_qnice_gp_reg_i`, debounced keyboard (`main_kb_key_num_i`
  0..79 + `main_kb_key_pressed_n_i`), debounced joysticks/paddles, and 65-bit `main_rtc_i`.
  Core provides `main_audio_left/right_o : signed(15:0)`, power/drive LED on+color,
  joystick output-enables.
- **Core-specific pass-through** `mega65.vhd:164-217` — the full CBM/IEC serial port and the
  complete C64 expansion/cartridge port. These exist because the template is C64-flavored and
  the MEGA65 hardware physically has these ports; a non-C64 core ties them off (the template's
  default values at `mega65.vhd:270-300` show how).

### 3.3 Clocks & resets — split ownership (a key invariant)

- **The core owns its own clock.** `CORE/vhdl/clk.vhd` (an `MMCME2_ADV`, 100 → 54 MHz)
  generates `main_clk`/`main_rst` and loops them *back into* the framework. The framework
  does **not** generate the core clock. Changing the core clock means editing both `clk.vhd`
  **and** `CORE_CLK_SPEED` in `globals.vhd:44` (that constant feeds the joystick debouncer and
  keyboard timing, and cores use it to avoid time-of-day drift).
- **The framework owns** QNICE (50 MHz), HyperRAM (100 MHz + a 200 MHz IDELAY refclk + a 90°-
  delayed 100 MHz), the audio clock (**12.288 MHz** — note two stale in-code comments say
  "30 MHz"/"60 MHz"; the real value is 12.288 MHz, `clk_m2m.vhd:36`, `framework.vhd:867`), and
  the reconfigurable HDMI pixel/TMDS clocks.
- **Reset semantics.** `reset_manager.vhd`: a short reset-button press = **core-only** reset;
  a **long press (≥1500 ms)** = full M2M reset (power LED turns blue during the long reset).
  The final reset OR-ing happens **in the board top, not the framework** (identical R3–R6),
  e.g. `top_mega65-r3.vhd:728-730`:
  `main_reset_m2m_i = m2m-reset OR qnice-reset OR core-clock-not-locked`;
  `main_reset_core_i = core-reset OR qnice-reset`. QNICE can command a reset (its CSR default
  `x"0839"` deliberately **holds the core in reset at power-on** to avoid reset "flicker" that
  crashes some cores — `qnice.vhd:95-119`). **HyperRAM reset is intentionally coupled to the
  core reset** (`clk_m2m.vhd:183-186`) so the Avalon arbiter/ascal state stays coherent across
  a burst — do not decouple it.

### 3.4 QNICE — the on-board helper CPU that runs the Shell

QNICE-FPGA is a 16-bit CPU + minimal SoC. In M2M it runs the **Shell** firmware (§4.5 →§3.5).

- **Two QNICE trees, and only one is synthesized (learned the hard way).** The CPU, BRAM/BROM,
  UART, EAE, SD controller, cycle counter come from the **submodule** `M2M/QNICE/vhdl/*`. But
  `mmio_mux` and `env1_globals` are **shadowed** by M2M overrides at `M2M/vhdl/QNICE/qnice_mmio.vhd`
  and `qnice_globals.vhd` (the `.xpr` compiles the overrides). **Editing the submodule's
  `mmio_mux.vhd`/`env1_globals.vhd` has no effect on the M2M bitstream.**
- **QNICE runs at 50 MHz and reads/writes registers and memory on the *falling* clock edge.**
  This is why every dual-port RAM/ROM the core shares with QNICE must set its QNICE-side port to
  falling-edge (`dualport_2clk_ram` generics `FALLING_A/B`; the byte-enable wrapper
  `dualport_2clk_ram_byteenable` uses `G_FALLING_A/B`), and `qnice2hyperram`/`vdrives` register
  files are falling-edge.
- **The MMIO "4k-window" device model (the core-facing contract).** Software writes a 16-bit
  device id to `0xFFF4` and a 16-bit window to `0xFFF5`, then reads/writes the 4k data window at
  `0x7000`. Hardware forms a 28-bit address `window*4096 + offset`. **Device IDs `< 0x0100` are
  framework-reserved** (VRAM, OSM config, ascal, HyperRAM `0x0004`, I2C, RTC, SysInfo `0x00FF`);
  IDs `>= 0x0100` fall through to the core's own `qnice_dev_*` bus. The authoritative map is
  `M2M/rom/sysdef.asm` (mirrored bit-for-bit by `qnice.vhd` and `qnice_wrapper.vhd`).
- **Data-bus convention:** the CPU input is a wired-OR of every device's data-out — **every
  device must output all-zeros when not selected** (`qnice.vhd:235-257`).
- **Firmware switch** (`CORE/vhdl/globals.vhd:29-33`): `QNICE_FIRMWARE_M2M` = the release Shell
  (`CORE/m2m-rom/m2m-rom.rom`); `QNICE_FIRMWARE_MONITOR` = the QNICE **Monitor** ("OS"), for
  debugging the firmware itself — you can then `M/L` code into RAM over the JTAG serial console.
  Default is `_M2M`.
- **`M2M/QNICE` is pinned to branch `dev-V1.61`** — see §4.4 for why this is *the* only relevant
  QNICE branch and what it adds.

### 3.5 The Shell (the behavioral heart) — see §4.5

### 3.6 AV pipeline (video + audio)

The core hands the framework a raw retro RGB stream + separate H/V sync + H/V blank + two
clock-enables (in the core's `video_clk` domain) and signed 16-bit stereo PCM (audio domain).
`M2M/vhdl/av_pipeline/av_pipeline.vhd` splits it into **two simultaneous outputs**:

- **Analog VGA** (`analog_pipeline.vhd`): optional MiSTer **scandoubler** (`hq2x` and gamma are
  disabled here), OSM overlay, optional composite sync; RGB forced to 0 during blanking (MEGA65
  VDAC requirement); output registers clock on `falling_edge(video_clk)` for a clean sample.
- **Digital HDMI** (`digital_pipeline.vhd`): `crop` (optional zoom) → **`ascal.vhd`** (temlib
  polyphase scaler, ~2900 lines — don't edit) which writes input frames into **HyperRAM** and
  reads them out at the chosen fixed HDMI mode → OSM overlay → `vga_to_hdmi` (Tyto2) → TMDS
  serialisers. HDMI PCM is fixed at 48 kHz.
- **7 HDMI output modes** (`video_modes_pkg.vhd`, enum `video_mode_type`): `720p@50` (default,
  16:9), `720p@60`, `576p@50` (4:3), `576p@50` (5:4), `640×480@60`, `720×480@59.94`, `800×600@60`.
  The core selects one via `qnice_video_mode_o`. Analog VGA is **not** one of these — it emits the
  core's native (optionally scandoubled) timing.
- **Flicker-free** (`hdmi_flicker_free.vhd`): the HDMI clock is a *standard* rate; the core's real
  frame rate rarely matches, so ascal write/read chase each other in HyperRAM. The framework
  measures the address gap and pulses `hr_high_o`/`hr_low_o` (→ core `hr_high_i`/`hr_low_i`) so the
  core can nudge its clock to stay phase-aligned. **The template/democore does NOT consume these**
  — to actually get flicker-free a porter wires them to a dynamic (reconfigurable) core clock.
- **Audio**: signed 16-bit PCM at 12.288 MHz → optional MiSTer biquad filter (`audio_out.v`,
  coefficients are **core-owned constants** in `globals.vhd:168`, copied from the MiSTer core's
  `sys/sys_top.v`) → both the analog jack and HDMI.

**CE (clock-enable) conventions a core MUST follow** (both in the `video_clk` domain,
contract at `CORE/vhdl/main.vhd:109-118`):
- `video_ce_o` = the core's **native** pixel-clock enable (pre-scandoubler).
- `video_ce_ovl_o` = the **post-scandoubler** pixel rate (≈ 2× `video_ce_o`), used for the analog
  OSM overlay; it must match `VGA_DX`/`VGA_DY` from `globals.vhd`. The demo cheats with
  `video_ce_ovl_o <= video_ce_o` because democore already outputs at full resolution.
- Sync and blank must be **active-high**.

### 3.7 Memory & HyperRAM

- **HyperRAM is the framework's only real memory** (SDRAM exists on R4+ but the framework does
  **not** use it yet — `C_CRTROMTYPE_SDRAM` is reserved; SDRAM support is a V2.1.0 item, §9).
- The framework exposes a **core-facing Avalon-MM slave `hr_core_*`** in the 100 MHz `hr_clk`
  domain; internally it is one of three fairly-arbitrated masters (ascal · core · QNICE).
- **HyperRAM is 16-bit, word-addressed, and `avm_address_i(31)=1` selects the HyperRAM register
  space, not RAM** — the single most common trip-up when driving `hr_core_*` directly.
- **Standard "core → HyperRAM" pattern:** a core whose logic is in a different clock domain
  instantiates an `avm_fifo` (async CDC) and usually an `avm_cache` (read-burst efficiency) in
  front of `hr_core_*`. `avm_cache` is provided but instantiated nowhere in *this* repo (real
  cores add it; the democore doesn't touch HyperRAM). The C64 core's REU chain is the reference.
- `M2M/vhdl/memory/` building blocks: `avm_arbit` (2→1), `avm_arbit_general` (3–4→1), `avm_cache`,
  `avm_fifo` (CDC; requires `G_DATA_SIZE > 8`), `avm_decrease`/`avm_increase` (width converters),
  `axi_fifo` (Xilinx `xpm_fifo_axis`). **Sim-only models (never synthesize these):** `avm_memory`,
  `avm_rom`, `avm_memory_pause`, `avm_pause`.

### 3.8 Virtual drives (`vdrives.vhd`)

`M2M/vhdl/vdrives.vhd` implements the virtual-drive half of MiSTer's `hps_io.sv`, so a core's
MiSTer drive wires straight to it. It is instantiated **on the core side** (in the template,
`mega65.vhd:500`, but a real core usually moves it into `main.vhd`). Model:

- The Shell firmware treats a mounted disk image as a **RAM disk** (buffered in HyperRAM) and
  serves the core's block reads/writes in real time. `img_mounted` is a strobe; **unmount =
  strobe with `img_size = 0`, mount = strobe with nonzero size**; `drive_mounted` is the latched
  version that drives the drive's reset.
- **Cache write-back interlock:** a write marks the cache dirty; the flush to SD only starts after
  a configurable idle window (default **2 s**, anti-thrashing) because QNICE SD writes are too slow
  for real-time emulation. A core uses `cache_dirty_o` to **delay/deny a reset or unmount until the
  cache is clean** ("prevent-reset"). Its QNICE register file is written on
  `falling_edge(clk_qnice_i)`. This VHDL register map must stay lock-step with `M2M/rom/vdrives.asm`.
- Only 8-bit data / 14-bit buffer address (MiSTer "WIDE" mode not supported); `VDNUM` max 15
  (config), MiSTer's own max is 10.

### 3.9 OSM / config.vhd menu model

- The 256-bit `M2M$CFM_DATA` register **is** the live menu state: **bit N ↔ menu line N**, 1:1
  with `OPTM_ITEMS`/`OPTM_GROUPS` in `config.vhd`. It reaches VHDL as `qnice_osm_control_i` (QNICE
  domain) and CDC'd `main_osm_control_i` (core domain).
- In `mega65.vhd` the `C_MENU_*` natural constants are **zero-based line indices** into
  `OPTM_ITEMS`. **Reorder/insert/delete any menu line and every index below it shifts — you must
  re-sync `C_MENU_*` in `mega65.vhd`.** This coupling is silent; nothing checks it.
- Menu structure, welcome text, and help screens are all data in `config.vhd`; see §4.9.

### 3.10 The democore & the `CORE/` template

`M2M/vhdl/democore/` is a self-contained Breakout demo (ball + paddle + test tone) that lets
the framework synthesize and run stand-alone. The `CORE/vhdl/*` files are the skeleton a porter
edits; large parts are flagged "delete before porting your own core" (the `C_MENU_*` demo menu
constants, the demo virtual-drive device, the `i_vdrives` demo instance, the whole cartridge-port
tie-off). See §4.10 for the exact porter step-by-step.

---

## 4. Subsystem deep-dives

### 4.4 QNICE `dev-V1.61` — the only relevant QNICE branch

M2M uses a **work-in-progress QNICE** on branch **`dev-V1.61`** ("the M2M branch"), pinned as the
`M2M/QNICE` submodule at commit `567254d` (`git describe` = `V1.6-50-g567254d`, i.e. 50 commits past
the `V1.6` tag — **not itself on a tag**). QNICE `V1.6` is released; `V1.7` (QNICE `develop`) is
stale. **`dev-V1.61` is THE only branch that matters.** The delta vs `V1.6` is documented in
`M2M/QNICE/VERSIONS.txt`; the highlights (all things you can rely on):

- **SD-card *write* ability** via the FAT32 lib — deliberately restricted: you may **overwrite bytes
  of an existing file only** (size must stay identical; no append/truncate/create/delete/attr
  change). This is the mechanism M2M uses to write back to fixed-size disk-image files.
  New: `SD$WRITE_BLOCK/BYTE`, `FAT32$FLUSH/CLOSE/WRITE_B/WB`; refactors `FAT32$READ_SIC→RW_SIC`,
  `FAT32$FILE_RB→FILE_RWB`; **`FAT32$FILE_SEEK` now seeks relative to file start** (was: current
  position). Renamed `FAT32$FDH_READ_LO/HI → FAT32$FDH_ACCESS_LO/HI`; new FDH fields `FAT32$FDH_FLAGS`,
  `FAT32$FDH_START_CLUS_LO/_HI`. C side: `fwrite` in `"r+"/"rb+"`, `fseek` `SEEK_SET`, new `fsize`.
- **Robustness:** async→synchronous reset + consistent falling-edge in SD/CycleCounter/UART/EAE; a
  device-handle/stack-corruption bug fixed; a macOS workaround for `.`/`..` being flagged HIDDEN on
  some FAT32 cards (macOS 11.6.8–14.3).
- **Merged from V1.7:** stdlib `MISC$ENTER/LEAVE`, `MTH$IN_RANGE_U`, `STR$CPY/STR`, modified
  `STR$STRCHR` (plus a brand-new `STR$RPLCHR` added in V1.61 itself); a much-improved **assembler**
  with meaningful error messages; and an **emulator
  headless Batch Mode** (`-b`) for scripting/CI — this is what makes the QNICE-emulator test loop
  in §6 possible.
- **Still OPEN / WIP (per VERSIONS.txt itself):** the doc header date is a placeholder; "make QNICE
  runnable stand-alone" is unfinished; and **MJoergen's new SD controller is NOT in M2M** (it lives
  on QNICE + M2M branches `mfj_new_sdcard`, builds but barely tested, blocked on R3 SPI support — a
  candidate for a *future* M2M V2.1+).

Other M2M QNICE glue: `qnice_wrapper.vhd` (framework device decode: VRAM `0x0000/0x0001`, OSM config
`0x0002`, ascal `0x0003`, HyperRAM `0x0004`, I2C `0x0005`, RTC `0x0006`, SysInfo `0x00FF`);
`qnice2hyperram.vhd` (QNICE→Avalon single-beat bridge, device `0x0004`); `sdmux.vhd` (dual-SD-slot
mux — auto-prefers the external/back slot; **the bottom-tray card can't be detected on R3**, a bug
fixed on R3A); `qnice_csr.vhd` (a file-parse request/response CSR helper the framework *offers* to
cores that must parse loaded files — **instantiated nowhere in this repo**, optional).

### 4.5 The Shell firmware (`M2M/rom/*.asm` + core-side `CORE/m2m-rom/`)

The Shell is the default "behavioral heart": QNICE assembly that draws the OSM (Options/Help),
runs the file+dir browser, mounts disk images with cached write-back, loads ROMs/cartridges, shows
welcome/help screens, and persists settings to SD. It is board-dependent, core-**independent** —
everything core-specific enters through `config.vhd`/`globals.vhd` data and through a small set of
**assembly callbacks**.

**Build & entry.** The ROM is assembled from the *core* side: `CORE/m2m-rom/m2m-rom.asm` is the top
file; it `#include`s the framework's `main.asm` then `shell.asm`, and jumps `START_FIRMWARE →
START_SHELL`. `shell.asm` is the trunk and `#include`s the outsourced units (`options selectfile
dirbrowse vdrives crts-and-roms filters gencfg whs menu screen keyboard tools coreinfo strings`;
`llist.asm` is pulled in transitively by `dirbrowse.asm`, not by `shell.asm` directly).
`make_rom.sh` **auto-generates** `globals.asm`, `shell_fhandles.asm`, `shell_fh_ptrs.asm` from the
VDRIVES/CRTROM counts in `CORE/vhdl/globals.vhd` (they say "DO NOT MANUALLY EDIT").

**The core↔Shell callback contract.** A porter overrides these labelled stubs in
`CORE/m2m-rom/m2m-rom.asm` (args/returns in `R8..R12`; keep the `INCRB`/`DECRB` register-bank
discipline; `R8=0` conventionally means "default/OK"):

| Callback | Purpose | Called from |
| --- | --- | --- |
| `SUBMENU_SUMMARY` | supply the `%s` text shown in a submenu headline | `options.asm` (`OPTM_CB_SHOW`) |
| `FILTER_FILES` | show/hide a file in the browser (by name/dir/context) | `dirbrowse.asm` (`_DIRBR_FILTWRAP`) |
| `PREP_LOAD_IMAGE` | validate/prep a selected image, return its 2-bit type | `shell.asm` (`LOAD_IMAGE`) |
| `PREP_START` | one-time prep before the core leaves reset (fatal on error) | `shell.asm` (`PREP_CONNECT`) |
| `OSM_SEL_PRE` | hook before a menu selection is applied | `options.asm` (`OPTM_CB_SEL`) |
| `OSM_SEL_POST` | hook after a menu selection is applied | `options.asm` (`OPTM_CB_SEL`) |
| `CUSTOM_MSG` | supply a custom message string for a browser situation | `selectfile.asm` |

> Note: AExp (§9) adds a proposed **8th** callback `HANDLE_CORE_IO` (a per-iteration time slice for
> background tasks like write-back caches) — that is a V2.1.0 upstream candidate, **not yet in this
> repo's Shell**. `START_FIRMWARE` (`m2m-rom.asm:43`) is the hook a core could use to replace the
> Shell entirely.

**Behavior worth knowing.** Startup inits libraries in a strict order (`SCR$INIT`, `FRAME_FULLSCR`,
`VD_INIT`, `CRTROM_INIT`, `KEYB$INIT`, `HELP_MENU_INIT`, `CRTROM_AUTOLOAD`); `RP_SYSTEM_START` must run
*after* `HELP_MENU_INIT` (menu defaults must already populate `M2M$CFM_DATA`). Settings load if
`config.vhd`'s `SAVE_SETTINGS` is true and the on-SD file exists and matches `OPTM_SIZE`; otherwise
factory defaults from `OPTM_G_STDSEL`. Write-back (`FLUSH_CACHE`) is deliberately lazy/iterated
(`VD_ITERATION_SIZE` bytes per call) to avoid timing out strict cores. **Debug backdoor:** hold
**Run/Stop + Cursor-Up, then press Help** to drop into the QNICE Monitor over UART.

**⚠ The V6 "mergesort" is NOT on this branch.** `llist.asm` uses an O(n²) sorted-insert
(`SLL$S_INSERT`, one per directory entry). The file-browser speedup is a genuine V2.1.0 to-do (§9),
not something already present — verified: no mergesort anywhere in `M2M/rom/`.

### 4.9 `CORE/vhdl/config.vhd` — the Shell config ROM

A big set of string/array constants that an address-decode process at the bottom of the file serves
to QNICE as a memory-mapped config ROM (read on `falling_edge`). The address-decode process below the
`config.vhd:443` "DO NOT TOUCH ANYTHING BELOW THIS LINE" banner, **plus** the `SEL_*` and `OPTM_G_*`
constants defined *above* it (each separately marked DO NOT TOUCH), are all off-limits; a porter edits
only string/array *values*.
The editable sections:

- **Welcome/Help screens (WHS).** Free-form strings concatenated into one `WHS_DATA` ROM with
  hand-computed start offsets (the `'length` idiom), then indexed by a `WHS` array of
  `(page_count, starts[], lengths[])`. **WHS index 0 = the Welcome screen; indices 1+ correspond, in
  order, to menu items tagged `OPTM_G_HELP`.** Max 16 records → max 15 Help items. The `\n` newline
  *escape* must be written lowercase (uppercase `\N` = undefined behavior); the screen text itself may
  be mixed-case.
- **`OPTM_ITEMS`** — the literal menu text, one item per line; every selectable line must start with
  a leading space; separator lines are exactly `"\n"`.
- **`OPTM_GROUPS`** — one entry per menu line: a porter-named group id (monotonic from 1, unique per
  single-select/mount item, 255 = close) OR'd with framework attribute flags (`OPTM_G_STDSEL`,
  `OPTM_G_LINE`, `OPTM_G_START`, `OPTM_G_HEADLINE`, `OPTM_G_HELP`, `OPTM_G_SUBMENU`, `OPTM_G_SINGLESEL`,
  `OPTM_G_MOUNT_DRV`, `OPTM_G_LOAD_ROM`, …).
- **`OPTM_SIZE`** — **must equal** the number of lines in `OPTM_ITEMS` **and** the number of entries in
  `OPTM_GROUPS` (all three are 35 in the template). It also sets the size of the on-SD settings file
  (regenerate it with `M2M/tools/make_config.sh` when it changes).
- **General settings** (`RESET_COUNTER`, `OPTM_PAUSE`, `WELCOME_ACTIVE`/`_AT_RESET`, keyboard/joystick
  enable during reset/OSM, `ASCAL_USAGE`/`ASCAL_MODE`, `SAVE_SETTINGS`, `VD_ANTI_THRASHING_DELAY`,
  `VD_ITERATION_SIZE`) and `DIR_START`/`CFG_FILE`/`CORENAME`.
- Note: the template has **no single numeric `CORE_VERSION` constant** — the visible version is text
  embedded in the welcome string; `config.vhd:83` literally emits `Version [WIP]` as a placeholder.
  (Real cores add a `CORE_VERSION`; that pattern is a candidate to standardize.)

### 4.10 Porter step-by-step (what actually gets filled in)

This is the "user journey" a coding agent should be able to explain and, later, keep the framework
friendly to:

1. **`clk.vhd`** — set the MMCM to your core's real clock(s); add `CLKOUTn` + BUFG +
   `xpm_cdc_async_rst` per extra clock.
2. **`globals.vhd`** — set `CORE_CLK_SPEED` (= step 1, exact Hz), `VGA_DX`/`VGA_DY`, virtual-drive
   count/devices, CRT/ROM autoload, audio-filter coefficients; keep `QNICE_FIRMWARE = _M2M`.
3. **`main.vhd`** — delete `i_democore`, instantiate the MiSTer core in the `clk_main_i` domain; drive
   `video_ce_o`/`video_ce_ovl_o` correctly; wire audio/video/inputs.
4. **`keyboard.vhd`** — reshape the 80-key snapshot into your core's key format using the `m65_*`
   constants.
5. **`mega65.vhd`** — delete the `C_MENU_*`/demo-device/demo-vdrive scaffolding; add real dual-clock
   RAM/ROM (QNICE port on falling edge) and real devices (`id >= 0x0100`) in `core_specific_devices`;
   re-wire `qnice_video_mode_o` and the AV-mode outputs to your menu bits; connect HyperRAM if used.
6. **`config.vhd`** — write the welcome/help strings + `WHS`; write `OPTM_ITEMS`/`OPTM_GROUPS` + group
   constants; set `OPTM_SIZE`/`OPTM_DX`/`OPTM_DY`; **keep every `C_MENU_*` in `mega65.vhd` in sync**.
7. **`CORE/m2m-rom/m2m-rom.asm`** — fill the callback stubs (§4.5) as needed.

---

## 5. Build & test workflow (this repo)

```bash
git clone https://github.com/sy2002/MiSTer2MEGA65.git
cd MiSTer2MEGA65
git submodule update --init --recursive         # pulls M2M/QNICE (dev-V1.61)

# 1) QNICE toolchain (ONE-TIME; builds qasm, qasm2rom, monitor, emulator, bit2core, C toolchain)
cd M2M/QNICE/tools && ./make-toolchain.sh && cd ../../..
#    The submodule ships only C SOURCES + the `asm` wrapper — NO toolchain binaries (they are
#    gitignored). You must build qasm/qasm2rom/monitor/emulator yourself; make_rom.sh errors until you do.
#    Quick alt for just the assembler:  cd CORE && ./make_qasm.sh   (compiles qasm.c / qasm2rom.c)

# 2) Build the Shell ROM (whenever you touch CORE/m2m-rom/*.asm, M2M/rom/*.asm, or the counts in globals.vhd)
cd CORE/m2m-rom && ./make_rom.sh && cd ../..      # → m2m-rom.rom (+ .out/.def/.lis)
#    (Vivado also rebuilds it automatically at synth via CORE/m2m-rom/synth_pre.tcl, so this is optional.)

# 3) Open the per-board Vivado project and Run Synthesis → Implementation → Generate Bitstream
#    CORE/CORE-R{3,4,5,6}.xpr   (each = same sources + a different top + XDC + G_BOARD string)

# 4) Flash / distribute
#    JTAG dev loop:  m65 -q <bitstream>.bit      (from the sibling mega65-tools repo)
#                    CORE/load_bitstream.sh is a convenience but is HARD-CODED to R3.
#    Distribution:   bit2core → .cor
```

### Verify QNICE assembly in the emulator — write headless testbeds

**Do not stop at "it assembles."** Any non-trivial Shell/QNICE change (sorting, parsing, string
handling, data structures) should ship with an emulator run that proves the behavior — no hardware,
no Vivado. The `dev-V1.61` emulator has a headless batch mode:

```bash
# assemble a testbed
( cd M2M/rom && ../QNICE/assembler/asm llist_test.asm )
# run it: -b loads the .out(s), sets SP like the monitor cold start, sets PC to the hex entry addr,
#         runs to HALT / error / EOF. Exit codes: 0=HALT/EOF, 1=error, 130=CTRL-C.
M2M/QNICE/emulator/qnice -b 0x8000  M2M/QNICE/monitor/monitor.out  M2M/rom/llist_test.out < /dev/null
```

Testbed style (see `M2M/rom/{llist,dirbrowse,keyboard}_test.asm`): `.ORG 0x8000`, `#include` the
module under test, feed fixed data, print with `SYSCALL(puts/puthex)`, `SYSCALL(exit,1)`, then
validate stdout with a script rather than eyeballing it. Gotchas: programs using syscalls must also
load `monitor.out`; a runaway program that never reads stdin spins forever (wrap in a `timeout`; macOS
has none — use a Python `subprocess(..., timeout=...)`); in the interactive `Q>` shell bare numbers are
*decimal* and `RUN` does not set SP (batch mode gets both right).

---

## 6. Coding conventions

- **Languages:** VHDL for framework logic; Verilog/SystemVerilog only where imported from MiSTer/Tyto2
  (`ascal.vhd`, `audio_out.v`, `controllers/MiSTer/*`, `controllers/HDMI/*`). Don't rewrite imported
  sources without a reason; keep their original headers and add yours.
- **Signal naming (hard convention):** `lower_snake_case` with suffixes `_i` input, `_o` output, `_io`
  bidir, `_n` low-active, `_oe` output-enable. Clock-domain prefixes (`qnice_*`, `main_*`/core, `hr_*`,
  `audio_*`, `hdmi_*`) mark which domain a signal lives in; Avalon uses `s_*` (slave) / `m_*` (master).
  **Crossing a prefix boundary without a CDC block is a bug.** American English in comments/identifiers.
- **File headers:** every file must credit the MiSTer team. Use the templates in
  `doc/m2m/example-file-headers.md` ("This machine is based on `<MiSTer repo>` / Powered by
  MiSTer2MEGA65 / MEGA65 port done by `<name>` in `<year>` and licensed under GPL v3"). For a modified
  MiSTer file, keep its original header, prepend yours, and add an "Updating notes" block.
- **`doc/m2m/exceptions.md`** is the per-project log of every deviation from upstream MiSTer/M2M/QNICE
  (the template files here are examples to be overwritten downstream). Guiding philosophy: **"avoid
  touching the original"** — prefer wrapping over editing; document unavoidable edits here.
- **QNICE assembly:**
  - **The assembler is multi-pass — `#include` order does not matter** (forward references resolve).
    Reorder only for readability.
  - **No apostrophes (or unpaired `"`) in comments.** The `asm` wrapper pipes every source through the
    C preprocessor; a lone `'` in `caller's`/`MiSTer's` is read as an unterminated char-literal and
    floods the build log with warnings. Rephrase possessives. Paired quotes in `.ASCII_W "..."` are fine.
  - `$` is a legal identifier char, namespaced by subsystem (`M2M$CSR`, `FAT32$FDH_*`, `SLL$NEXT`).
  - ABI: args/returns in `R8..R12`; helpers open `SYSCALL(enter,1)` / close `SYSCALL(leave,1)`; the
    carry flag is the common boolean return.
  - Generated `*.asm` files (`globals.asm`, `shell_fhandles.asm`, `shell_fh_ptrs.asm`) and `m2m-rom.rom`
    are build products — never hand-edit; re-run `make_rom.sh`.
- **Append-only, newest-on-top READMEs** (e.g. `M2M/video_filters/README.md`): add a new dated section
  at the top for new work; never rewrite historical sections.
- **Timing-constrained CDC:** `cdc_stable.vhd` (and friends) require a `set_max_delay ... -datapath_only`
  line in the XDC — the exact constraint is documented in the file header. `tdp_ram`/`2port2clk_ram`
  keep a clock-enable and an `InitRAM` indirection specifically to satisfy Vivado 2019.2/2021.2 BRAM
  inference — do not "simplify" them away.

---

## 7. Per-board deltas (R3 / R3A / R4 / R5 / R6)

The framework entity is board-agnostic; **all board variance lives in the tops
(`M2M/vhdl/top_mega65-rX.vhd`, each a distinct entity `mega65_rX` passing its own
`G_BOARD => "MEGA65_RX"`) and the XDCs (`M2M/MEGA65-RX.xdc` + `M2M/common.xdc`).**

- **Reset source:** R3 reads the reset button (and DIP switches, GPIO, commit/date) from the **MAX10
  companion FPGA** via `controllers/M65/max10.vhdl` (R3-only); R4/R5/R6 use a direct reset button.
- **Audio:** R3 does not use its onboard DAC (SSM2518, held in power-down via `audio_pdn_n_o <= '0'`) and
  drives the 3.5 mm jack with **analog PDM** (`pcm_to_pdm.vhdl`); R4/R5/R6 drive an **AK4432VT I2S DAC**
  (`controllers/M65/audio.vhd`, needs the 12.288 MHz clock).
- **SDRAM:** present on R4/R5/R6, **tied off / unused by the framework** (reserved for V2.1.0).
- **Cartridge / joystick ports:** joystick output-enables (`fa_*_o`/`fb_*_o`) are present on **R4/R5/R6**;
  only R3 is joystick-input-only (its `joy_*_o` map to `open`). R5/R6 additionally expose more
  bidirectional cartridge lines (13 inout vs 8 on R3/R4) plus extra direction controls. `cart_en_o <= '1'`
  is **mandatory even if unused** — an R5/R6 board bug makes joystick port 2 fail if the cart-port level
  shifter is disabled.
- **HDMI transceiver / I2C fan-out** differ per board; the RTC chip is selected per `G_BOARD` in
  `i2c/rtc_master.vhd` (a new board revision teaches its RTC device there).
- **Vivado projects:** `CORE/CORE-RX.xpr` per board — keep the file lists in sync across all four when
  adding/removing sources.

---

## 8. Branch & version model — the prime directive

- **`master`** = the current public release, tag **`V2.0.1`** (2025-02-22). Also used for MINOR edits to
  the public-facing `README.md`.
- **`develop`** = the next version, **V2.1.0**, in the making. It is currently **exactly 1 commit ahead**
  of `master`: `80cbba3 "QNICE updated"`, which bumps the `M2M/QNICE` submodule to `dev-V1.61`
  (`567254d`). So V2.1.0 work has just begun.
- **V2.1.0 is a NON-BREAKING enhancement.** The backward-compatibility promise (issue #63): *"V2.0.2 =
  bugfixes only. V2.1 = bugfixes plus new features but nothing breaks backwards compatibility"* — a
  downstream core must be able to just **re-synthesize** after upgrading. Since you are editing the very
  `M2M/` tree cores treat as read-only, **preserving every existing `M2M/` interface is the prime
  directive.** New ports/inputs must default to a value that leaves existing cores unaffected (AExp's
  interlace work is the model: new `video_fl_i` defaults to `'0'`).
- Tags present: `V0.9.0, V0.9.1, V1.0.0, V2.0.0, V2.0.1` (+ `Vivado-2019.2`). Version history is in
  `VERSIONS.md` (newest on top; extend, don't rewrite).
- **Experimental remote branches** (MJoergen's `mfj_*` = his initials; not merged into `develop`, intent
  inferred from names/logs — audit diffs before relying): `mfj_hyperram_stats` (HyperRAM statistics +
  video-mode cleanup), `mfj_refactor` (warning reduction, doc), `mfj_new_sdcard` (the WIP new SD
  controller), `mfj_add_uart` (UART→QNICE; ~30 commits, last touched 2024-11-16), `research` (sy2002: "disable the ascaler",
  QNICE update, the joystick-2 fix that later reached master).

---

## 9. Reference cores & the "upstream from a core" workflow

New framework capabilities are first developed and **hardware-verified inside a real core**, then
back-ported into `M2M/`. The two reference cores (local sibling repos):

- **C64MEGA65** (`../C64MEGA65/`) — **the reference implementation of M2M**, maintained by MJoergen +
  sy2002, public (https://github.com/MJoergen/C64MEGA65). Its `AGENTS.md` is an excellent, deep source on
  the framework — especially QNICE, vdrives, OSM, cartridges. Its "V6" development is the source of most
  V2.1.0 features below.
- **AExp** (`../AExp/`) — **Amiga 500** (MiSTer Minimig-AGA, OCS/PAL only), sy2002's own port, built on
  M2M V2.0.1, currently local-only. It is the proving ground for the newest framework features (ADF
  floppy write-back, interlace weave, VGA analog modes). It marks every sanctioned edit to *its* `M2M/`
  copy with a greppable in-code **`M2M-UPSTREAM <name>`** tag — literally a to-do list of framework diffs
  awaiting upstream merge into this repo.

**Rule:** a core-side change that is generic gets promoted to `M2M/`; a core-specific change stays in
`CORE/`. When you are asked to "merge feature X from the C64/Amiga core into M2M," find its `M2M-UPSTREAM`
tags (AExp) or its V6 commits (C64), lift the framework side, and preserve backward compatibility (§8).

### V2.1.0 backlog — GitHub issue #63

https://github.com/sy2002/MiSTer2MEGA65/issues/63 is the canonical V2.1.0 tracker (title: *"Create a
V2.1.0 release in sync with the V6 version of the C64 core and with AExp"*). **These merges are a FUTURE
task, not this session** — but they define where the framework is going. Do **not** assume any of them is
already in `M2M/`; grep before claiming (only the QNICE bump has landed):

- **QNICE → `dev-V1.61`** — ✅ DONE on `develop` (commit `80cbba3`).
- **New SDRAM support** — on R6 the framework hands the core **two independent memory interfaces**
  (HyperRAM ~200 MB/s shared with ascal; SDRAM ~332 MB/s, otherwise idle) so a core can use both at once
  (C64 R6: SIMCRT on HyperRAM, SIMREU on SDRAM). From C64 `6a33db8`.
- **Reset fix** (C64MEGA65 #226), **video filter improvements** (C64MEGA65 #223 — AExp backported a
  polyphase loader as a stopgap, flagged for deletion at V2.1+), **file-browser algorithmic speedup**
  (C64MEGA65 #228 — the `llist.asm` mergesort rewrite; not yet present here, §4.5), and moves of
  C64MEGA65 #229/#230.
- **AExp upstreams:** the `HANDLE_CORE_IO` core-io-hook + the `m2m-rom.asm` polling extension for
  writeable disks, and the debounce hack (AExp #4).
- **`make_release.py`** (both cores ship one) — bring it in with a default TOML.
- **Port `config.vhd` comments** that point to the new Wiki articles into the framework.
- **More than one drive 8** — issue #63 also links C64MEGA65 #93 (supporting more than just "drive 8").
- **Bugfixes (would be V2.0.2):** keyboard dies after leaving the menu (#58); vdrive `sd_lba_i[]` array
  swap (#57); possible `XOR 0, R9` bug in `shell.asm` (#52).

---

## 10. The Wiki (`../MiSTer2MEGA65.wiki/`) — status

The Wiki is a **separate repo**; parts are outdated. **Trust `Home.md`'s tiering, and the actual source
code, over any individual page.** The three intro/tutorial pages (see below) are now up to date with the
current framework; updating the **rest** of the Wiki is still a future task.

- **Canonical (2026-dated):** `The-Ultimate-MiSTer2MEGA65-Porting-Guide.md` (the new main reference, uses
  C64MEGA65 as running example), `Home.md`, and the topic pages Home.md lists as current
  (`On-Screen-Menu-(OSM).md`, `Welcome and Help Screens.md`, `config.vhd-Switches-and-Settings.md`,
  `make_release.py.md`). (`Devices.md` and `Video-pipeline-and-output.md` were edited in 2026 but `Home.md`
  still files them under its "Deprecated Reference Guide" — trust the tiering.)
- **Up to date (2026) — verified against the current framework:** `1.-What-is-MiSTer2MEGA65.md`,
  `2.-First-Steps.md`, and `3.-"Hello-World"-Tutorial.md` (the filename literally embeds quotes) — the three
  intro/tutorial pages are current on facts, links, and images:
  - **Facts:** board support is R3/R3A/R4/R5/R6 (the "R2 planned" claim is gone); the board tops and
    constraints are framework-owned (`M2M/vhdl/top_mega65-rX.vhd`, `M2M/MEGA65-RX.xdc` + `M2M/common.xdc`,
    top entity `mega65_rX`, bitstream `mega65_r3.bit`); the top instantiates `i_framework` and `CORE`
    **side by side** (there is no wrapping `M2M` / `m2m.vhd` module); tutorial 3 tracks the 35-item template
    menu in `config.vhd` (`OPTM_SIZE` 35, `C_MENU_*` in `mega65.vhd`, the `clk_main_speed_i` port on
    `entity main`); and packaging a `.cor` now uses **`coretool`** (the modern replacement for `bit2core`,
    which is documented as the legacy equivalent).
  - **Links:** dead/stale links fixed — mega65-tools binaries now come from the **MEGA65 Filehost**
    (`files.mega65.org`; the old `releases/tag/CI-latest` 404s), the README link targets the repo root
    (default branch is `development`; `master` is gone), and Vivado downloads from **AMD** (the `xilinx.com`
    URL 301-redirects). The YouTube / Trenz / C64 `#some-demo-pictures` links were verified live.
  - **Images:** the two structural graphics (`firststeps-structure.png`, `firststeps-layout.png`) were
    **factually wrong** — they drew a phantom `M2M : m2m (m2m.vhd)` wrapper and the old `CORE_R3` top — and
    were replaced with **Mermaid** diagrams (GitHub wikis render Mermaid). The remaining screenshots
    (`firststeps-intro.png`, `template.jpg`, `osm_i.png`) are current; `osm_i.png` already shows the
    `clk_main_speed_i` port. **Still `bit2core`, not audited here:** the release page
    `How-to-release-...` and the big `The-Ultimate-...Porting-Guide.md`.
- **Known-wrong — do not use for the current architecture:**
  - `Architecture.md` is a `@TODO` stub describing an **unbuilt** HAL design (`hal_mega65_rX.vhd`) — those
    files do not exist; the real hierarchy is `framework.vhd` + `top_mega65-r{3..6}.vhd`.

Cosmetic leftovers in the framework itself (not bugs, but don't be misled): the template board tops and
`CORE/vhdl/*` files still carry "Commodore 64 for MEGA65" headers because they were lifted from the C64
core; `keyboard.vhd`'s "bit 0=Space, 1=Return, 2=Run/Stop" comment is stale (the code mirrors all 80 keys).

---

## 11. Gotchas & do-not-touch (consolidated)

- **`M2M/` interfaces are a public contract** — every change must be backward-compatible (§8).
- **Menu line index = OSM control bit = `C_MENU_*`** in `mega65.vhd`. Editing the menu silently
  desyncs the AV mux unless you update the indices. `OPTM_SIZE` = #`OPTM_ITEMS` = #`OPTM_GROUPS`.
- **QNICE reads/writes on the falling edge** — every QNICE-shared BRAM/register must honor it.
- **Editing `M2M/QNICE/vhdl/mmio_mux.vhd` or `env1_globals.vhd` does nothing** — the M2M copies in
  `M2M/vhdl/QNICE/` shadow them in the build.
- **HyperRAM: 16-bit, word-addressed, `addr(31)=1` = register space, not RAM.** A core drives `hr_core_*`;
  cross clock domains with `avm_fifo` (and usually `avm_cache`). `avm_memory/rom/memory_pause/pause` are
  sim-only.
- **HyperRAM reset is coupled to the core reset** on purpose (`clk_m2m.vhd:183-186`).
- **`cart_en_o <= '1'` is a required R5/R6 workaround**, not dead code (joystick port 2).
- **Flicker-free is computed but not wired** in the template — a core must connect `hr_high_i`/`hr_low_i`
  to a dynamic clock to use it.
- **`crop.vhd` zoom borders are hardcoded to a 320×200 (C64) image** — per-core if you change native res.
- **`av_pipeline/vga_controller.vhd` and `av_pipeline/frame_buffer.vhd` are DEAD CODE** (not in the build);
  the live `vga_controller` is `M2M/vhdl/democore/vga_controller.vhd`.
- **`doc/temp/*` are non-authoritative scratch notes** — verify against source before trusting them.
- Generated firmware files and `m2m-rom.rom` are build artifacts — regenerate, never hand-edit.
- Every `globals.vhd` device/vdrive/CRT array must terminate with `x"EEEE"`.

---

## 12. When developing / debugging — quick orientation

| Area | Files to look at first |
| --- | --- |
| Framework↔core wiring | `CORE/vhdl/mega65.vhd` (contract), `M2M/vhdl/framework.vhd`, `M2M/vhdl/top_mega65-rX.vhd` |
| Clocks / resets | `CORE/vhdl/clk.vhd`, `M2M/vhdl/clk_m2m.vhd`, `reset_manager.vhd`, board-top reset-OR |
| OSM menu / help text | `CORE/vhdl/config.vhd` (OPTM_ITEMS/GROUPS/WHS), `C_MENU_*` in `mega65.vhd` |
| Shell behavior / menu engine | `M2M/rom/{shell,options,menu}.asm`; callbacks in `CORE/m2m-rom/m2m-rom.asm` |
| File / directory browser, sort | `M2M/rom/{selectfile,dirbrowse,llist}.asm` (emulator testbeds alongside) |
| Disk mount / vdrive / write-back | `M2M/vhdl/vdrives.vhd`, `M2M/rom/vdrives.asm`, `shell.asm` (`HANDLE_IO`/`FLUSH_CACHE`) |
| ROM / cartridge loading | `M2M/rom/crts-and-roms.asm`, `qnice_csr.vhd`, `globals.vhd` (`C_CRTROMS_*`) |
| QNICE hardware / MMIO map | `M2M/vhdl/QNICE/{qnice,qnice_mmio,qnice_globals}.vhd`, `M2M/rom/sysdef.asm` |
| QNICE↔framework devices | `M2M/vhdl/qnice_wrapper.vhd` (device-id decode), `qnice2hyperram.vhd`, `sdmux.vhd` |
| HDMI tearing / flicker-free | `M2M/vhdl/hdmi_flicker_free.vhd`, `av_pipeline/digital_pipeline.vhd`, `ascal.vhd`, `controllers/HDMI/video_out_clock.vhd` |
| VGA / scandoubler / CSYNC | `av_pipeline/analog_pipeline.vhd`, `controllers/MiSTer/{scandoubler.v,csync.sv,video_mixer.sv}` |
| OSM rendering / scaling | `av_pipeline/{video_overlay,vga_osm,vga_recover_counters}.vhd`, `M2M/font/` |
| Video modes / resolutions | `av_pipeline/video_modes_pkg.vhd`, `framework.vhd` (VIDEO_MODE_VECTOR) |
| Audio | `av_pipeline/audio_out.v`, `globals.vhd` (filter coeffs), `controllers/M65/{audio.vhd,pcm_to_pdm.vhdl}` |
| HyperRAM PHY / arbiter | `controllers/hyperram/*`, `memory/avm_arbit*.vhd`, `memory/avm_{cache,fifo}.vhd` |
| Keyboard | `M2M/vhdl/m2m_keyb.vhd`, `controllers/M65/{mega65kbd_to_matrix,matrix_to_keynum}.vhdl`, `CORE/vhdl/keyboard.vhd` |
| I2C / RTC | `M2M/vhdl/i2c/*` (per-board device tables in `rtc_master.vhd`) |
| Per-board pinout / bring-up | `M2M/MEGA65-RX.xdc`, `M2M/common.xdc`, `M2M/vhdl/top_mega65-rX.vhd`, `controllers/M65/max10.vhdl` (R3) |
| Build / ROM / settings file | `CORE/m2m-rom/{make_rom.sh,synth_pre.tcl}`, `M2M/tools/make_config.sh`, `M2M/QNICE/tools/make-toolchain.sh` |
| Framework conventions | `doc/m2m/{example-file-headers,exceptions,m2m_migration}.md` |

---

## 13. Useful pointers

- Framework repo & Wiki: https://github.com/sy2002/MiSTer2MEGA65 · …/wiki (parts WIP — see §10)
- Reference cores: https://github.com/MJoergen/C64MEGA65 (public) · AExp (Amiga, local `../AExp/`)
- QNICE-FPGA: https://github.com/sy2002/QNICE-FPGA · https://qnice-fpga.com
- MEGA65: https://mega65.org · alternate cores: https://sy2002.github.io/m65cores/ · https://cores.mega65.org
- Upstream MiSTer cores: https://mister-devel.github.io/MkDocs_MiSTer/
- V2.1.0 tracker: https://github.com/sy2002/MiSTer2MEGA65/issues/63
- Community: the MEGA65 Discord (M2M has its own channel).
