# Ideas for Issue #28 — Greatly improved "retro look" and accuracy

*A working paper for the MiSTer2MEGA65 framework, written against the C64 for MEGA65, AExp (Amiga 500) and gbc4mega65 cores.*

---

## How to read this document

Issue #28 opens with an honest admission: *"I have no idea about all the magic that is happening in various retro projects."* This document is written to remove that gap, and it is written for exactly one reader profile: an experienced FPGA and systems engineer who has never had a reason to study video signal processing. Nothing below assumes prior DSP knowledge. Every term is defined the first time it is used, and every claim comes with a number.

The document has five parts:

* **Part I — The basics.** What a retro machine actually puts on the wire, how colour got onto that wire in 1953, why that decision produces every artefact we are chasing, and what the specific numbers are for the C64. Read this even if you skip everything else; the rest of the document is unreadable without it.
* **Part II — What everyone else has done.** Tom Harte's CLK, Blargg's NTSC filters, the CRT shader family, VICE, RGBtoHDMI/Lumacode, and MiSTer. Five different schools of thought, with an honest assessment of what each one costs.
* **Part III — Where M2M stands today.** An annotated walk through our own video pipeline, what it already does, and the measured resource budget we have to play with.
* **Part IV — A concrete plan.** Five tiers of implementation, from "one afternoon" to "a serious project", each with block diagrams, memory and multiplier counts, and menu design.
* **Part V — Reference.** Glossary, number tables, and links.

There is a **[TL;DR](#tldr)** immediately below for anyone who wants the conclusions without the education.

---

<a name="tldr"></a>

## TL;DR

1. **There are two completely separate problems hiding inside issue #28, and mixing them up is why the topic feels like "magic".** One is the **signal** problem: a real C64 never emitted RGB, it emitted a modulated composite waveform, and the receiver's imperfect decoding of that waveform is what fuses chequerboards into new colours and smears colour sideways. The other is the **tube** problem: scanlines, shadow mask, phosphor glow, gamma. They need different solutions, they live at different points in the pipeline, and M2M has already largely solved the second one while not having touched the first one at all.

2. **What paich64 is asking for in [C64_MiSTer#104](https://github.com/MiSTer-devel/C64_MiSTer/issues/104) is the signal problem, specifically its cheapest 10%.** "ALM" and "DCM" are community names for two ways of exploiting one single physical fact: a PAL television averages the colour of each line with the line above it, and blurs colour horizontally over roughly six C64 pixels. Games like *Mayhem in Monsterland* — and, per paich64, *Sam's Journey* — paint two colours in a fine pattern and let the TV do the mixing. Our cores show the raw pattern instead, because they hand the display finished RGB pixels.

3. **The FPGA has room. That is the headline finding.** Measured from the current C64 for MEGA65 build (`CORE/CORE-R6.runs/impl_1/mega65_r6_utilization_placed.rpt`, 31 July 2026): all four board revisions target `xc7a200tfbg484-2`; we use **25% of the LUTs, 10% of the flip-flops, 48% of the block RAM and 10% of the DSP48 slices**. That leaves roughly **665 free DSP48E1 multipliers and 190 free 36 kbit block RAMs**. The `main_clk` domain, where all of this work would live, closes timing with **9.42 ns of slack** on a 31.7 ns period. A full composite modulator plus demodulator costs on the order of 60 DSP slices and 2 block RAMs — 8% of the device. **We are not silicon-limited. We are effort-limited.**

4. **Half the hardware already exists in our own repositories, dormant.** `AExp/CORE/Minimig_MiSTerMEGA65/sys/yc_out.sv` is a complete, working PAL/NTSC composite *encoder* in SystemVerilog — phase accumulator, sine table, YUV matrix, PAL line switch, colour burst — sitting unused because M2M replaces MiSTer's `sys_top.v`. `M2M/vhdl/controllers/MiSTer/gamma_corr.sv` and `hq2x.sv` are likewise present and wired to `open` / `'0'` in `analog_pipeline.vhd:148-149`.

5. **The arithmetic is unusually kind to us.** At the C64 core's main clock the PAL colour subcarrier advances **9/64 of a cycle per clock**, and NTSC exactly 7/64 — both exact 64ths. A 6-bit phase accumulator with an increment of 9 is a drift-free subcarrier: no numerically controlled oscillator, no new clock, no clock-domain crossing. See [§4.4](#c64-numbers) for the one honest qualifier (the MEGA65 PLL is 5.6 ppm slow, which cancels in a closed encode/decode loop).

6. **Recommended build order.** *Tier 0* (palette and gamma correctness, days) → *Tier 1* (PAL line blending in the colour-index domain, ~1 block RAM, no multipliers, this alone delivers what issue #104 asks for) → *Tier 2* (horizontal chroma bandwidth limiting, ~20 DSPs, delivers the chequerboard/DCM effect and general "PAL softness") → *Tier 3* (real modulate/demodulate, ~60 DSPs + 2 BRAM, delivers dot crawl, cross-colour, and correctness for machines whose colours *are* artefacts). Tiers 1 and 2 together get 90% of the visible benefit for maybe 15% of the effort of tier 3.

7. **The single best architectural decision is to insert one module in one place**: at the top of `M2M/vhdl/av_pipeline/av_pipeline.vhd`, upstream of both `i_analog_pipeline` (line 397) and `i_crop`/`i_digital_pipeline` (lines 532/555). One instance, one clock domain (`video_clk` = the core clock), and both the VGA and the HDMI output benefit. Because each pipeline composites the on-screen menu *downstream* of that point, the OSM stays pixel-crisp for free.

8. **Do not do this only for the C64.** For the C64 it is a beauty feature. For an Apple II-class machine it is a *correctness* feature, because the colours literally do not exist without composite decoding. For the Amiga (AExp) most of this does *not* apply — an A500 drove analog RGB into a 1084, so there are no composite artefacts to reconstruct — though the same encoder would give it a genuine S-Video output over the VGA port. For gbc4mega65 the answer is different and simpler: a Game Boy has no CRT and no composite signal at all, and its authentic look is LCD ghosting plus colour correction — see [§24.3](#gbc).

---

# Part I — The basics

<a name="ch1"></a>

## 1. There are no pixels

Start here, because every misconception in this field comes from skipping this paragraph.

A Commodore 64 does not produce an image. It produces a **voltage that varies over time**, together with timing marks that tell the display when to snap back to the left edge (horizontal sync) and when to snap back to the top (vertical sync). A cathode ray tube sweeps an electron beam across a phosphor-coated screen at an essentially constant speed and modulates the beam current with that voltage. Nowhere in that chain does anything have a concept of a "pixel". The pixel is a fiction that *we* impose, at the moment we decide to sample the waveform at some rate.

Two consequences follow, and they are not symmetric:

* **Vertically, resolution is genuinely quantised.** Lines are discrete physical sweeps. There really are 312 of them per frame on a PAL C64. This is why "scanlines" are a meaningful visual effect.
* **Horizontally, resolution is not quantised at all.** It is a *bandwidth*. If the signal is band-limited to 5 MHz, the picture cannot contain detail finer than about 100 ns, no matter what the machine intended. There is no such thing as a "scancolumn".

That asymmetry is the origin of nearly everything in this document. Anything that limits horizontal bandwidth — the machine's own video output stage, the cable, the TV's input filters, the tube's beam width — smears the picture *sideways only*, continuously, and by an amount measured in nanoseconds rather than in pixels.

An FPGA core, by contrast, is a machine that produces pixels and nothing but pixels. It computes a colour index, looks up an RGB triple, and hands that triple to a scaler. The waveform never exists. This is why FPGA cores look "too clean": we are not failing to *add* an effect, we are failing to *pass through* a process that the original hardware could not avoid.

> **The mental model to carry through the whole document:** a retro machine's picture is the result of a signal chain. Our cores implement the two ends of that chain and skip the middle. Issue #28 is a request to put some of the middle back.

<a name="ch2"></a>

## 2. Getting colour down one wire

In 1953 the NTSC committee had a hard constraint: add colour to television without using more bandwidth and without breaking the millions of black-and-white sets already in living rooms. The solution they found is elegant, slightly outrageous, and is the direct cause of every artefact we are chasing.

### 2.1 Luma and chroma

First, do not transmit red, green and blue. Transmit **luminance** (brightness, called `Y`) and two **colour-difference** signals. `Y` is a weighted sum of R, G and B that matches how bright the eye perceives the colour:

```
Y = 0.299 R + 0.587 G + 0.114 B
```

The two colour-difference signals are then simply what is left over:

```
U = 0.492 (B - Y)
V = 0.877 (R - Y)
```

(The odd scaling factors exist so that the combined signal never exceeds the legal voltage range. The same pair is called `I`/`Q` in classic NTSC, rotated by 33 degrees; PAL uses `U`/`V`.)

A black-and-white set ignores `U` and `V` and displays `Y`. Backwards compatibility solved. Note also that `Y` alone carries all of the detail the eye is most sensitive to, which sets up the next trick.

### 2.2 The subcarrier

Now the two colour-difference signals have to travel on the same wire as `Y` without disturbing it. The trick is **quadrature amplitude modulation**: take a high-frequency sine wave (the *colour subcarrier*), and use `U` to scale a sine and `V` to scale a cosine of that same frequency:

```
C(t) = U·sin(2π·f_sc·t) + V·cos(2π·f_sc·t)

composite(t) = Y(t) + C(t)
```

Two independent numbers ride on one frequency because sine and cosine are orthogonal — the receiver can separate them again by multiplying by sine and by cosine respectively and averaging. In polar terms, `C` is a single sine wave whose **amplitude is the colour saturation** and whose **phase is the hue**. Hold that thought: hue *is* phase. It is the single most important sentence in this document.

The subcarrier frequency is chosen to sit in a "gap". A scanned picture's spectrum is not smooth: it clusters into bunches around multiples of the line frequency. Choosing `f_sc` to be an odd multiple of half the line frequency drops the chroma energy neatly between the luma bunches, so the two interleave rather than collide. On a static picture this also makes the chroma pattern invert on every field, so the eye averages it away.

### 2.3 The colour burst

The receiver needs to know where phase zero is, otherwise every hue is wrong. So every single line begins with a short reference: about 9 to 10 cycles of the unmodulated subcarrier, transmitted during the "back porch" after horizontal sync, in the part of the line that is off-screen. This is the **colour burst**. A receiver locks a local oscillator to it and uses that oscillator for the whole line.

You can see this in real FPGA code. In MiSTer's `yc_out.sv`, which is sitting in the AExp repository right now, the burst is generated for exactly nine cycles at a fixed offset from sync:

```verilog
// Generate Colorburst for 9 cycles
if (cburst_phase >= COLORBURST_RANGE[16:10] && cburst_phase <= COLORBURST_RANGE[9:0]) begin
    phase[2].u <= $signed({chroma_SIN_LUT[chroma_LUT_BURST],5'd0});
    phase[2].v <= 21'b0;
```

### 2.4 The bandwidth asymmetry, and why it matters more than anything else

The human eye has far worse spatial acuity for colour than for brightness. Broadcasters exploited this ruthlessly: the chroma signal is deliberately given **much less bandwidth** than luma.

| Signal | Typical bandwidth | What it means in time |
|---|---|---|
| PAL luma (`Y`) | about 5 MHz (5.5 MHz in a good System B/G set) | detail down to about 100 ns |
| PAL chroma (`U`, `V`) | about 1.3 MHz each | detail no finer than about 400 ns |
| NTSC luma | about 4.2 MHz | about 120 ns |
| NTSC chroma (`I` / `Q`) | 1.3 MHz / 0.4 MHz in the ideal standard; roughly 0.6 MHz for both in cheap sets | 400 ns to 800 ns |

Now put a C64 next to that table. A PAL C64 pixel is one dot-clock period long: **127 ns**. Chroma detail finer than about 400 ns simply does not survive. In other words:

> **On a real PAL C64, brightness has full pixel resolution and colour has roughly one third of it, smeared over something like five or six pixels.**

That single fact explains the checkerboard trick, the "luma-driven graphics" school, the softness of C64 sprites on a TV, and half of why an emulator screenshot looks wrong to someone who grew up with the machine.

<a name="ch3"></a>

## 3. PAL, NTSC, and the delay line

NTSC's weak point is that hue is phase, and phase drifts. A group delay error anywhere in the transmission path rotates every hue. Viewers had a tint knob and used it constantly; the joke expansion of the acronym was "Never Twice the Same Colour".

PAL's fix is in its name: **Phase Alternating Line**. On every second line, the transmitter inverts the sign of `V`:

```
even lines:  C = U·sin(ωt) + V·cos(ωt)
odd  lines:  C = U·sin(ωt) - V·cos(ωt)
```

Again this is visible in real hardware. `yc_out.sv` implements exactly this, flipping a bit at each hsync:

```verilog
// Calculate for chroma (Note: "PAL SWITCH" routine flips V * COS(Wt) every other line)
if (PAL_EN) begin
    if (PAL_FLIP)
        phase[4].c <= vref + phase[3].u - phase[3].v;
    else
        phase[4].c <= vref + phase[3].u + phase[3].v;
```

If the path introduces a phase error, that error pushes the hue one way on even lines and the opposite way on odd lines. Two adjacent lines therefore have *complementary* errors. Average them and the error cancels, leaving only a small loss of saturation, which nobody notices.

### 3.1 The 64 µs glass delay line

Early PAL sets did the averaging in the viewer's eye — two adjacent lines with opposite errors, seen from a normal viewing distance, look correct. That is "PAL-S" (simple). Better sets did it properly, in hardware, with an **ultrasonic glass delay line**: a block of glass in which the chroma signal travels as an acoustic wave and emerges exactly one line period later (64 µs). The receiver then computes:

```
U_displayed(line n) = ( U(line n) + U(line n-1) ) / 2
V_displayed(line n) = ( V(line n) - V(line n-1) ) / 2      ← sign handled by the PAL switch
```

That is "PAL-D" (delay line), and it is what virtually every PAL television made after the mid-1970s does. (A C64 PAL line is 63.943 µs, i.e. exactly 504 dot clocks — 0.09% shorter than the 64 µs broadcast line. In an FPGA implementation the delay is therefore trivially exact: same column, previous line.)

**Read that formula again, because it is the entire point of MiSTer issue #104.** On a PAL television:

* **Luma is *not* averaged between lines.** Brightness detail stays at full vertical resolution.
* **Chroma *is* averaged between lines, always, unconditionally, in every PAL set.** Colour has, in effect, half the vertical resolution.

So if a C64 programmer paints colour A on even rows and colour B on odd rows within a character block, a PAL television does not show stripes. It shows the *average hue* of A and B, at whatever brightness each individual line has. The programmer has just created a colour the VIC-II cannot produce. This is what the community calls the "alternate line method" (ALM); on the horizontal axis the same idea using a fine checkerboard, exploiting the chroma bandwidth limit from §2.4 instead of the delay line, is called the "dynamic checkerboard method" (DCM).

`mrdudz` is right in the issue thread when he says the terminology is home-grown and that the underlying phenomenon is simply PAL colour mixing. He is also right that this is the cheap part to implement. Both facts can be true, and the naming argument is not worth having; what matters is that the physical mechanism is completely unambiguous and is described by the two lines of arithmetic above.

### 3.2 NTSC has no delay line

NTSC does not alternate phase, so there is no vertical averaging to speak of. NTSC machines got their "extra" colours the other way, horizontally: a fine luma pattern at the right frequency *is* a chroma signal as far as the decoder is concerned, and gets decoded as colour. That is **cross-colour**, and on the Apple II it is not a bug but the entire colour system (see [§24.2](#aexp)). It is also why the same C64 program looks different on an NTSC machine, and why any feature we build has to be mode-aware rather than hard-wired to PAL.

<a name="ch4"></a>

<a name="c64-numbers"></a>

## 4. The C64, in numbers

Everything above becomes concrete once you write down the actual frequencies. All values here are derived from the master crystal; the derivations are shown so they can be checked.

### 4.1 PAL (6569 VIC-II)

| Quantity | Value | Derivation |
|---|---|---|
| Master crystal | 17.734475 MHz | `4 ×` the PAL colour subcarrier |
| Colour subcarrier `f_sc` | 4.43361875 MHz | crystal `/ 4` |
| CPU clock `phi2` | 985 248.6 Hz | crystal `/ 18` |
| Dot clock | 7.881989 MHz | `8 × phi2` |
| Dot period | 126.87 ns | |
| Line length | 504 dots = 63 `phi2` cycles | |
| Line frequency | 15 638.87 Hz | |
| Lines per frame | 312 | |
| Frame rate | 50.1246 Hz | |
| **Subcarrier cycles per line** | **283.5** | `4.5 phi2 × 63 phi2/line` |

That last row deserves attention. Broadcast PAL uses 283.7516 cycles per line. The C64 uses exactly 283.5 — that is, 283 and a *half*. A half-cycle offset per line means **the subcarrier phase inverts exactly every line**, giving a rigid two-line repeat instead of broadcast PAL's four-field dance. The C64's PAL output is, in this specific respect, not standards-compliant; the pattern it produces on screen is correspondingly stable and strong, which is precisely what makes line-based colour tricks reliable on the machine.

### 4.2 NTSC (6567R8 VIC-II)

| Quantity | Value | Derivation |
|---|---|---|
| Master crystal | 14.31818 MHz | `4 ×` the NTSC colour subcarrier |
| Colour subcarrier | 3.579545 MHz | crystal `/ 4` |
| CPU clock `phi2` | 1 022 727 Hz | crystal `/ 14` |
| Dot clock | 8.181818 MHz | `8 × phi2` |
| Line length | 520 dots = 65 `phi2` cycles | |
| Line frequency | 15 734.3 Hz | matches the NTSC standard exactly |
| **Subcarrier cycles per line** | **227.5** | `3.5 phi2 × 65 phi2/line` — the textbook NTSC value |

The NTSC C64 is a well-behaved NTSC source; the PAL C64 is a slightly eccentric PAL source. Worth knowing before anyone tries to explain a discrepancy as a bug.

### 4.3 What the VIC-II actually emits

The VIC-II does not have an RGB output and never did. Per pixel it emits:

* one of **8 luminance levels**, and
* for the eleven chromatic colours, one of **eight hue angles** — black, white and the three greys carry no chroma at all.

Some colours share a hue angle and differ only in luminance (Red and Light Red; Green and Light Green; Blue and Light Blue). That is worth noticing, because it is exactly the pairs that share a *luma cluster* but differ in hue which the alternating-line trick exploits.

Sixteen colours are therefore sixteen `(luma, phase)` pairs, and the palette we all know is a *reconstruction* of what those pairs turn into after an ideal decoder. This is why "the C64 palette" has been argued about for twenty years and why there are several competing tables. The best-known reconstructions are **Pepto's** (from measurements and the VIC-II schematics) and its successor **Colodore**, which adds a proper gamma model.

Our core uses the **Colodore** table (checked value by value against the reference). It is a plain combinational case statement in `CORE/C64_MiSTerMEGA65/rtl/fpga64_rgbcolor.vhd:37-54`:

```vhdl
when X"0" => r <= X"00"; g <= X"00"; b <= X"00";
when X"1" => r <= X"FF"; g <= X"FF"; b <= X"FF";
when X"2" => r <= X"81"; g <= X"33"; b <= X"38";
when X"3" => r <= X"75"; g <= X"ce"; b <= X"c8";
...
```

and it is instantiated *inside* the MiSTer core, at `fpga64_sid_iec.vhd:653`, where the internal signal `vicColorIndex` is converted and then thrown away:

```vhdl
c64colors: entity work.fpga64_rgbcolor
port map (
    index => vicColorIndex,
    r => r,
    g => g,
    b => b
);
```

`vicColorIndex` is declared at `fpga64_sid_iec.vhd:279` and is **not** part of the entity's port list. Exporting it is a one-line change, and as [§18](#tier1) shows, it makes the cheapest tier of this whole project dramatically cheaper: about six times less memory, and no per-pixel arithmetic at all instead of roughly ten multiplies.

### 4.4 The gift: exact subcarrier arithmetic at our clock

The C64 core runs on a main clock of `32 × phi2` — nominally 31.527956 MHz, and 31.527778 MHz as actually synthesised by the MEGA65's MMCM. Now divide:

```
PAL :  f_sc / clk_main = 4.5 phi2 / 32 phi2 = 9 / 64   exactly
NTSC:  f_sc / clk_main = 3.5 phi2 / 32 phi2 = 7 / 64   exactly
```

Both are exact 64ths *of the ideal relationship*. One honest qualifier: the MEGA65's MMCM synthesises 31.527778 MHz rather than the ideal 31.527956 MHz, so an absolute subcarrier generated this way lands 5.6 ppm (about 25 Hz) low. That does not matter here, because inside the FPGA the ratio `main_clk : dot clock : generated subcarrier = 64 : 16 : 9` is exact *by construction* — all three are derived by integer division from the same clock — and because any encode/decode pair shares one counter, so the error cancels identically in the loop.

What it means practically: **a 6-bit phase accumulator incremented by 9 (PAL) or 7 (NTSC) on every main clock reproduces the subcarrier phase perfectly and forever**, with zero accumulated error, using an adder and no multiplier at all. Compare that with the general case, where you need a 32- or 40-bit accumulator and accept slow phase drift — which is exactly what `yc_out.sv` has to do because it must serve arbitrary cores:

```verilog
input  [39:0] PHASE_INC,
...
phase_accum <= phase_accum + PHASE_INC;
chroma_LUT  <= phase_accum[39:32];
```

We can do better on the C64 than the generic MiSTer module does, essentially for free. Note also the sampling headroom: at 31.53 MHz we have **7.11 samples per subcarrier cycle**, comfortably above the classic "4× f_sc" sampling used by real digital TV decoders. There is no need to invent a new clock domain for any of this work.

One warning that follows immediately from the same arithmetic: **none of the composite work can happen at the pixel rate.** The dot clock is 7.88 MHz, so its Nyquist limit is 3.94 MHz — *below* the 4.43 MHz subcarrier. A composite signal simply cannot be represented at the pixel clock. Any tier that touches a subcarrier must run at the full 31.5 MHz main clock, one sample per clock, 2016 samples per line.

<a name="ch5"></a>

## 5. And then there is the tube

Everything so far concerned the *signal*. A second, entirely independent set of effects happens after the signal reaches the display. Keeping these two categories apart is the single most useful piece of hygiene in this field, because they need different techniques, cost different amounts, and belong at different points in a pipeline.

| Effect | What it is | Where it belongs |
|---|---|---|
| **Beam spot / horizontal blur** | The electron beam is a Gaussian blob, not a point. Adjacent samples overlap. | Signal-rate or output-rate, horizontal only |
| **Scanlines** | The beam draws 312 discrete lines with gaps between them. Visible only if the output has more vertical resolution than the source. | After upscaling |
| **Phosphor mask / aperture grille** | The screen is a grid of R, G and B phosphor stripes or dots. Fine structure, only visible at high output resolution. | After upscaling, at output resolution |
| **Phosphor persistence** | Phosphor keeps glowing for a few milliseconds after the beam passes; bright objects trail slightly. | Needs a frame buffer |
| **Bloom / halation** | Very bright areas spill light into neighbours, in the glass and in the eye. | After upscaling |
| **Gamma** | A CRT's brightness is roughly `input^2.4`; an LCD fed sRGB is not the same curve. Getting this wrong makes everything else look wrong. | Everywhere, and it must be right *before* any blending |
| **Geometry / overscan** | Slight curvature, and the fact that a TV crops the edges of the picture. | Output stage |

**M2M has already implemented a decent share of this list** (see [§14](#what-we-have)): the polyphase scaler in `ascal.vhd` provides scanlines and horizontal softening through downloadable filter coefficient sets, and the C64 core's V6 menu already offers *Scanlines*, *CRT (S-Video)* and *CRT (Composite)* presets. What M2M has *not* touched at all is the signal half of the story. That is the actual content of issue #28, and it is why "add another filter preset" will never produce the effect paich64 is asking for: no amount of blurring RGB can turn two alternating rows of colour into a third colour, because the information that they were *chroma* was destroyed the moment the palette lookup happened.

> **Slogan for the rest of this document:** you cannot un-bake a cake with a blur kernel. If you want composite behaviour, you have to reintroduce the concept of chroma somewhere.

---

# Part II — What everyone else has done

<a name="ch6"></a>

## 6. Five schools of thought

Every project that has ever tried to make an emulated retro machine look right belongs to one of five families. They are usually presented as rivals. They are not: the first four are alternative solutions to the *signal* problem, and the fifth solves the *tube* problem and composes with any of them.

| # | School | Core idea | Where the arithmetic happens | Fidelity | FPGA portability | Representatives |
|---|---|---|---|---|---|---|
| 1 | **Signal simulation** | Actually encode the machine's output to composite and actually decode it | Per sample, at 8-40 MHz | Highest — artefacts emerge instead of being added | Good, once you accept a sample-rate pipeline | Tom Harte's CLK, Bisqwit's NES decoder |
| 2 | **Precomputed kernels** | Run the entire encode/decode chain offline for every (colour, phase) pair, ship the answer as a table | Offline; at runtime, table reads and adds | Very high for the horizontal axis | Excellent — zero multipliers | Blargg's `nes_ntsc`, AppleWin |
| 3 | **Palette-pair blending** | Model only the single dominant artefact — line-to-line chroma averaging — as a 256-entry lookup | Offline; at runtime, one table read | Low but *targeted*: it nails the one effect people ask for | Excellent — one line buffer, one ROM | VICE "fast PAL", RGBtoHDMI |
| 4 | **Colour-space filtering** | Convert to YUV, apply the two physically real filters (horizontal chroma low-pass, vertical chroma delay line), convert back | Per pixel, at the machine's own dot clock | High for everything except cross-colour and dot crawl | Very good — a handful of multipliers | VICE's modern PAL renderer |
| 5 | **Tube cosmetics** | Leave the signal alone; model the glass — scanlines, mask, beam, gamma, bloom | Per output pixel, after upscaling | Orthogonal | Mixed: masks and scanlines are trivial, curvature and persistence are not | CRT-Royale, crt-lottes, MiSTer's shadow masks, **and M2M's existing polyphase filters** |

M2M today implements exactly one of these — school 5, partially, via `ascal`'s polyphase coefficient sets. Issue #28 is a request to add something from schools 1 to 4.

A useful way to hold all of this in your head: schools 1 and 2 are the same physics, differing only in whether you evaluate it at runtime or bake it into a table. School 4 is what you get when you notice that a machine like the C64 already *has* chroma as a separate quantity, so you can skip the modulation step entirely and filter chroma directly. School 3 is school 4 with only one of the two filters, and that filter reduced to a lookup.

<a name="ch7"></a>

## 7. Tom Harte's CLK — "decode the real signal"

This is the project issue #28 links to, and it is worth understanding properly, because its philosophy is genuinely different from everything else in the emulation world.

### 7.1 The philosophy, in Harte's own words

From the CLK README, section *Signal Processing*:

> Consider an ordinary, unmodified Commodore Vic-20. Its only video output is composite. Therefore the emulated machine's only video output is composite. In order to display the video output, your GPU must decode composite video. Therefore composite video artefacts are present and correct — not because of a post hoc filter but because the real signal is really being processed.

That last clause is the whole idea. CLK does not have an "NTSC artefact" feature. It has a composite decoder, and artefacts are what a composite decoder does when you feed it a machine that was designed to exploit them.

### 7.2 The contract: a machine declares what it emits, a user picks how to view it

The central abstraction is `Outputs/ScanTarget.hpp`. A machine describes its output with an `InputDataType`:

```cpp
Luminance1,             // 1 byte/pixel; any bit set => white; no bits set => black.
Luminance8,             // 1 byte/pixel; linear scale.
PhaseLinkedLuminance8,  // 4 bytes/pixel; ... which value is output is a function of
                        // colour subcarrier phase — byte 0 defines the first quarter
                        // of each colour cycle, byte 1 the next quarter, etc.
Luminance8Phase8,       // 2 bytes/pixel; first is luminance, second is phase
                        // of a cosine wave.
Red1Green1Blue1, Red2Green2Blue2, Red4Green4Blue4, Red8Green8Blue8,
```

and the *user* independently picks a `DisplayType`:

```cpp
enum class DisplayType { RGB, SVideo, CompositeColour, CompositeMonochrome };
```

Any input type can be shown on any display type. Feed RGB into a composite display and CLK will encode it to composite and then decode it again — which is precisely the trick an FPGA implementation would use for a core that only has RGB available.

`Luminance8Phase8` is the important one for us: *"first is luminance, second is phase of a cosine wave. Phase is encoded on a 128-unit circle; anything greater than 192 implies that the colour part of the signal should be omitted."* That is an S-Video source described exactly the way a VIC-II works. CLK's Plus/4 (TED) driver encodes it with a 16-entry table that would be almost character-for-character identical for a VIC-II (`Machines/Commodore/Plus4/Video.hpp:728-744`):

```cpp
uint16_t colour(uint8_t chrominance, uint8_t luminance) const {
    static constexpr uint8_t chrominances[] = {
        0xff, 0xff, 90, 23, 105, 59, 14, 69, 83, 78, 50, 96, 32, 9, 5, 41, };
    luminance = chrominance ? uint8_t((luminance << 5) | (luminance << 2) | (luminance >> 1)) : 0;
    return uint16_t(luminance | (chrominances[chrominance] << 8));
}
```

Only four machines in the whole of CLK emit luma-plus-phase: the VIC-20's 6560, the Plus/4's TED, the Atari 2600's TIA, and (in the phase-linked variant) the Oric.

### 7.3 The pipeline

1. **Composition (encode).** Each scan is rasterised into a 3072-pixel-wide line buffer whose horizontal axis is *time since horizontal retrace*, not screen position. That buffer holds a genuine one-dimensional sampled composite signal. The encode is one line of shader:
   `composite = Y·(1−2A) + (U·cosφ + V·sinφ)·A + A`, where `A` is the burst amplitude (default 41/255 ≈ 0.161, derived from the real black-level-to-burst-peak ratios of NTSC and PAL).
2. **Separation.** A **31-tap** filter pair splits luma from chroma, then quadrature demodulation multiplies by the stored `cos φ` and `sin φ`.
3. **Demodulation.** Another **31-tap** low-pass cleans the U and V products, then a 3×3 matrix and optional gamma produce RGB. Notably, the *luma* demodulation filter is one tap — `const float identity[] = { 1.0f };` with the comment "Don't filter luminance at all."
4. **Line output, phosphor decay, field mixing.** Lines are drawn into a persistent framebuffer; a "frame cleaner" pass fades whatever was not repainted; the final blit mixes the two most recent fields.

The filters are designed at runtime by a **Kaiser-Bessel windowed FIR designer** (`SignalProcessing/FIRFilter.cpp`, citing *Digital Signal Processing II*, IEEE Press) at 60 dB stop-band attenuation. The luma filter measures `|H(0)| = 1.000` and `|H(f_sc)| = 0.0009`, i.e. a 61 dB notch exactly at the subcarrier.

The line buffer is oversampled: `MinColourSubcarrierMultiplier = 8.0f`, so CLK always works at 8 or more samples per colour cycle.

### 7.4 Apple II artefact colour: the proof of the philosophy

The Apple II feeds CLK **one bit per pixel** (`Luminance1`) at 910 cycles per line into an NTSC CRT whose subcarrier is 227.5 cycles per line. `910 / 227.5 = 4` exactly — four dots per colour cycle. There is no artefact-colour table anywhere in CLK, no Apple II branch in any shader; a grep for "artefact" or "artifact" in the entire `Outputs/` tree returns nothing. The colours simply fall out of the ordinary decode chain, exactly as they fall out of a real television.

That is the single most persuasive argument for school 1, and it should be kept in mind for any future MEGA65 Apple II core.

### 7.5 What CLK does *not* do — and why it matters here

**CLK models PAL's phase alternation but not PAL's delay line.** The alternation is real: `should_be_alternate_line_ ^= phase_alternates_` per retrace, expressed as a sign flip on the emitted subcarrier angle. But the decoder is strictly one-dimensional — every filter tap offsets in X only, and each line is drawn as an independent quad. There is no comb filter and no line averaging anywhere.

The consequence deserves to be stated bluntly, because it is easy to assume otherwise:

> **A faithful port of CLK's decoder would *not* fix *Mayhem in Monsterland*.** The alternate-line colour fusion that issue #104 is about comes from the receiver's 64 µs delay line, which CLK does not have. CLK would give us dot crawl, cross-colour and correct Apple II colours; it would not give us ALM.

### 7.6 What a CLK C64 would look like

CLK has no C64 (`Machines/Commodore/` contains only the 1540, the Plus/4 and the VIC-20). But the parameters are fully determined, and the exercise is instructive:

```cpp
crt_(504, 1, 312, Outputs::Display::ColourSpace::YUV,
     567, 2,      // 283.5 colour cycles per line — NOT the PAL50 default of 709379/2500
     5, true,     // PAL vertical sync length; phase alternates
     Outputs::Display::InputDataType::Luminance8Phase8);
```

Note that the C64 must *not* use CLK's built-in `PAL50` type, whose 283.7516 cycles per line is the broadcast value. This is the same non-standard `283.5` derived independently in [§4.1](#c64-numbers), arrived at from CLK's own model — a useful cross-check.

### 7.7 Transfer to FPGA

Estimated cost of a faithful port of CLK's composite decode, at one sample per clock with symmetric-tap folding: about **78 multiplies and 126 adds per sample** for the full chain (two 31-tap separation filters, quadrature demodulation, two 31-tap demodulation filters, the colour matrix). Time-multiplexed at 4 samples per DSP that becomes roughly **20 DSP48E1 slices**; fully parallel it is 78. **We have 665 free.** Crucially, because there is no delay line, there is **no line memory at all** — the whole decoder is a 31-sample shift register.

What does *not* port: the runtime Kaiser-Bessel filter designer (run it offline, or on QNICE at mode-change time, and load 16 coefficients), the scan-geometry resampling model (we emit pixels in raster order at a known rate, so it collapses), and the flywheel sync (we have real timing). The phosphor/field-mixing stages need a framebuffer and are the genuinely expensive part.

<a name="ch8"></a>

## 8. Blargg and AppleWin — "precompute the answer"

If school 1 is "evaluate the physics at runtime", school 2 is "evaluate it once, at startup, and ship the result as a table". For an FPGA this is enormously attractive, because it converts a filter bank into a ROM.

### 8.1 Blargg's NTSC filters

Shay Green's `nes_ntsc` / `snes_ntsc` / `sms_ntsc` are the most widely deployed composite simulators in emulation. At initialisation they run, for every combination of (palette colour × colour-burst phase × sub-pixel alignment), the complete encode → filter → decode chain, and store the resulting **RGB contribution kernel**: how much red, green and blue this one input pixel adds to each of the next N output pixels. Because the chain is linear up to the final clamp, superposition holds and blitting is just summing overlapping kernels.

The entire per-output-pixel runtime cost is this:

```c
nes_ntsc_rgb_t raw_ =
    kernel0  [x       ] + kernel1  [(x+12)%7+14] + kernel2  [(x+10)%7+28] +
    kernelx0 [(x+7)%14] + kernelx1 [(x+ 5)%7+21] + kernelx2 [(x+ 3)%7+35];
```

Six table reads, five adds, one clamp. And a detail worth stealing outright: all three colour channels are packed into a single 32-bit word with guard bits between them (`(1L<<21)|(1<<11)|(1<<1)`), so **one 32-bit add performs three channel adds simultaneously**, and the clamp is five bitwise operations that saturate all three channels at once. That is an FPGA idiom that happens to have been written in C.

**Table sizes scale with palette size, not resolution.** `nes_ntsc` is 64 colours × 128 entries × 4 bytes = 32 KB. `snes_ntsc`, indexed by 15-bit RGB instead of a palette index, is 4 MB — and is therefore the cautionary tale: *this method only works if you index by a small colour index.*

**The C64 is the best case in the family.** With `f_dot / f_sc = 16/9`, the subcarrier phase repeats every **16 dots**, so a C64 kernel table is 16 colours × 16 phases = 256 entries (512 if you also carry the PAL line-parity state). At 8 taps × 3 channels × 10 bits that is about **2 block RAMs**. The entire horizontal composite behaviour of a C64, in two BRAMs, with zero multipliers.

**But: there is no PAL variant, and there cannot be a straightforward one.** Blargg never wrote one, and the reason is architectural — PAL's line averaging is a *vertical* operation and Blargg's kernels have no vertical dimension at all. Same conclusion as CLK, from a completely different direction.

### 8.2 AppleWin: the 12-bit window

AppleWin's NTSC decoder is even simpler at runtime, and is the cleanest existing blueprint for an FPGA artefact decoder:

```c
g_nSignalBitsNTSC = ((g_nSignalBitsNTSC << 1) | signal) & 0xFFF;  // 12-bit history
return *(uint32_t*) &pTable[ g_nSignalBitsNTSC ];
```

A 12-bit shift register and one table read. The table is 4 phases × 4096 patterns × 4 bytes = 64 KB, built offline by pushing every pattern through three biquad IIR filters (signal, luma, chroma), a quadrature demodulator, and the YIQ matrix. In FPGA terms: a 12-bit shift register and a 16 K × 24-bit ROM.

The cheap ancestor of this is the **4-bit window**: since the Apple II's 14.31818 MHz dot clock is exactly 4× the subcarrier, four consecutive dots are exactly one colour cycle, so a 4-bit window indexes 16 colours directly. Exact for static patterns, wrong at edges — which is why the 12-bit window exists.

Our local WIP Apple II core does the same idea in VHDL with a 6-dot window and four basis colours (`Apple-II_MEGA65/CORE/Apple-II_MiSTerM65/rtl/vga_controller.vhd:51-58`, values credited to Linards Ticmanis):

```vhdl
constant basis_r : basis_color := ( X"88", X"38", X"07", X"38" );
constant basis_g : basis_color := ( X"22", X"24", X"67", X"52" );
constant basis_b : basis_color := ( X"2C", X"A0", X"2C", X"07" );
signal shift_reg : unsigned(5 downto 0);  -- Last six pixels
```

<a name="ch9"></a>

## 9. The shader family — "model the glass"

This is the school everyone has seen screenshots of. It is worth knowing what is in it, mostly so we can pick the two or three cheap items and knowingly decline the rest.

| Shader | Passes | Models | FPGA verdict |
|---|---|---|---|
| **crt-royale** | 12 | Linearise, interlace, scanlines, halation (9-tap separable), mask resize, brightpass, bloom, curvature | Not portable. Useful as a catalogue of effects, not as a target |
| **crt-lottes** | 1 | Scanline Gaussian, horizontal beam Gaussian, four mask types, barrel warp, bloom, linear light | ~32 texture fetches per pixel; the mask and scanline parts port easily |
| **crt-guest-advanced** | 12 | The above plus afterglow (true temporal feedback) and deconvergence | Only the afterglow is conceptually new; needs a framebuffer |
| **crt-geom** | 1 | Curvature, **brightness-dependent beam width**, 20 mask patterns, CRT-vs-monitor gamma | The beam model is the most physically motivated: `wid = 0.3 + 0.1·color³` |

Two items from this family are worth taking seriously, and two are worth explicitly refusing.

**Take: gamma.** Blending in sRGB space is simply wrong. sRGB values encode perception, not light. Averaging 0 and 255 in sRGB gives 128, which emits about 21.6% of full light, whereas two half-lit scanlines physically emit 50%. Every scanline blend, every beam Gaussian and every mask multiply currently done on sRGB bytes darkens the picture and shifts hue. The exact transfer function is:

```
sRGB -> linear:  c <= 0.04045   ? c/12.92        : ((c + 0.055)/1.055)^2.4
linear -> sRGB:  c <  0.0031308 ? c*12.92        : 1.055·c^(1/2.4) - 0.055
```

In FPGA terms that is two ROMs and zero multipliers: 256 × 12-bit in, 4096 × 8-bit out. Twelve bits of linear intermediate is the minimum — 8-bit linear posterises the shadows badly.

**Take: shadow mask and scanline weighting.** A mask is a small ROM indexed by `(x mod 3, y mod 2)` or a 16×16 tile; MiSTer's `shadowmask.sv` does it with a 256-entry, 11-bit table, shift-add multipliers, and **zero DSP slices**. Scanline dimming in MiSTer's `scanlines.v` is pure shift-add: 25% is `{1'b0,r[7:1]} + {2'b00,r[7:2]}`.

**Refuse: curvature.** It requires a per-pixel inverse geometric mapping and therefore arbitrary two-dimensional access into a full frame. That is a framebuffer, not a line buffer, and it is incompatible with a streaming pipeline.

**Refuse: phosphor persistence — and know why.** Real P22 phosphor decays to under 10% in well under 100 µs for blue and green, and a few hundred microseconds for red. A PAL frame is 20 ms. Cross-frame persistence is therefore *physically wrong* by two orders of magnitude; what people perceive as afterglow is mostly eye and camera integration. `crt-guest-advanced` uses a per-frame retention of 0.81, roughly a 100 ms time constant — 100× longer than the real tube. It is a look, not a model. (It also needs a full previous-frame read: 2.76 MB per frame at 720p, a second stream on a memory bus that AGENTS.md already flags as contended.)

<a name="ch10"></a>

## 10. VICE — the reference the C64 world will compare us against

Whatever we build, C64 users will hold it next to VICE. So it is worth knowing exactly what VICE does, and the answer is: **school 4, implemented cheaply and well.**

### 10.1 The two generations

The **old "fast PAL emulation"** is the one mrdudz describes in issue #104: a 256-entry palette indexed by `(colour1 << 4) | colour2`, holding the blend of the two, with separate tables for odd and even lines, plus a one-line buffer of colour indices. That is school 3.

The **modern PAL renderer** (`video/render2x2pal.c` and friends) is school 4 and is remarkably lean. Per pixel:

```c
l    = ytablel[tmpsrc[1]] + ytableh[tmpsrc[2]] + ytablel[tmpsrc[3]];
unew = cbtable[tmpsrc[0]] + cbtable[tmpsrc[1]] + cbtable[tmpsrc[2]] + cbtable[tmpsrc[3]];
vnew = crtable[tmpsrc[0]] + crtable[tmpsrc[1]] + crtable[tmpsrc[2]] + crtable[tmpsrc[3]];
```

A **3-tap symmetric FIR on luma**, a **4-tap boxcar on chroma**, both fed by per-colour lookup tables that already contain the Y, U and V contributions. Then the delay line, which is the ten most important lines of C code in this whole topic:

```c
void get_yuv_from_video(const int32_t unew, const int32_t vnew,
                        int32_t *const line, const int off_flip,
                        int32_t *const u, int32_t *const v)
{
    *u = (unew + line[0]) * off_flip;
    *v = (vnew + line[1]) * off_flip;
    line[0] = unew;
    line[1] = vnew;
}
```

`line` points at the same column on the previous row. That single add *is* the 64 µs glass delay line. And then a deliberately cheap output matrix:

```c
/*  R = Y + V ;  G = Y - (0.1953*U + 0.5078*V) ;  B = Y + U  */
*red = (y + v) >> 16;
*blu = (y + u) >> 16;
*grn = (y - ((50 * u + 130 * v) >> 8)) >> 16;
```

Two of the three channels are a single add.

### 10.2 The numbers behind the defaults

| Resource | Default | What it does |
|---|---|---|
| `PALBlur` | 500 | Luma 3-tap FIR weights `32, 191, 32` out of 255 → −3 dB at 2.18 MHz |
| `PALOddLineOffset` | 500 | Odd-line chroma weight 0.625 instead of 1.0 — controls Hanover-bar strength |
| `PALOddLinePhase` | 1500 | Odd-line hue rotation |
| `PALScanLineShade` | 750 | Scanline darkening |
| `ColorGamma` | 1000 | PAL default gamma 2.8, NTSC 2.2 |

The chroma boxcar is not user-adjustable and sits at −3 dB at 0.90 MHz with its first null at 1.97 MHz — somewhat tighter than the real 1.3 MHz, i.e. VICE errs on the side of more blending.

### 10.3 The NTSC renderer is the PAL one minus the delay line

Verbatim from `video/render2x2ntsc.c:36-38`:

```c
/*
    right now this is basically the PAL renderer without delay line emulation
*/
```

The horizontal filters are identical; the previous-line terms are simply gone; the colour space is YIQ via the Sony CXA2025AS decoder matrix. This is a useful licence: **one implementation, one bit to disable the vertical average, and you have both standards.**

### 10.4 On palettes

VICE ships several C64 palettes (its default build is `TOBIAS_COLORS`, with `PEPTO_COLORS` and `COLODORE_COLORS` available), and it carries the only per-revision hard data anyone has: measured luma voltages for 6567R56A, 6567R8, 6569R1, R3, R4 and R5. There is no measured data for the 8565 at all. Practically, the only revision difference that matters to artists is **five luma levels on the 6569R1 versus nine on everything later** — which is why *Mayhem in Monsterland*'s bushes fuse on an old machine and look stripey on a new one.

For reference, our own core ships the **Colodore** palette (verified value-by-value against `fpga64_rgbcolor.vhd:38-53`), hardcoded, with no alternative. Upstream MiSTer merged an eight-palette selector in March 2026 (PR #201) that our fork predates.

<a name="ch11"></a>

## 11. Lumacode and RGBtoHDMI — the hardware that already does this

This is what paich64 points at in issue #28, and it is the most directly relevant prior art in the entire document, because it is a *shipping product* that solves exactly the problem being asked about.

### 11.1 Lumacode

Lumacode (c0pperdragon) is a wire protocol for getting **digital** pixel data out of a retro machine over one ordinary RCA cable. It uses four voltage levels plus a fifth for sync:

| symbol | voltage (75 Ω, DC-coupled) |
|---|---|
| sync tip | 0.00 V |
| `00` | 0.31 V |
| `01` | 0.53 V |
| `10` | 0.74 V |
| `11` | 0.96 V |

Four levels means two bits per sample ("quaternary"). Each C64 pixel is sent as **two consecutive samples**, giving four bits, giving all sixteen VIC-II colours. The level assignment is chosen so that the average of the two samples tracks the colour's real brightness, which means plugging the cable into an ordinary TV shows a legible greyscale picture — a deliberate diagnostic feature.

The C64 adapter, the **VIC-II-dizer**, is a passive interposer that sits under the VIC-II socket and listens to the bus, reconstructing exact pixel colours with no soldering. RGBtoHDMI's shipped C64 profiles sample at **15 764 000 Hz** (PAL) and **16 363 636 Hz** (NTSC) — exactly twice the C64 dot clock, 1008 and 1040 samples per line.

The point to take away: this whole elaborate chain exists to deliver, to the scaler, **the 4-bit VIC-II colour index** — which our core already has internally and throws away.

### 11.2 The colour blending in RGBtoHDMI

Release 59 ("Add PAL artifact (colour blending) on Commodore 64 & 128 lumacode") does the blending in the Raspberry Pi's bare-metal ARM assembly capture loop. The runtime is a one-scanline delay buffer and a 256-entry table:

```asm
        adrl   r14, bufferc64          ; reset once per line
loop_16bpplc:
        ldr    r9, [r14]               ; the previous line, 4 packed pixels
        adrl   r10, c64_artifact_palette_16
        ...
        and     r5, r9, #0xff          ; byte = (prev_line_colour<<4) | this_colour
        ldr     r5, [r10, r5, lsl #2]  ; 256-entry LUT
```

Each table entry packs **two** RGB444 colours — the even-line and odd-line results — and line parity picks the halfword in two instructions.

All the arithmetic happens once, at palette-build time, in C:

```c
double Y  = 0.299*R + 0.587*G + 0.114*B;          // current-line pixel
double U  = -0.14713*R - 0.28886*G + 0.436*B;
double V  =  0.615*R  - 0.51499*G - 0.10001*B;
//double Y2 = ...                                 // prev-line LUMA DELIBERATELY UNUSED
double U2 = -0.14713*R2 - 0.28886*G2 + 0.436*B2;  // previous-line pixel
double V2 =  0.615*R2  - 0.51499*G2 - 0.10001*B2;
...
U = (U + U2)/2;  V = (V + V2)/2;
R = (Y + 1.140*V);  G = (Y - 0.396*U - 0.581*V);  B = (Y + 2.029*U);
```

Read that carefully: **luma comes from the current line only; chroma is the 50/50 average of this line and the one above.** That is the PAL delay line, exactly as described in [§3.1](#ch3), implemented as a table.

There is one further refinement worth stealing. The previous line's chroma vector is first *rotated* by a user-settable angle (`PAL Odd Level`, 33° in the shipped C64 profile) before averaging, and the rotation is applied either always or only when the two colours differ. IanSB's own description of the three-state option:

> "PAL Odd line: This sets the behaviour of the PAL Odd lines which have a different phase to the even lines. Off = same as even. **Blended Colours: only different colours are blended. All Colours: all colours are blended which can give hanover bars on solid colours.** PAL Odd Level: This changes the phase offset of the odd lines compared to the even lines."

The "Blended Colours" mode is not physically honest — suppressing the rotation on identical colours is an aesthetic hack that hides Hanover bars on flat areas. It is also, by all reports, what makes it look right. Both options exist because users genuinely want both. That is a menu design lesson as much as a technical one.

The colour source is **Colodore** — the same palette our core already ships.

### 11.3 What this means for us

An FPGA port of RGBtoHDMI's blending is: **one line buffer of 4-bit indices (504 × 4 bits, about 11% of one RAMB18), one 256-entry table, one mux, zero multipliers, one pixel of latency.** Everything expensive is offline, and the natural home for the offline part is QNICE writing the table into a dual-port BRAM — exactly the pattern already used by every `C_DEV_C64_*` device in `mega65.vhd`.

The one thing it does *not* do is horizontal chroma bleed. It is the vertical half of the story only.

<a name="ch12"></a>

## 12. MiSTer — what already exists in FPGA, and what nobody has built

### 12.1 The framework blocks

MiSTer's `sys/` folder contains a surprisingly complete video toolkit, and — this is the useful part — **most of it is already sitting in our repositories**, either vendored into M2M or dragged along inside a core's MiSTer subtree.

| Block | Technique | Cost | Where it is in our trees |
|---|---|---|---|
| `scandoubler.v` | Line doubler that auto-measures the input pixel size | 2 line buffers, 0 DSP | Used by M2M's analog path |
| `hq2x.sv` | 3×3 edge-directed 2× upscale, 256×6-bit decision ROM | line buffers + 1.5 kbit ROM, 0 DSP | In M2M, tied to `'0'` |
| `scanlines.v` | Shift-add row dimming: 25% is `{1'b0,r[7:1]} + {2'b00,r[7:2]}` | ~a dozen adders, 0 BRAM, 0 DSP | Not in `M2M/vhdl/`, but present and unused in `C64MEGA65/CORE/C64_MiSTerMEGA65/sys/` |
| `gamma_corr.sv` | 3 × 256-entry LUT in one BRAM, time-multiplexed over 4 clocks | 1 RAMB18, 0 DSP | In M2M, `gamma_bus => open` |
| `shadowmask.sv` | 16×16 tile ROM, 3 select bits + two 4-bit shift-add multipliers, 5-stage pipeline | 2.8 kbit, ~120 LUT, **0 DSP** | In AExp's MiSTer subtree only |
| `vga_out.sv` | RGB→YPbPr, a **full 3×3 colour matrix with zero multipliers** — e.g. `y_1g <= {green,9'd0} + {green,2'd0};` | ~24 adders, 0 DSP, 0 BRAM | In AExp's MiSTer subtree |
| **`yc_out.sv`** | **Real PAL/NTSC composite and S-Video encoding** | 40-bit NCO, 256-entry sine ROM, **2 DSP48** | **In AExp's MiSTer subtree, unused** |

Two of these deserve a precise statement of where they are, because it decides how much work adopting them is. `scanlines.v`, `gamma_corr.sv`, `vga_out.sv`, `hq2x.sv`, `scandoubler.v` and `video_mixer.sv` all exist inside C64MEGA65's own `CORE/C64_MiSTerMEGA65/sys/` snapshot as well, unused. Only **`shadowmask.sv` and `yc_out.sv` are genuinely absent from the C64 core** — they arrived in MiSTer's `sys/` after our fork point, and are present in AExp's newer snapshot.

That last row is worth dwelling on. `yc_out.sv` (Mike Simone, 2022) is a complete composite modulator: numerically controlled oscillator, signed sine table, shift-add RGB→Y and RGB→UV conversion, quadrature modulation with exactly two real multipliers, a correct PAL line-alternate V flip, and a proper nine-cycle colour burst with the ±135° PAL swing. It even has a CVBS mode that sums chroma into luma. It sits in `AExp/CORE/Minimig_MiSTerMEGA65/sys/yc_out.sv`, is not in any Vivado project file list, and is unused only because M2M replaces MiSTer's `sys_top.v`.

The relevance is direct: **half of a "true composite" implementation is already written, tested in the field by the MiSTer community, and present in our own tree.** The missing half is a demodulator.

### 12.2 Per-core artefact implementations that already exist

| Core | File | Technique | Cost |
|---|---|---|---|
| **Atari 800** | `articolor.sv` | Detects a luminance ridge over a 3-pixel window, alpha-blends toward one of four hardcoded artefact colours; two selectable sets | 3 multiplies, 0 BRAM |
| **CoCo 3** | `Mister_Video.v` | 6-bit pixel-history → colour ROM, two artefact engines, menu `"Artifact Type,MESS,Simple,NONE"` | LUT only |
| **Apple II** | `vga_controller.vhd` | 6-pixel shift register → 16-entry runtime-loadable palette; menu offers four named palettes and `"Lo-Res Text,Clean,Composite"` | 0 DSP |
| **Genesis** | `cofi.sv` (Kitrinx) | "Composite-like horizontal blending": 2-tap box filter, `sum = curr + prev; out = sum[8:1]`, blanking-aware. Menu: `"Composite Blend,Off,On,Adaptive"` | **3 adders and 3 registers** |
| **NES** | `Palette/` | Composite look delivered as *a palette*, including `Composite.pal` | 0 |

`cofi.sv` deserves a mention as the cheapest thing in this entire document that visibly improves dithered artwork: three adders.

### 12.3 The MiSTer C64 core today

Upstream merged PR #201 "Implement palette selection" on 28 March 2026, turning `fpga64_rgbcolor.vhd` into an eight-way palette selector:

```
"P1O[84:82],Palette,Colodore,Ultimate,Pepto-PAL,Vice,Vice6569R1,Vice6569R5,Vice8565R2,Lemon64;",
```

Our fork predates that. Upstream also now pulls `yc_out.sv` and `shadowmask.sv` from the framework, so the MiSTer C64 gets S-Video output and shadow masks for free. What upstream still has is **no PAL blending, no chroma model, no colour filter of any kind.**

### 12.4 sorgelig's position, read carefully

Issue #104 sat untouched from August 2021 to August 2025. sorgelig's comment is:

> "You are free to propose your changes to implement the features you want. It's ok to implement such filter but sometimes such filter degrades the video and it doesn't look good on modern TV."

That is permission with a caveat, not opposition. The supporting evidence is his behaviour on issue #121 ("Add Shadow Masks filter option"), where he wrote *"All cores will be updated with shadow mask after test of released cores"* — and then delivered; `shadowmask.sv` is now in every core's `sys/`.

The honest conclusion is not "MiSTer rejected this". It is: **the framework maintainer merges well-scoped video work, and nobody ever wrote the PAL-blend code.** A code search across `org:MiSTer-devel` for chroma delay-line blending returns zero RTL hits.

### 12.5 Checking mrdudz's two claims

He made two technical claims in issue #104 and both deserve a verdict, because they frame the whole cost discussion.

**The cheap path — "two palettes, one line buffer, a 256-entry blend table".** Correct, matches VICE, and matches what RGBtoHDMI actually ships. Costed against our real build: line buffer 504 × 4 bits = 2016 bits (11% of one RAMB18), blend table 256 × 24 bits = 6144 bits (a third of a RAMB18), zero multipliers. **About one RAMB18 and no DSPs.** "Relatively easy" is, if anything, an understatement.

**The expensive path — "at least two 3×3 matrix multiplies per pixel, at significant precision, plus horizontal blur due to different bandwidth of chroma and luma".**

* The *matrix* half is wrong in FPGA terms. Both matrices are constant, so they compile to shift-and-add. MiSTer ships two working proofs: `vga_out.sv` does a full RGB→YPbPr matrix with **zero** multipliers, and `yc_out.sv` does RGB→Y the same way. A round trip at 12-bit internal precision is roughly 50 adders and no DSP48s.
* The *bandwidth* half is the real work, and he is right to flag it — but not about the cost. Normalised chroma cutoff is 1.3 MHz / 7.882 MHz = 0.165·fs; a 40 dB stop-band with a 0.5 MHz transition needs on the order of 29 taps per chroma component, so about 60 multiply-accumulates per pixel, halved by symmetry. At 7.88 M pixels/s on a 100 MHz fabric clock there are 12.7 clocks per pixel, so that fits on **8 DSP48s time-multiplexed**, or about 60 fully parallel. Against 665 free, neither number is a constraint.
* His closing remark, *"no other FPGA project implemented something like this yet AFAIK"*, is now partly false: `yc_out.sv` (2022) does full PAL/NTSC modulation with a correct line-alternate V flip. What remains genuinely unbuilt anywhere in FPGA land is the **encode-then-decode round trip**, and — more importantly for issue #104 — **the vertical PAL delay-line chroma average**. Nobody has done that one, and it costs about one block RAM.

---

# Part III — Where M2M stands today

<a name="ch13"></a>

## 13. The M2M video pipeline, annotated

Before proposing anything, it is worth having the current pipeline written down in one place, with line numbers, because the structure turns out to be unusually favourable.

### 13.1 The contract between core and framework

A core hands the framework a *single* video clock plus clock enables and finished 8-bit RGB (`M2M/vhdl/framework.vhd:124-130`):

```
video_clk_i             : in    std_logic;
video_ce_i              : in    std_logic;
video_ce_ovl_i          : in    std_logic;
video_red_i             : in    std_logic_vector(7 downto 0);
video_green_i           : in    std_logic_vector(7 downto 0);
video_blue_i            : in    std_logic_vector(7 downto 0);
```

There is deliberately no second clock. As MJoergen put it in `doc/temp/video_pipeline.md`, M2M uses one clock plus a clock enable rather than two clocks, so that no clock-domain crossing exists inside the core-to-framework path and static timing analysis stays trivial. For the C64 core, `video_clk` is the 31.5 MHz main clock and `video_ce` fires once every four cycles, giving the 7.88 MHz dot clock (`CORE/vhdl/main.vhd:1669-1680`):

```vhdl
video_ce_o      <= '1' when video_ce = 0 else '0';
-- Clock divider: The core's pixel clock is 1/4 of the main clock
video_ce_proc : process (clk_main_i)
begin
  if rising_edge(clk_main_i) then
    video_ce <= video_ce + 1;
  end if;
end process video_ce_proc;
```

**This is important and easy to miss:** the framework already receives the core's pixels on a clock that runs at four times the pixel rate. Three out of every four clock cycles are idle as far as pixel data is concerned. Any signal-domain processing we add has those cycles available for free, and — as shown in [§4.4](#c64-numbers) — 31.5 MHz is exactly the rate at which a 4.43 MHz subcarrier can be represented comfortably.

### 13.2 The split

`framework.vhd:865` instantiates a single wrapper, `i_av_pipeline`. Inside `M2M/vhdl/av_pipeline/av_pipeline.vhd` the video fans out:

```
                       core RGB + video_ce  (video_clk, 31.5 MHz)
                                  |
              +-------------------+---------------------+
              |                                         |
   i_analog_pipeline (line 397)              i_crop (line 532)   ← HDMI zoom
              |                                         |
   video_mixer (scandoubler)                 i_digital_pipeline (line 555)
              |                                         |
   i_video_overlay  ← OSM (VGA VRAM)         i_ascal    ← upscale via HyperRAM/SDRAM
              |                                         |
   i_csync / i_vga_sync_reshaper             i_video_overlay ← OSM (HDMI VRAM)
              |                                         |
        VGA connector                        i_vga_to_hdmi + serialisers → HDMI
```

Relevant clock domains: `video_clk` (31.5 MHz, the core), `hr_clk` (HyperRAM, 100 MHz), `hdmi_clk` (74.25 MHz for 720p50), `qnice_clk` (50 MHz), plus the audio clock.

Two structural facts fall out of this diagram, and together they make the whole project much easier than it might have been:

* **One insertion point serves both outputs.** Everything upstream of `i_analog_pipeline` and `i_crop` is common. A processing block placed at the top of `av_pipeline.vhd` is instantiated once, in one clock domain, at the core's own rate, and both the VGA connector and the HDMI connector see the result.
* **The on-screen menu is immune.** There are two separate OSM VRAMs (`i_osm_vram_vga` at line 648, `i_osm_vram_hdmi` at line 673) and the corresponding `video_overlay` instances sit *downstream* — after the scandoubler on the analog side (`analog_pipeline.vhd:182`) and after ascal on the digital side (`digital_pipeline.vhd:497`). Whatever we do to the picture, the menu font stays pixel-perfect with no extra work. This is a genuinely lucky property; in MiSTer's pipeline the OSD is composited in `video_mixer` and would have needed care.

<a name="what-we-have"></a>

## 14. What we already have — and what is missing

### 14.1 What already ships

**A 4-tap, 64-phase polyphase scaler with runtime-loadable coefficients.** `ascal.vhd` is instantiated with `ADAPTIVE => true` (`digital_pipeline.vhd:348`, commented "Needed for advanced scanlines emulation in polyphase mode") and its coefficient RAM is written from QNICE (`digital_pipeline.vhd:446-449`). The format is documented in `M2M/rom/filters.asm:15-17`:

```
; currently, we only support filters with 4 signed 10-bit integers per line,
; 64 lines, i.e. 256 data points
ASCAL_FILTER_LEN    .EQU 0x0100
```

So: 4 taps, 64 sub-pixel phases, separate horizontal and vertical coefficient sets, uploaded at boot and swappable at runtime by the Shell.

**A user-facing filter menu.** The V6 C64 core offers, inside a nested HDMI submenu (`CORE/vhdl/config.vhd:487-499`): *No Filter*, *Sharp Bilinear*, *Bicubic*, *Smooth*, *Lanczos*, *Scanlines*, *CRT (S-Video)*, *CRT (Composite)*. The dispatch table lives at `CORE/m2m-rom/m2m-rom.asm:1337-1354`.

**Scanlines, brightness-compensated.** The `Scan_Br_1xx_80` coefficient sets in `M2M/video_filters/` implement scanlines as a vertical polyphase kernel, with a brightness boost to compensate for the darkening.

**Zoom/crop, Retro 15 kHz with HS/VS or CSYNC, and HDMI flicker-free.** All present and shipping.

### 14.2 What is missing

**No gamma correction anywhere.** MiSTer's `gamma_corr.sv` *is* in the tree (`M2M/vhdl/controllers/MiSTer/gamma_corr.sv`), and `analog_pipeline.vhd` even instantiates the MiSTer `video_mixer` component that carries a `gamma_bus` port — wired to nothing:

```vhdl
scandoubler => video_scandoubler_i,
hq2x        => '0',
gamma_bus   => open,
```

(`analog_pipeline.vhd:147-149`.) The digital path does not have a gamma stage at all, because ascal receives the core's raw RGB directly. `M2M/video_filters/README.md` says as much, in a note written for C64MEGA65 Release 1 and never superseded: *"Release 1 of C64MEGA65 only supports horizontal and vertical filters for performing the CRT emulation. There is no gamma correction and no shadow mask."*

**No shadow mask / aperture grille.** MiSTer has a whole mask-file ecosystem; we import none of it. Curiously, the *data* is already here: `M2M/video_filters/` carries `CRT_Simulation.txt` (which is not a polyphase filter at all — it is a 256-entry gamma curve) and two MiSTer shadow-mask files, `Commodore_1084_BGR_1987.txt` and `VGA_Squished_BGR_1987.txt`. The README says plainly that they are *"kept as reference material for a future release that adds gamma correction and shadow-mask support"*. `convert.py` skips them, and nothing includes them.

**`hq2x` is present but disabled** (tied to `'0'` above). Probably correct — hq2x is a pixel-art smoother, not a CRT effect — but worth knowing it is there.

**Nothing at all that understands chroma.** This is the real gap and the subject of this document.

### 14.3 An honest word about the existing "CRT (Composite)" preset

The V6 menu entries *CRT (S-Video)* and *CRT (Composite)* are polyphase coefficient sets, and the comment in `m2m-rom.asm:1348-1352` is refreshingly candid about what they do:

```
; The Composite vs S-Video character lives entirely in the H file
; (Composite has heavy horizontal blur, S-Video has mild softening), so
; swapping only ...
```

They are blur profiles. They look good and they were a sensible thing to ship. But a blur applied to R, G and B equally cannot do what a composite decoder does, for a reason that is worth stating precisely:

> By the time the picture reaches ascal, the information that a given pixel carried *chroma* rather than *luma* has been destroyed — it happened in `fpga64_rgbcolor.vhd`, thirty modules upstream. A low-pass filter on RGB blurs brightness and colour together, in equal measure. A composite decoder blurs *only* colour and leaves brightness sharp. The two are not approximations of each other; they are different operations.

That is also the definitive answer to the natural question, "can we not just abuse ascal's polyphase filter for this?" No, for three independent reasons: it operates on RGB, it has 4 taps where a 1.3 MHz chroma low-pass at the C64's 7.88 MHz dot rate needs on the order of 30, and its coefficients are a *scaling* kernel whose phase is dictated by the resampling ratio, not by us. It is the right tool for its job and the wrong tool for this one.

<a name="budget"></a>

## 15. The budget — measured, not guessed

This section exists because "will it fit?" is the question that kills projects like this before they start, and in our case the answer is a pleasant surprise.

All figures below are read from the current build of the C64 for MEGA65 (branch `mh_dev_drives`, reports dated 31 July / 1 August 2026), files `CORE/CORE-R{3,6}.runs/impl_1/mega65_r{3,6}_utilization_placed.rpt` and `..._timing_summary_routed.rpt`.

**The device.** All four MEGA65 board revisions (R3, R4, R5, R6) target the same part: `xc7a200tfbg484-2`, verified from the four `.xpr` files. There is no "small board" to design around. That is a significant simplification compared with what one might assume.

| Resource | Used (R3) | Used (R6) | Available | Free |
|---|---|---|---|---|
| Slice LUTs | 33 318 (24.9%) | 33 299 (24.9%) | 133 800 | ~100 000 |
| Slice registers | 25 592 (9.5%) | 25 437 (9.5%) | 269 200 | ~243 000 |
| Block RAM tiles | 175 (48.0%) | 175 (48.0%) | 365 | **190** |
| DSP48E1 | 75 (10.1%) | 75 (10.1%) | 740 | **665** |

One caveat on the table: the R3 and R6 reports are fresh (31 July / 1 August 2026). The **R4 and R5 reports on disk are from June 2024** and predate the multi-drive branch, full DMA and the V6 filter work; they show 204 BRAM tiles and ~24.7k LUT and should not be quoted as a current budget. Since all four boards are the same die and carry nearly the same design, treat R3/R6 as the truth and expect R4/R5 to land in the same place once rebuilt.

**Timing.** Worst negative slack is `+0.282 ns` (R3) and `+0.378 ns` (R6) — but the critical path is in the HyperRAM `hr_rwds` capture domain, not in logic we would touch (on R3 it is the inter-clock `hr_rwds → hr_clk` path, on R6 the intra-clock `hr_rwds` group). Per-clock intra-domain slack on R6:

| Clock | Slack | Comment |
|---|---|---|
| `main_clk` (31.53 MHz, 31.72 ns period) | **+9.420 ns** | where all proposed work would live |
| `hdmi_clk` (74.25 MHz) | +1.889 ns | tight; do not add logic here |
| `hr_clk` (100 MHz) | +0.501 ns | tight |
| `qnice_clk` (50 MHz) | +0.493 ns | tight |

### 15.1 What that means

A full composite modulator and demodulator — the most expensive thing this document proposes — costs roughly **30 DSP48 slices and 2 block RAMs**, and would run in the `main_clk` domain where we have nine nanoseconds of slack on a thirty-one nanosecond clock. As a sanity check, MiSTer's complete Y/C encoder `yc_out.sv` uses **two** multipliers and one 256-entry sine table.

So the conclusion is blunt and should be stated at the top of any discussion of issue #28:

> **The obstacle is not the FPGA.** We are using a tenth of the DSP slices and half the block RAM, on the largest part in the family, with three quarters of the LUTs free and a third of the main clock period unused. Every tier in Part IV fits several times over. What this project costs is *design attention* — deciding what to model, getting the coefficients right, and building a way to compare against reference images — not silicon.

The one real constraint to respect is the **`hdmi_clk` domain**, which is genuinely tight and which is also the wrong place for this work anyway: after ascal the picture has been resampled to 720p, and a composite decoder needs the *original* sample grid. Everything proposed here stays upstream, at 31.5 MHz.

---

# Part IV — A concrete plan

<a name="ch16"></a>

## 16. The three domains where you can intervene

Before any tier list, one decision dominates everything: **at which point in the chain do you re-introduce the concept of chroma?** There are exactly three answers, and they differ by orders of magnitude in cost.

```
   VIC-II                                                             display
     |                                                                   ^
     |  (A) 4-bit colour index                                           |
     v                                                                   |
  [ palette ] --(B) Y,U,V--> [ modulate ] --(C) composite--> [ demodulate ]
     |                                                                   ^
     +=================  what our core does today  =======================+
                 (straight from the index to finished RGB,
                  skipping every box in between)
```

**(A) The index domain.** Intervene while the picture is still 16 discrete colours. Everything becomes a lookup table, because the space of possible inputs is tiny: a blend of two colours has only 16 × 16 = 256 possibilities. Cost: *no arithmetic at all*. Restriction: only works for machines with a small palette — brilliant for the C64, useless for the Amiga's 4096 colours.

**(B) The colour-difference (S-Video) domain.** Convert to Y, U, V; apply the two filters that a real television applies to chroma — a horizontal low-pass and a vertical two-line average; convert back. Cost: a handful of adders and multipliers. This is what VICE does, and it is physically correct for everything *except* effects that arise from luma and chroma sharing one wire. Works for any RGB source.

**(C) The composite domain.** Modulate onto a real subcarrier, then demodulate with realistic filters. Cost: tens of multipliers and a sample-rate pipeline. This is the only domain in which cross-colour, cross-luminance and dot crawl can appear at all, because those artefacts *are* luma and chroma being confused for one another. It is also the only domain in which a machine like the Apple II has colours in the first place.

The tier list below is simply: (A) first, then (B), then (C) — plus a fourth option that gets (C)'s result by precomputing it into a table.

One organising remark: an FPGA core sits at the *left* end of this diagram and jumps straight to the right end. The whole project is about walking back one, two or three steps.

<a name="ch17"></a>

## 17. Tier 0 — get the colours and the light right

**What it delivers:** nothing visible on its own. Everything else is wrong without it.

### 17.1 Palette choice

The C64 palette is a *reconstruction*, and reasonable people have produced different ones. Our core hardcodes Colodore; upstream MiSTer merged an eight-way selector in March 2026 (`Colodore, Ultimate, Pepto-PAL, Vice, Vice6569R1, Vice6569R5, Vice8565R2, Lemon64`). Adding a `palette : in unsigned(2 downto 0)` port to `fpga64_rgbcolor.vhd` costs **zero block RAM and zero DSP** — sixteen nested constants are pure LUT logic.

The one that matters technically rather than aesthetically is the **6569R1 five-luma set**. Old chips had five luminance levels, later ones nine. Artwork tuned for one looks wrong on the other — *Mayhem in Monsterland*'s bushes fuse cleanly on an R1 and go stripey on a later chip, because green and medium grey fall into the same luma cluster on one and not the other. If we implement line blending, offering the R1 palette is what makes the classic games look the way their authors saw them.

### 17.2 Gamma, and why it comes first

Every blend proposed in this document — line averaging, chroma filtering, scanline dimming, mask multiplication — is currently performed, or would be performed, on sRGB-coded bytes. That is arithmetically wrong. sRGB values encode *perception*, not light. The average of 0 and 255 in sRGB is 128, which emits about 21.6% of full light; two half-lit scanlines physically emit 50%.

This is not an abstract complaint: it is the reason M2M needs brightness-compensated scanline filters at all (`Scan_Br_105/110/115/120_80`). Those files exist to hand-compensate for an error that correct arithmetic would not make in the first place.

The fix is two lookup tables and no multipliers:

| Direction | Table | Size | Cost |
|---|---|---|---|
| sRGB → linear | 256 → 12 bit, ×3 channels | 9 216 bits | distributed LUTRAM |
| linear → sRGB | 4096 → 8 bit, ×3 channels | 98 304 bits | ~3 RAMB36 |

Twelve bits of linear intermediate is the minimum; eight bits posterises the shadows, because the sRGB curve's linear segment near black carries roughly four stops that 8-bit linear throws away.

**Where the LUTs may and may not go — this is a real constraint, not a detail.** `ascal`'s internal pixel type is 8 bits per channel:

```vhdl
TYPE type_pix IS RECORD
  r,g,b : unsigned(7 DOWNTO 0); -- 0.8
END RECORD;
```

so you cannot decode to linear before the scaler and encode after it: that would push 8-bit *linear* light through the scaler and the frame buffer and crush exactly the shadows the exercise was meant to protect. **Decode and encode must sit on the same side of ascal.** Practically that means each stage that blends does its own local linearise-blend-encode, and the natural home for the runtime pair is around the post-ascal tube stage described in [§22](#ch22).

Two consequences worth stating plainly:

* **The table-driven tiers need no gamma hardware at all.** Tier 1's blend table and Tier 3-alt's kernels are computed offline; doing that computation in linear light is free and makes those stages correct by construction.
* **ascal's own polyphase resampling keeps running in sRGB space**, because it is inside the scaler and we are not going to rewrite it. So the brightness-compensated `Scan_Br_*` scanline variants remain necessary, and gamma correctness does *not* retire them. This is the honest version of the story.

There is a shortcut available for the analog path: MiSTer's `gamma_corr.sv` is **already vendored into M2M** (`M2M/vhdl/controllers/MiSTer/gamma_corr.sv`) and already wired into the analog path's `video_mixer` component — with `gamma_bus => open`. It stores 3 × 256 entries in one BRAM and time-multiplexes the three channels over four clocks per pixel, which works at the 7.88 MHz core rate but *not* at 74.25 MHz one-pixel-per-clock, where three parallel BRAMs are genuinely needed. Enabling it on the VGA path is plumbing plus a QNICE loader, not new logic.

**Menu:** `Palette: Colodore / Pepto / VICE / 6569R1` and a gamma setting (or simply "correct gamma, always on", which is defensible).

<a name="tier1"></a>
<a name="ch18"></a>

## 18. Tier 1 — the PAL delay line, in the index domain

**What it delivers: exactly what MiSTer issue #104 asks for.** Alternating-line colour patterns fuse into hues the VIC-II cannot produce. *Mayhem in Monsterland*'s bushes become one desaturated green instead of green-and-grey stripes.

### 18.1 The data path

```
vicColorIndex(3:0) ─┬──────────────────────────────► idx_cur
                    └─► line_buf[504] ─────────────► idx_prev   (same column, previous line)

line_parity ──┐
              ├─► LUT_even[ idx_prev<<4 | idx_cur ] ──► RGB
              └─► LUT_odd [ idx_prev<<4 | idx_cur ] ──► RGB
```

That is the whole design. Two tables, one line buffer, one mux.

### 18.2 The cost, in real numbers

| Item | Size | In device terms |
|---|---|---|
| Line buffer, 504 dots × 4 bits | 2 016 bits | 11% of one RAMB18, or ~32 LUT6 as distributed RAM |
| Blend table, even lines, 256 × 24 bits | 6 144 bits | a third of one RAMB18 |
| Blend table, odd lines | 6 144 bits | a third of one RAMB18 |
| Multipliers | — | **zero** |
| Adders | — | **zero** |
| Latency | **one pixel** | |

**One block RAM tile. No DSP slices. One BRAM read per pixel.** Against 190 free tiles and 665 free DSPs, this is not a cost, it is a rounding error.

Note the latency figure: it is **one pixel, not one line**. The line buffer is addressed by column and read *before* it is written, so the read returns the previous line's index at the same column and the write immediately replaces it. Nothing needs to be delayed by a line, and the sync signals need no adjustment at all — which matters, because a one-line pipeline delay would force `hs`, `vs` and the blanks to be delayed with it.

### 18.3 Why the index domain, specifically

Doing the same blend in the RGB domain would require: a 504 × 24-bit line buffer (six times the memory), plus real arithmetic — RGB→YUV, average U and V, YUV→RGB, roughly ten multiplies per pixel — because there is no table with 2^24 × 2^24 entries. The index domain replaces all of that with one lookup, because 16 × 16 is 256.

This is also the reason **Tier 1 is a C64-only feature**. AExp has 4096 colours (a 16.7-million-entry table) and gbc4mega65 has RGB555. For those cores, if you want vertical chroma averaging you must do it in the colour-difference domain, i.e. Tier 2's machinery.

### 18.4 The enabling one-line change

`vicColorIndex` is declared at `fpga64_sid_iec.vhd:279` and consumed internally at `:653`. It is not in the entity's port list. Adding

```vhdl
colorIndex  : out unsigned(3 downto 0);
```

and one assignment is a two-line change to the MiSTer core — the same size of change that upstream PR #201 made to route a palette selector in. Note a pleasant detail from `video_vicII_656x.vhd:1384-1396`: **border colour and blanking are applied in index space**, before the palette, so the border participates in the blend automatically and needs no special case.

### 18.5 Getting the details right

* **Odd/even palettes.** VICE ships *distinct* odd-line and even-line colour tables — Red is 95.50°/0.217 nominally, 89.00°/0.202 on even lines and 102.00°/0.232 on odd. That ±6.5° split is the physical PAL phase alternation baked into the palette, and it is what produces the "slight bias towards the colour on the top line" that C64 artists actually observe. Two tables, not one.
* **Three states, not a boolean.** Copy RGBtoHDMI's option naming verbatim: `Off / Blended Colours / All Colours`. "All Colours" applies the odd-line rotation everywhere and is physically honest, at the price of Hanover bars on flat areas. "Blended Colours" applies it only when the two colours differ, which is a cheat and is also what makes it look right. Users want both.
* **Off by default.** sorgelig's caveat is worth respecting: *"sometimes such filter degrades the video and it doesn't look good on modern TV."*
* **Gate it off in NTSC.** NTSC has no phase alternation and therefore no delay line; VICE's NTSC renderer is, in its own words, *"basically the PAL renderer without delay line emulation"*. The core already knows which mode it is in.
* **The tables come from QNICE.** All the trigonometry happens once, at menu-change time. Write the 512 words into a dual-port BRAM using exactly the pattern that `M2M$LOAD_POLYPHASE` already uses for the ascal coefficients (`M2M/rom/tools.asm`), with a new device ID.

<a name="ch19"></a>

## 19. Tier 2 — horizontal chroma bandwidth

**What it delivers:** the *other* half of the C64's PAL look. Fine chroma detail dissolves while luma stays sharp — single-pixel chequerboards fuse into a third colour, sprites acquire the soft colour edges people remember, and dithered artwork stops looking like dithered artwork.

### 19.1 The physics, restated as a filter spec

The VIC-II applies **no** band-limiting of its own — it has separate luma and chroma pins and switches the subcarrier phase instantaneously at pixel boundaries. All horizontal smear happens in the television. PAL's U and V are each limited to about 1.3 MHz against a 7.882 MHz dot clock, i.e. a normalised cutoff of **0.165 · fs**.

What that does to specific patterns:

| Pattern | Fundamental | Fate |
|---|---|---|
| 1 pixel on / 1 off | 3.94 MHz | completely suppressed → perfect fusion (this is the chequerboard trick) |
| 2 on / 2 off | 1.97 MHz | suppressed |
| 4 on / 4 off | 0.985 MHz | survives, partially → visible banding |

which is exactly why the technique needs single-pixel chequerboards and degrades as the pattern coarsens.

### 19.2 Two implementations, pick either

```
RGB8 ─► [RGB→YUV, shift-add] ─► Y ────────────(delay N/2)───────┐
                                U ─► FIR_N ──┐                  ├─► [YUV→RGB] ─► RGB8
                                V ─► FIR_N ──┘──────────────────┘
```

**(a) The honest filter.** A 40 dB stop-band with a 0.5 MHz transition needs roughly **29 taps**; symmetry folds that to 15 unique coefficients per channel, so 30 multiply-accumulates per pixel. With four main-clock cycles available per pixel, that is **8 DSP48 slices time-multiplexed**, or 30 fully parallel. Memory: *zero line buffers* — a 29-deep shift register per channel, which maps to SRL32 primitives.

**(b) The VICE filter.** A **4-tap boxcar** maintained as a running sum: two adders, no multipliers. Measured response at our dot clock: −3 dB at 0.896 MHz, first null at 1.970 MHz, and exactly zero at 3.94 MHz. Tighter than the real 1.3 MHz — VICE errs towards more blending — but it nails the chequerboard behaviour and costs nothing.

The colour-space conversions themselves cost **no multipliers at all**: the matrices are constant, so they compile to shifts and adds. MiSTer proves this twice — `vga_out.sv` does a full RGB→YPbPr matrix with zero DSPs, and `yc_out.sv` does RGB→Y the same way:

```verilog
yr <= {red, 8'd0} + {red, 5'd0} + {red, 4'd0} + {red, 1'd0};
yg <= {green, 9'd0} + {green, 6'd0} + {green, 4'd0} + {green, 3'd0} + green;
yb <= {blue, 6'd0} + {blue, 5'd0} + {blue, 4'd0} + {blue, 2'd0} + blue;
```

**Menu:** `Chroma Bandwidth: Off / Soft / TV`.

### 19.3 Combining Tier 1 and Tier 2

Once you are in the colour-difference domain, the vertical average from Tier 1 is one more two-tap filter on U and V — and it now works for *any* core, not just the C64, at the cost of a real line buffer (504 × 2 × 12 bits ≈ 12 kbit, well under one RAMB18). Tiers 1 and 2 together are, in effect, a reimplementation of VICE's PAL renderer in hardware:

| VICE | Our equivalent |
|---|---|
| 16-entry Y/U/V tables per parity | 32-entry ROM |
| 3-tap luma FIR (`32, 191, 32`) | 2 adders, or skip it |
| 4-tap chroma boxcar | 2 adders |
| 1H delay line (`*u = (unew + line[0])`) | one line buffer, one adder |
| Cheap YUV→RGB (`R = Y+V`, `B = Y+U`, G costs 2 multiplies) | shift-add |

Total: on the order of **6 DSP48 slices and 3 block RAMs**, running at 7.88 M pixels per second in a domain with 9.4 ns of timing slack. This is the single highest-value target in the whole document.

<a name="ch20"></a>

## 20. Tier 3 — true composite, modulated and demodulated

**What it delivers:** everything the lower tiers cannot — cross-colour (fine luma detail becoming colour), cross-luminance and dot crawl (chroma leaking into brightness), and colour-on-black-and-white-content artefacts. It is also the only tier that is *required* rather than decorative for machines whose colours exist only as artefacts.

### 20.1 The gift, again

`main_clk / f_sc = 64/9` exactly. At the existing 31.527778 MHz main clock the subcarrier advances 9/64 of a cycle (50.625°) per sample and repeats every 64 samples. So:

> **A 64-entry sine/cosine ROM indexed by a mod-64 counter is an exact, drift-free subcarrier.** No numerically controlled oscillator, no new MMCM, no clock-domain crossing, no accumulated phase error, ever.

Compare with the generic MiSTer module, which must carry a 40-bit phase accumulator precisely because it cannot assume anything about the core's clock.

Better still: since we encode and decode in the same closed loop, the MEGA65 PLL's 5.6 ppm frequency error cancels identically on both sides. Absolute subcarrier accuracy is irrelevant.

The one caveat: 64/9 = **7.111 samples per subcarrier cycle**, just under CLK's design floor of 8. Nyquist is not remotely a problem (15.76 MHz against a top sideband around 5.8 MHz), but the separation filters are tighter to design. If that proves awkward, a ×2 leg at 63.06 MHz gives 14.22 samples per cycle and a 128-entry table — still one clock, still exact, still increment 9. (Note that the "classic" 4×f_sc = 17.73 MHz sampling rate would be a *downgrade* here: it is below the clock we already have.)

### 20.2 The chain and its cost

```
RGB → YUV  →  encode:  composite = Y·(1−2A) + (U·cos φ + V·sin φ)·A + A
           →  separate: 31-tap luma notch at f_sc  +  9-tap chroma bandpass
           →  demodulate: × cos φ, × sin φ
           →  31-tap low-pass on U and V
           →  PAL 1H average
           →  YUV → RGB
```

| Stage | Multipliers (symmetric folding) |
|---|---|
| Luma notch, 31 taps | 16 |
| Chroma bandpass, 9 taps | 5 |
| Quadrature demodulation | 2 |
| U and V low-pass, 31 taps each | 32 |
| YUV → RGB | 4 |
| **Total, fully parallel** | **≈59 DSP48E1 — 8% of the device** |

PAL delay line at the sample rate: 504 dots × 4 samples × 2 channels × 12 bits = 48 384 bits ≈ **2 RAMB36**.

**It fits, comfortably.** What this tier costs is engineering, not silicon: it is a genuine encoder, separator and demodulator that must be tuned by eye against reference material, and CLK — the obvious source to copy from — has no delay line to copy. Half of it, the encoder, already exists as `yc_out.sv` in the AExp tree.

Be honest in any write-up: **nobody in FPGA land has shipped the encode-then-decode round trip.** That is the interesting part and also the risky part.

### 20.3 A free by-product worth naming

If we build the encoder anyway, we get **real S-Video and composite output over the MEGA65's VGA connector** essentially for nothing — the same feature MiSTer users get from `yc_out.sv`. The `@TODO` comment sitting in `analog_pipeline.vhd:139` ("Evaluate the capabilities, including outputting an old composite signal instead of VGA") has been waiting for this. It belongs to the retro-tube story rather than to issue #28, but it is the same module.

<a name="ch21"></a>

## 21. Tier 3-alt — Blargg's answer: precompute the whole thing

This may well be the sweet spot, and it deserves to be evaluated on its own merits rather than as a fallback.

Run the entire Tier 3 chain **offline**, for every (colour, subcarrier phase) pair, and store the resulting RGB impulse response — how much red, green and blue this one input pixel contributes to each of the next few output pixels. At runtime, sum the overlapping kernels of neighbouring pixels. Because the chain is linear, this is exact.

**Runtime cost: six table reads, five adds, one clamp. Zero multipliers.** And with the packed-RGB trick — all three channels in one word with guard bits between them — those five adds are five adds *total*, not fifteen.

**Table size for a C64.** The subcarrier phase repeats every 16 dots (`f_dot / f_sc = 16/9`); PAL's line alternation and the half-integer 283.5 cycles per line both have a two-line period, so 32 states in total.

| Configuration | Bits | RAMB36 |
|---|---|---|
| 16 colours × 16 phases × 8 taps × 3 ch × 10 bit | 61 440 | 1.7 |
| 16 colours × 32 states × 8 taps × 3 ch × 10 bit | 122 880 | 3.3 |
| 16 colours × 32 states × 12 taps × 3 ch × 10 bit | 184 320 | 5.0 |

**The full horizontal composite behaviour of a PAL C64: about four block RAMs out of 190 free, eight adders, and no multipliers.** Add Tier 1's line buffer on top for the vertical delay line, which this architecture structurally cannot provide — the same limitation that CLK and Blargg both have.

Two implementation notes that are easy to get wrong:

* **The six table reads are six independent addresses**, and a 7-series block RAM has two ports. Replicating the table three times would cost 12 to 15 RAMB36 instead of four. Do not replicate — *time-multiplex*. `video_ce` is an unconditional divide-by-four, so there are four `main_clk` cycles per C64 pixel; two true-dual-port BRAMs over four cycles give sixteen reads per pixel against the six needed. The margin is comfortable.
* **The phase counter must free-run across blanking.** 504 dots per line is 31.5 × 16, so the mod-16 phase advances by half a period per line — that *is* the 283.5-cycles-per-line, 180°-per-line behaviour from [§4.1](#c64-numbers). Resetting the counter at each line would destroy exactly the effect you are trying to reproduce. (A pleasant check: 312 × 504 = 157 248 is divisible by 16, so the whole pattern also repeats exactly once per frame.)

Two honest limitations: the input must be the small colour index (indexing by RGB is what turns a 32 KB table into a 4 MB one), and everything after the clamp is linear superposition, so comb-filter nonlinearity, AGC and overload are not modelled.

The table would be generated offline by a small host-side program — a natural companion to the existing `M2M/video_filters/convert.py` — and uploaded by QNICE exactly like the polyphase coefficients are today.

<a name="ch22"></a>

## 22. The tube layer

This is the other half of the problem, and it is mostly *already solved* in M2M. What follows is the short list of what is worth adding, what is worth refusing, and one piece of arithmetic that constrains the whole thing.

### 22.1 What exists

Scanlines and horizontal beam softening ship today as ascal polyphase coefficient sets, uploaded at runtime by QNICE. Worth noting how they work, because it is better than the obvious approach: the polyphase scanline is **phase-based, not row-parity based**, so it degrades gracefully at non-integer scale ratios where MiSTer's row-parity `scanlines.v` would beat. Keep it.

The one flaw is that it operates in sRGB space, which is why the brightness-compensated variants exist — and, as [§17.2](#ch17) explains, that cannot be fixed from outside ascal without pushing 8-bit linear light through the scaler. Any new *tube* stage should do its own linear-light arithmetic; ascal's own resampling stays as it is.

Also worth recording: the analog path has **no** pixel processing whatsoever today. That gap is already scoped in the separate research done for issue #250 (analog 31 kHz quality), which recommends scanlines, hybrid scanlines, an optional HQ2X, and a `cofi`-style two-tap blend for the VGA path. **This document deliberately does not re-cover that ground** — issue #250 is about the tube on the analog path, issue #28 is about the signal.

### 22.2 The mask arithmetic, which decides the whole question

The C64 core hands M2M a 382 × 270 active picture. (The repository is not entirely self-consistent here: `main.vhd` says the crop is 382 × 270, while `globals.vhd` declares `VGA_DX = 720`, `VGA_DY = 540`, which is what sizes ascal's input buffer and the OSM character grid. The mask and scanline arithmetic below uses the *data-enable window*, 382 × 270; the 720 × 540 figure is a buffer-sizing declaration, not a picture size.) Output modes are 1280×720 and 720×576 / 720×480.

| Mode | Output rows per C64 line | Triads across at 3-pixel pitch |
|---|---|---|
| 1280×720 | 2.67 | 426 |
| 720×576 | 2.13 | 240 |
| 720×480 | 1.78 | 240 |

From which:

1. **A mask needs at least three output columns per triad.** At 720p that gives 426 triads across — roughly half the triad density of a real 1084-class tube. So even at 720p a mask reads as visible stripes rather than as texture. That is the accepted compromise everywhere, not a defect.
2. **At 576p the mask period is 1.6 C64 pixels** — the same spatial frequency as the content, which guarantees moiré. **Gate the mask off whenever the horizontal output is below 1280.**
3. **Scanlines need at least two output rows per source line.** 720p (2.67) fine, 576p (2.13) marginal, 480p (1.78) **no** — gate them off there.
4. **Offer a vertical-stripe aperture grille only, never a dot or slot mask.** A slot mask needs two output rows per mask cell *on top of* the two rows scanlines already want; 720p does not have four or five rows per source line to spend.

MiSTer's `shadowmask.sv` is directly liftable: a 16×16 tile ROM of 256 eleven-bit entries, shift-add multipliers, five-stage pipeline, **zero DSP slices**, with an optional 2× scale. It is already on disk in the AExp tree.

### 22.3 What to refuse, and why

* **Curvature.** Requires a per-pixel inverse geometric mapping, therefore arbitrary two-dimensional access to a whole frame. Incompatible with a streaming line-buffer pipeline.
* **Phosphor persistence.** Two independent reasons. It is *physically wrong*: real P22 decays below 10% in well under 100 µs for blue and green, against a 20 ms frame — what people call afterglow is eye and camera integration, and the shaders that model it use a ~100 ms time constant, a hundred times the real value. And it is *expensive*: 1280×720×3 bytes at 50 Hz is about 138 MB/s in each direction, so 276 MB/s combined. The MEGA65's HyperRAM is 8 bits wide, double-data-rate, at 100 MHz — a **theoretical peak of 200 MB/s before any command or latency overhead**, and on R3 it is the only memory and already serves three masters (ascal, the cartridge/REU path, QNICE). The requirement exceeds the entire bus, by itself, before anyone else gets a cycle.
* **Large-radius bloom.** A nine-tap separable blur is nine line buffers and ~54 multipliers, and nine taps at 74.25 MHz with 1.9 ns of slack will not close without heavy pipelining. A three-tap approximation is the realistic version.

### 22.4 Where the tube layer goes

Post-ascal, pre-OSM: between the scaler output and `i_video_overlay` in `digital_pipeline.vhd`. That is the only place where "output pixel" is a meaningful unit, and it is upstream of the menu, which matters — see below.

Note the timing constraint: `hdmi_clk` has only ~1.9 ns of slack on a 13.5 ns period. Everything here must be aggressively pipelined and kept to roughly one LUT level plus a BRAM lookup per stage.

<a name="ch23"></a>

## 23. Framework design — what belongs where

### 23.1 The insertion points, precisely

Two, and only two.

**Signal-domain stage — one instance, both outputs.** At the top of `M2M/vhdl/av_pipeline/av_pipeline.vhd`, upstream of `i_analog_pipeline` (line 397) and `i_crop` (line 532). Clock: `video_clk`, 31.53 MHz. Rate: the core's own `video_ce`. This is the only insertion point that serves the VGA connector *and* the HDMI connector from one instance, and it is the only one where a filter can be specified in units of the machine's own dot clock — which is precisely what ascal's polyphase fundamentally cannot express, since it runs at output resolution after a HyperRAM round trip.

**Tube-domain stage — HDMI only.** In `digital_pipeline.vhd`, between `i_ascal` (line 334) and `i_video_overlay` (line 497). Clock: `hdmi_clk`.

(Line numbers are from the standalone M2M repository; the copy inside C64MEGA65 has drifted and differs by a few lines in both files.)

### 23.2 The on-screen menu stays crisp for free

This is worth stating explicitly because it is the thing that usually makes such features painful. In `video_overlay.vhd` the OSM is composited **by replacement, not by blending**:

```vhdl
if stage8_vga_osm_on = '1' then
   stage9.vga_red   <= stage8_vga_osm_rgb(23 downto 16);
   stage9.vga_green <= stage8_vga_osm_rgb(15 downto  8);
   stage9.vga_blue  <= stage8_vga_osm_rgb( 7 downto  0);
end if;
```

and the overlay runs at *output* resolution on both paths, downstream of both proposed insertion points. Menu text therefore never passes through any of the new stages. No keying, no alpha, no signal to export.

The corollary is a rule: **do not put the tube stage after `i_video_overlay`.** At 720p an OSM character cell is 16×16 output pixels at the default menu scaling (the overlay applies a fractional scale factor, so glyphs can be up to twice that), and a three-pixel grille would put five stripes across every glyph.

One discipline to copy: AExp's `analog_positioner.vhd` documents a *genuine bypass* contract — when the feature is disabled the block is a registered pass-through with identical latency, so a build with the feature off is bit-identical to a build without the block at all. Every new stage should carry that guarantee, and any added latency must be applied to `hs`, `vs` and `de` in lockstep or the OSM will shift horizontally (the overlay already delays video by eight stages to align with the menu).

### 23.3 The VGA / HDMI policy

**When `retro15kHz = '1'`, the entire tube stack must be forced off in hardware**, not merely defaulted off in the menu. There is a real CRT attached; every effect in §22 is either redundant or actively harmful:

* Scanlines: at 15 kHz there is exactly one output row per source line. There is no spare row to darken, and the tube already produces the gap.
* Mask: the attached tube has a physical one. A synthetic 3-pixel grille beats against it.
* Gamma: the C64 palette is already authored for a ~2.8-gamma tube; an sRGB-targeted correction double-corrects.
* Bloom and persistence: the tube does both, in analogue, for free.

The **signal**-domain stages are a different matter and should stay *available* at 15 kHz, because chroma bandwidth and the delay line are properties of the source-plus-receiver, and a 15 kHz RGB monitor is not a composite receiver either. Whether to enable them there is a taste question; make it a menu item rather than a hardware gate.

Interaction with flicker-free: **none.** The control loop compares ascal's frame-buffer *write* pointer against its *read* pointer once per frame, and drives the PLL mux from the difference. It therefore closes entirely upstream of ascal's output port, and any stage placed after ascal is structurally invisible to it. Worth a code comment, because it is the first thing anyone will worry about.

### 23.4 The proposed interface

M2M's contract with a core is currently "hand me RGB". The minimum extension is: let a core also declare **what kind of display the original machine drove**, and optionally hand over its native colour index.

```vhdl
-- NEW: M2M/vhdl/av_pipeline/video_config_pkg.vhd
type source_kind_t is (SRC_COMPOSITE, SRC_SVIDEO, SRC_RGB_CRT, SRC_LCD);

type crt_config_t is record
   enable       : std_logic;              -- master on/off
   scanline_str : unsigned(2 downto 0);   -- 0..4
   mask_kind    : unsigned(1 downto 0);   -- 00 off, 01 grille, 10 grille 2x
   glow_str     : unsigned(1 downto 0);   -- 0..3
   src_gamma    : unsigned(1 downto 0);   -- 00 = 2.2, 01 = 2.4, 10 = 2.8
end record;
```

with generics `G_SOURCE_KIND`, `G_NATIVE_H`, `G_NATIVE_V` and `G_DEFAULT_PRESET` on the new stages, and one new port on `MEGA65_Core` in the QNICE domain carrying the config record — decoded from `qnice_osm_control_i` exactly like the existing `qnice_ascal_mode_o`.

For the signal-domain work, one optional extra: a **palette-index side channel**, `video_index_o : out std_logic_vector(N-1 downto 0)` plus `video_index_valid_o`. A core that has a small palette can hand it over and unlock the index-domain tiers; a core that does not simply leaves it unconnected.

That is a deliberately small interface. The division of labour it encodes is worth putting in the wiki as a sentence: **the core owns the picture; the framework owns the tube.**

### 23.5 The menu

Keep the visible option count small and nest it, using the multi-level submenu and dependent-entry mechanisms M2M now has:

```
 CRT Emulation: %s
   CRT Emulation
   Off
   Sharp                   gamma + light scanlines, no mask
   Tube                    gamma + scanlines + grille + slight glow
   Custom
   ---
   Scanlines      < 3 >    greyed unless Custom
   Shadow Mask    < 1 >    greyed unless Custom; greyed if H_PIXELS < 1280
   Glow           < 1 >    greyed unless Custom
   Gamma          < 2.8 >  greyed unless Custom
```

plus, in the signal group:

```
 PAL Blend      < Off / Blended Colours / All Colours >   greyed in NTSC mode
 Chroma Bandwidth < Off / Soft / TV >
 Palette        < Colodore / Pepto / VICE / 6569R1 >
```

Dependency rules to encode: whole tube submenu greyed when `retro15kHz = '1'` (header `%s` reading `n/a (15 kHz)`); mask greyed below 1280 pixels wide; scanlines greyed at 480p; `PAL Blend` greyed in NTSC.

Settings persist through the existing `.cfg` mechanism at no extra cost — they are ordinary OSM bits.

**One caution from hard experience:** adding OSM items shifts every later `C_MENU_*` bit index in `mega65.vhd`, and `MENU_HEAP_SIZE` has to be re-checked. Drive the change from `menu_test.py` rather than by hand.

Finally, a naming matter. The V6 menu already offers *CRT (S-Video)* and *CRT (Composite)*, and those are blur presets. If real composite processing arrives, the two names collide. Either rename the existing presets to what they are (*Soft*, *Very Soft*) or place the new feature under a clearly different heading. Better to decide that now than after users have learned the current labels.

<a name="ch24"></a>

## 24. The three cores, in practice

The instruction to "be practical about our cores" produces a genuinely different answer for each of them, and two of the three answers are not what one would guess.

### 24.1 C64MEGA65 — the whole document applies

Everything above was written with this core in mind. It has a 4-bit colour index, a composite/S-Video native output, a fixed `/4` pixel clock enable, exact subcarrier arithmetic at its main clock, and 90% of the device's DSP capacity unused. `ROADMAP.md` already lists "Simulate the blending of colours when ALM and DCM are used".

Recommended: Tier 0 → export `colorIndex` → Tier 1 → Tier 2 (boxcar) → optionally Tier 3-alt.

### 24.2 AExp (Amiga 500) — mostly *not* applicable, and that is the finding

<a name="aexp"></a>

The A500 drove **analog RGB** out of its 23-pin video connector into a 1084. It is a component source, not a composite one. There are no artefact colours to reconstruct, and a chroma low-pass would be *authenticity-negative*. With 4096 colours the index domain is unavailable anyway.

What the Amiga's "retro look" problem actually is:

1. **Interlace flicker** — 512-line laced modes flicker at 25 Hz. Already solved, and solved well: AExp weaves the fields in ascal (`INTER => true`, `i_fl => video_fl_i`), and the change is already marked `M2M-UPSTREAM`.
2. **Phosphor persistence for 15 kHz demos.** AExp's own `doc/retrotubes.md` puts it nicely — on a real tube "the intentional flicker effects of demos melt on the phosphor exactly as their authors intended." This is the one core where persistence has a genuine justification, and it is also the one effect §22.3 argues against on cost grounds. Worth revisiting only for R4+ boards where ascal has SDRAM to itself.
3. **A cautionary constraint for framework design:** AExp's pixel clock enable is a *frame-locked* mux between 7.09 and 14.19 MHz, latched once per frame so ascal's line length does not change mid-frame. **Any framework block that assumes a constant pixel rate will break this core.** The C64's fixed `/4` divider makes it easy to forget that cores differ here.

What AExp *would* gain from this work: Tier 0's gamma, the tube layer's mask and scanlines, and — if the encoder from Tier 3 gets built — genuine S-Video output for people driving a 1084 over the VGA port.

### 24.3 gbc4mega65 — a different problem entirely, with the cheapest win in the project

<a name="gbc"></a>

A Game Boy has no cathode ray tube, no scan, no composite signal, and no subcarrier. Almost nothing in Parts I and II applies. Its authentic look is: a reflective LCD's washed-out gamma, a visible pixel grid, and — most importantly — **LCD response ghosting**.

Current state:

* **GBC colour correction: already done, and done right.** The core implements the Gambatte matrix in `CORE/GameBoy/lcd.v`, exposed as `Color Mode → LCD Emulation / Fully Saturated`. Peak output is 248, not 255, on all three channels, which *is* the reflective-LCD white.
* **DMG green: implemented upstream, tied off here.** `pal1..pal4` and `tint` are real input ports on `lcd.v`; the port ties them to zero with the comment that greyscale is authentic. Four constants and a bit would give the classic panel.
* **LCD ghosting: implemented upstream, tied off here.** `lcd.v` contains a working 50/50 inter-frame blender backed by a full previous-frame store, `reg [14:0] prev_vbuffer[160*144]` — and `CORE/vhdl/lcd_wrapper.v:80` ties `.frame_blend(1'b0)`.
* **Dot-matrix grid: not implemented anywhere.** A genuine addition, and cheap at output resolution.

The ghosting item is the highest-value-per-effort change available in any of the three cores: **flip one constant to an OSM bit.** Be accurate about the cost, though — because the enable is tied to a constant, synthesis currently prunes the buffer, so turning it on *adds* 23 040 × 15 bits = 345 600 bits, about **10 RAMB36**, plus three adders and no DSP slices. That is still cheap, and it matters for *correctness* as well as looks: several Game Boy titles use single-frame flicker for transparency effects that only resolve on a ghosting panel. (gbc4mega65's own block-RAM headroom was not measured for this document — check it before committing.)

And one thing to *stop* doing: gbc4mega65's HDMI filter menu currently offers *CRT (S-Video)* and *CRT (Composite)* on a handheld LCD console. All three cores inherited the same list. Under the interface proposed in §23.4, a core declaring `SRC_LCD` would simply not be offered them.

### 24.4 A note on the WIP Apple II core

There is a local Apple II port (`Apple-II_MEGA65`, by lydon42, no release yet), and it is the case where composite decoding is a *correctness* feature rather than a cosmetic one — Apple II hi-res colours do not exist except as NTSC artefacts. Its dot clock is 14.318181 MHz, exactly 4× the subcarrier, which is the friendliest possible ratio.

It already implements four-phase artefact colour with a six-dot window and four basis colours. What that approach does not give: chroma bandwidth limiting (real Apple II colour fringes bleed over several dots), luma/chroma crosstalk, or dot crawl. It also currently hardwires the core's own monochrome/green/amber monitor modes off (`SCREEN_MODE => (others => '0')`) although the RTL for them is finished — a free menu item waiting to be wired.

If anyone ever wants to justify building Tier 3 properly, this is the core that would benefit most.

<a name="ch25"></a>

## 25. Non-goals, risks, and how to know it works

### 25.1 Explicit non-goals

* **Curvature and geometric distortion.** Needs a framebuffer.
* **Cross-frame phosphor persistence** for the C64. Physically wrong and expensive.
* **Making anything on by default.** Every filter in this document should ship `Off`, for exactly the reason sorgelig gives.
* **Touching the analog 31 kHz path.** Separately scoped in the issue #250 research.
* **Re-implementing what ascal already does well.** Scaling, scanlines and horizontal softening are fine as they are.

### 25.2 Risks worth naming up front

* **Timing on `hdmi_clk`.** Only ~1.9 ns of slack at 74.25 MHz. The tube stage must be pipelined hard. The signal stages live at 31.5 MHz with 9.4 ns of slack and are much safer.
* **Latency alignment with the OSM.** `video_overlay` aligns video against the menu with a fixed eight-stage delay. Any inserted latency must be applied to the syncs in lockstep.
* **Menu bit-index ripple.** Adding OSM items renumbers every later `C_MENU_*` constant.
* **The "looks right" problem.** Filter coefficients that are correct on paper can look wrong on a modern panel. Budget iteration time, and build the comparison harness *before* the filter.
* **Fork drift.** Our `fpga64_rgbcolor.vhd` predates upstream's palette selector, and the M2M standalone repo and the C64MEGA65 in-tree copy have drifted in both directions. Decide deliberately whether to rebase or to diverge.

### 25.3 How to test

The failure mode of this kind of work is shipping something that is defensible in theory and unconvincing on screen. Three concrete checks:

1. **The named games.** *Mayhem in Monsterland* (alternate-line colour, tuned for five-luma chips — test with the 6569R1 palette as well as the default), *Parallaxian* (alternate-line plus static chequerboard plus a per-frame swapped chequerboard driven by a raster interrupt), and whatever *Sam's Journey* actually uses (paich64 cites it; the technique is worth confirming rather than assuming).
2. **A synthetic test screen.** One screen containing: the sixteen colours as flat blocks; every pair of same-luma-cluster colours as alternating lines; the same pairs as single-pixel chequerboards; 1/2/4-pixel-wide colour bars to exercise the chroma bandwidth; and a block of white text on black to check that luma stays sharp and that nothing sprouts false colour.
3. **A reference.** VICE with the PAL renderer at known settings (`PALBlur 500`, `PALOddLineOffset 500`, `PALOddLinePhase 1500`), screenshotted and compared side by side. Not because VICE is ground truth — it is another model — but because it is the model our users will compare against, and any large discrepancy is worth understanding before shipping.

If a real PAL C64 and a 1084 are available, photographing the same test screen is worth more than all three of the above.

<a name="ch26"></a>

## 26. A suggested order of work

Nothing here needs to be done all at once, and the early steps are independently useful.

| # | Step | Cost | Delivers |
|---|---|---|---|
| 1 | Gamma LUTs around the tube stage; wire MiSTer's existing `gamma_corr.sv` on the analog path | ~3 RAMB36, 0 DSP | Correct light for everything we add. Note it does *not* fix ascal's internal sRGB resampling, so the `Scan_Br_*` variants stay |
| 2 | Palette selector in `fpga64_rgbcolor.vhd` (including the 6569R1 five-luma set) | 0 BRAM, 0 DSP | User choice; and the *precondition* for judging step 4 |
| 3 | Export `colorIndex` from `fpga64_sid_iec` | 2 lines | Unlocks steps 4 and 7 |
| 4 | **Tier 1: PAL line blending**, three-state menu item, off by default, NTSC-gated | ~1 BRAM tile, 0 DSP | **Closes MiSTer issue #104 and the ROADMAP item.** The single highest payoff-to-risk step |
| 5 | Tier 2 boxcar chroma low-pass | 2 adders | Chequerboard fusion; general PAL softness |
| 6 | The generic `video_config_pkg` interface + tube stage skeleton with grille and scanlines, gated by output resolution and `retro15kHz` | ~1 BRAM, ~120 LUT | Framework feature all cores share |
| 7 | Tier 3-alt kernel LUT, as `CRT: Composite (full)` | ~4 RAMB36, 0 DSP | Dot crawl and cross-colour; visually supersedes 4+5 |
| 8 | Tier 3 live encoder/decoder — only if the fixed kernel proves too rigid | ~59 DSP, 2 RAMB36 | Full fidelity; also gives S-Video out over VGA |

Steps 1 to 5 are, together, a modest amount of work and would deliver everything paich64 asked for in 2021. Steps 6 to 8 are a project.

And one last framing, since issue #28 began by asking what the magic is:

> There is no magic. There is a signal our cores never generate, two filters that every PAL television applies to its colour, and a piece of glass that adds texture. We already model the glass. The rest is a line buffer, a lookup table, and a decision to do it.

---

# Part V — Reference

<a name="glossary"></a>

## Appendix A — Glossary

Terms are defined the way they are used in this document.

**Aperture grille** — a display mask made of vertical R/G/B phosphor stripes (Sony Trinitron style), as opposed to a dot or slot mask.

**Chroma** — the colour information of a video signal, carried as amplitude and phase of a subcarrier. Phase is hue, amplitude is saturation.

**Colour burst** — nine or ten cycles of unmodulated subcarrier sent during each line's back porch, so the receiver knows where phase zero is.

**Comb filter** — a filter that separates luma from chroma by comparing adjacent *lines* rather than adjacent samples, exploiting the fact that the subcarrier phase relationship repeats vertically.

**Cross-colour** — fine luma detail at a frequency near the subcarrier being decoded as colour. On the Apple II this is not a defect but the entire colour system.

**Cross-luminance / dot crawl** — chroma leaking into the luma channel, producing the crawling dotted fringe on saturated colour edges.

**DDS / NCO (numerically controlled oscillator)** — generating a periodic waveform by repeatedly adding a constant to a phase accumulator and using the accumulator's top bits to index a sine table.

**Delay line** — in a PAL receiver, a device that holds one line's chroma (64 µs) so it can be averaged with the next. Originally a block of glass carrying an acoustic wave.

**FIR filter** — Finite Impulse Response: a weighted moving average, `output = Σ coefficient[k] × input[n−k]`. **Taps** is the number of coefficients. A *symmetric* (linear-phase) FIR can be "folded", halving the number of multipliers.

**Hanover bars** — the horizontal striping that appears when PAL's line-to-line phase errors are *not* averaged away, i.e. when the delay line is absent or misadjusted.

**Kernel** — in the Blargg sense, the impulse response of the whole encode/decode chain for one input pixel: how much R, G and B it contributes to each of the next N output pixels.

**Linear light** — pixel values proportional to photons, as opposed to sRGB values, which are proportional to perception. Blending is only correct in linear light.

**Luma** — the brightness component, `Y`. Carries almost all of the detail the eye is sensitive to.

**Phase alternation (the PAL switch)** — inverting the sign of the `V` colour-difference component on every second line so that transmission phase errors cancel between line pairs.

**Polyphase filter** — an FIR whose coefficient set is chosen per output sample from N precomputed "phases", according to where the output sample falls between two input samples. This is a *resampler*, which is why it cannot be repurposed as a fixed-frequency filter. ascal uses 4 taps and 64 phases.

**QAM (quadrature amplitude modulation)** — carrying two independent signals on one frequency by modulating a sine and a cosine of it. Demodulation is multiplying by each and low-pass filtering.

**Subcarrier** — the fixed high frequency (4.43361875 MHz PAL, 3.579545 MHz NTSC) onto which chroma is modulated.

**U, V** — the two colour-difference signals of PAL, roughly blue-minus-luma and red-minus-luma. NTSC's `I`/`Q` are the same pair rotated 33°.

<a name="numbers"></a>

## Appendix B — The numbers in one place

### B.1 The machines

| | C64 PAL (6569) | C64 NTSC (6567R8) | Amiga 500 OCS PAL | Game Boy Color | Apple II |
|---|---|---|---|---|---|
| Master crystal | 17.734475 MHz | 14.31818 MHz | 28.37516 MHz | 4.194304 MHz | 14.318181 MHz |
| Colour subcarrier | 4.43361875 MHz | 3.579545 MHz | (RGB output) | (none) | 3.579545 MHz |
| CPU clock | 985 248.6 Hz | 1 022 727 Hz | 7.09 MHz | 4.194304 MHz | 1.0227 MHz |
| Dot clock | 7.881989 MHz | 8.181818 MHz | 7.09 / 14.19 MHz | ~6.71 MHz CE | 14.318181 MHz |
| Line | 504 dots / 63 cycles | 520 dots / 65 cycles | — | — | 910 CRT cycles |
| Lines/frame | 312 | 263 | 313 | 154 | 262 |
| Frame rate | 50.1246 Hz | 59.826 Hz | 49.9201 Hz | 59.7275 Hz | ~59.94 Hz |
| Subcarrier cycles/line | **283.5** | **227.5** | — | — | **227.5** |
| Dot clock ÷ subcarrier | **16/9** | **16/7** | — | — | **4** |
| Colour output | luma + chroma | luma + chroma | analog RGB | reflective LCD | composite only |
| Colours | 16 (4-bit index) | 16 | 4096 (12-bit) | RGB555 | 4-phase artefacts |

### B.2 Our implementation

| Quantity | Value | Source |
|---|---|---|
| C64 core main clock | 31.527778 MHz (ideal 31.527954) | `CORE/vhdl/globals.vhd:47` |
| C64 core pixel CE | main ÷ 4 = 7.881944 MHz | `CORE/vhdl/main.vhd:1669-1680` |
| Subcarrier per main clock, PAL | **exactly 9/64 cycle** | derived |
| Subcarrier per main clock, NTSC | **exactly 7/64 cycle** | derived |
| Samples per subcarrier cycle at main clock | 7.111 | derived |
| Samples per line at main clock | 2016 | derived |
| Active picture handed to M2M (DE window) | 382 × 270 | `CORE/vhdl/main.vhd:1647` |
| ascal input buffer sizing | `VGA_DX = 720`, `VGA_DY = 540` | `CORE/vhdl/globals.vhd:69-70` |
| HDMI pixel clock | 74.25 MHz (720p50) / 27 MHz (576p50) | `video_modes_pkg.vhd` |
| ascal polyphase | 4 taps × 64 phases, signed 10-bit, unity = 256 | `ascal.vhd`, `M2M/rom/filters.asm:15-17` |

### B.3 The device budget

Measured from `CORE/CORE-R{3,6}.runs/impl_1/*_utilization_placed.rpt` and `*_timing_summary_routed.rpt`, 31 July / 1 August 2026.

| Resource | Used | Available | Free |
|---|---|---|---|
| Slice LUTs | 33 318 (24.9%) | 133 800 | ~100 000 |
| Slice registers | 25 592 (9.5%) | 269 200 | ~243 000 |
| Block RAM tiles | 175 (48.0%) | 365 | **190** (≈6.7 Mbit) |
| DSP48E1 | 75 (10.1%) | 740 | **665** |

Part: `xc7a200tfbg484-2` on **all four** board revisions (R3, R4, R5, R6) — verified from the `.xpr` files and the report headers. There is no XC7A100T board in this project.

The used/free figures above are measured on **R3 and R6** (reports dated 1 August and 31 July 2026). The R4 and R5 reports on disk date from June 2024 and show a different, older design (204 BRAM tiles, ~24.7k LUT); they are stale and should be rebuilt before being quoted.

Per-clock timing slack (R6):

| Clock | Period | Slack | Comment |
|---|---|---|---|
| `main_clk` | 31.718 ns | **+9.420 ns** | build here |
| `hdmi_clk` | 13.468 ns | +1.889 ns | tight; pipeline hard |
| `hr_clk` | 10.000 ns | +0.501 ns | do not touch |
| `qnice_clk` | 20.000 ns | +0.493 ns | do not touch |

The global worst path (+0.378 ns) is the HyperRAM `hr_rwds` capture path — a fixed I/O relationship that new video logic will not move.

### B.4 Cost of each proposed tier

| Tier | Block RAM | DSP48 | Adders/mults per pixel | Latency |
|---|---|---|---|---|
| 0 — gamma + palette | ~3 RAMB36 | 0 | 0 | few clocks |
| 1 — PAL line blend (index domain) | ~1 tile | 0 | 0 (one BRAM read) | 1 pixel |
| 2 — chroma boxcar | 0 | 0 | 2 adders | few clocks |
| 2 — chroma 29-tap | 0 (shift registers) | 8 time-shared / 30 parallel | 30 MAC | ~15 clocks |
| 3-alt — Blargg kernel LUT | ~4 RAMB36 | 0 | 6 reads + 5 adds | ~8 clocks |
| 3 — live modulate/demodulate | 2 RAMB36 | ~59 | ~59 MAC | ~40 clocks |
| Tube: grille + scanlines | ~1 RAMB36 | 0 | shift-add | few clocks |
| Tube: 3-tap bloom | ~2 RAMB36 | ~18 | 18 MAC | 2 lines |
| Refused: persistence | full framebuffer | 3 | — | 1 frame |

<a name="codemap"></a>

## Appendix C — Where the relevant code is

### In our own repositories

| What | Path |
|---|---|
| C64 palette (Colodore, hardcoded) | `C64MEGA65/CORE/C64_MiSTerMEGA65/rtl/fpga64_rgbcolor.vhd:37-54` |
| Palette instantiation; `vicColorIndex` is internal | `.../rtl/fpga64_sid_iec.vhd:279, 653-659` |
| `colorIndex` generation, border and blanking in index space | `.../rtl/video_vicII_656x.vhd:1384-1396` |
| Core → framework video handoff | `C64MEGA65/CORE/vhdl/main.vhd:1666-1680` |
| Framework video input ports | `M2M/vhdl/framework.vhd:124-130`, `i_av_pipeline` at `:865` |
| **The signal-domain insertion point** | `M2M/vhdl/av_pipeline/av_pipeline.vhd`, before `:397` and `:532` |
| Analog path: MiSTer `video_mixer`, gamma unwired | `M2M/vhdl/av_pipeline/analog_pipeline.vhd:142-165` |
| Analog OSM composite | `.../analog_pipeline.vhd:182` |
| `@TODO` about composite output over VGA | `.../analog_pipeline.vhd:139` |
| Digital path: ascal | `M2M/vhdl/av_pipeline/digital_pipeline.vhd:334` |
| **The tube-domain insertion point** | `.../digital_pipeline.vhd`, between `:334` and `:497` |
| Digital OSM composite (replacement, not blending) | `.../digital_pipeline.vhd:497`, `video_overlay.vhd` `p_stage9` |
| ascal polyphase coefficient port | `.../digital_pipeline.vhd:446-449` |
| Polyphase filter format and loader | `M2M/rom/filters.asm:15-17`, `M2M/rom/tools.asm` (`M2M$LOAD_POLYPHASE`) |
| Filter coefficient files and README | `M2M/video_filters/` |
| MiSTer gamma module (vendored, unused) | `M2M/vhdl/controllers/MiSTer/gamma_corr.sv` |
| MiSTer hq2x (vendored, tied to `'0'`) | `M2M/vhdl/controllers/MiSTer/hq2x.sv` |
| **MiSTer composite/S-Video encoder (present, unused)** | `AExp/CORE/Minimig_MiSTerMEGA65/sys/yc_out.sv` |
| MiSTer shadow mask (present, unused) | `AExp/CORE/Minimig_MiSTerMEGA65/sys/shadowmask.sv` |
| MiSTer zero-multiplier colour matrix | `AExp/CORE/Minimig_MiSTerMEGA65/sys/vga_out.sv:39-53` |
| Bypass-contract precedent | `AExp/M2M/vhdl/av_pipeline/analog_positioner.vhd` |
| Amiga interlace weave (already upstreamed) | `AExp` → `digital_pipeline.vhd` `INTER => true` |
| Game Boy colour correction (Gambatte matrix) | `gbc4mega65/CORE/GameBoy/lcd.v:239-265` |
| Game Boy frame blend (implemented, tied off) | `gbc4mega65/CORE/GameBoy/lcd.v:221, 251-257, 305-308`; disabled in `gbc4mega65/CORE/vhdl/lcd_wrapper.v:80` |
| Game Boy DMG tint (implemented, tied off) | `lcd.v` `pal1..pal4`, `tint`; zeroed in `lcd_wrapper.v:70-79` |
| Apple II four-phase artefact colour | `Apple-II_MEGA65/CORE/Apple-II_MiSTerM65/rtl/vga_controller.vhd:51-58, 143-166` |
| C64 video menu items | `C64MEGA65/CORE/vhdl/config.vhd:471-517`; bit indices in `mega65.vhd:419-447` |
| HDMI filter dispatch table | `C64MEGA65/CORE/m2m-rom/m2m-rom.asm:1337-1354` |

### External references

* Tom Harte, **CLK** — https://github.com/TomHarte/CLK — the contract is `Outputs/ScanTarget.hpp`; the decoder is `Outputs/ScanTargets/FilterGenerator.cpp` plus the Metal/GLSL kernels; the FIR designer is `SignalProcessing/FIRFilter.cpp`.
* **MiSTer C64** issue #104 (paich64's request) — https://github.com/MiSTer-devel/C64_MiSTer/issues/104
* **MiSTer C64** PR #201 (palette selection, merged March 2026) — https://github.com/MiSTer-devel/C64_MiSTer/pull/201
* **Pepto**, *Calculating the colour palette of the VIC-II* — https://www.pepto.de/projects/colorvic/ ; successor **Colodore** — https://www.colodore.com/
* **Christian Bauer**, *The MOS 6567/6569 video controller* — https://www.cebix.net/VIC-Article.txt (see lines 243-261 for the clock and pin descriptions)
* **VICE** — `src/video/render2x2pal.c` (the delay line and the two filters), `render2x2ntsc.c` (the same minus the delay line), `src/vicii/vicii-color.c` (palettes and measured chip voltages)
* **Blargg's NTSC filters** — https://www.slack.net/~ant/libs/ntsc.html
* **AppleWin** composite decoder — `source/NTSC.cpp`
* **Lumacode** — https://github.com/c0pperdragon/LumaCode/wiki/ and the VIC-II-dizer page
* **RGBtoHDMI** — https://github.com/hoglet67/RGBtoHDMI/wiki and https://github.com/IanSB/RGBtoHDMI (the C64 blend is in `src/osd.c` and `src/capture_line_c64_8bpp.S`; comparison screenshots in issue #20)
* **Kodiak64**, *Luma-driven graphics on the C64* — https://kodiak64.co.uk/blog/luma-driven-graphics-on-c64 (the `.com` host now 404s)
* **libretro slang shaders** — https://github.com/libretro/slang-shaders (`crt/crt-royale.slangp`, `crt/shaders/crt-lottes.slang`, `crt-geom`, `crt-guest-advanced`)
* **Filters_MiSTer** and **ShadowMasks_MiSTer** — https://github.com/MiSTer-devel/Filters_MiSTer , https://github.com/MiSTer-devel/ShadowMasks_MiSTer

### Related internal work

* **Issue #250** (analog 31 kHz quality) — separate research report, covering the VGA path's missing scanlines, HQ2X, hybrid scanlines and a `cofi`-style blend. Deliberately not duplicated here.
* `C64MEGA65/ROADMAP.md` already carries the line *"Simulate the blending of colours when ALM and DCM are used"*.
