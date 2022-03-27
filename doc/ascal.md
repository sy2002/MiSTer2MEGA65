# Video rescaler

This page contains a few notes on the inner workings of the Video Rescaler
`ascal.vhd`.  These notes are obtained by examining the source code.

## Clock domains

The video rescaler operates on a total of FIVE different clock domains:
* Input video (`i_clk`)
* Output video (`o_clk`)
* External memory (`avl_clk`)
* Frame buffer (`pal1_clk` and `pal2_clk`)
* Polyphase filter (`poly_clk`)

In this MiSTer2MEGA framework, we are not using the Frame buffer or the
Polyphase filter, so these clocks are hard-wired to zero. In other
words, only the first three clock domains are used.

## Signal naming

The source code uses a consistent naming scheme of prefixing the signal name
with the corresponding clock domain, i.e. `i_*`, `o_*`, and `avl_*`.

## Clock domain crossing

Within the source code, some comments like `<ASYNC>` exist. These comments are
NOT read by the synthesis tool and are thus only for the convenience of the
reader.

Clock domain crossing is handled by explicit or implicit synchronization
registers.  In other words, the source signal is guaranteed (in the
implementation) to be stable for a number of clock cycles, thus allowing for a
stable value in the destination clock domain. This is a very resource efficient
use, and also quite portable.  However, it does require careful (manual)
analysis by the developer, because the Static Timing Analysis tool is not able
to assert the correctness. Instead, a catch-all `set_false_path` constraint is
needed to instruct the tool to ignore any potential timing errors.

For instance, these lines 1625-1641:
```
-- Push write accesses. Ensure a delay between consecutive writes
IF i_wreq='1' THEN
  i_wadrs_mem<=i_adrs; -- Address
  i_walt_mem <=i_alt;  -- Double buffer select
  i_wline_mem<=i_line; -- Line, for interleaved video
  i_wreq_mem<='1';
END IF;
IF i_wreq_mem='1' AND i_wdelay=5 THEN
  i_write<=NOT i_write;
  i_wadrs<=i_wadrs_mem;
  i_walt <=i_walt_mem;
  i_wline<=i_wline_mem;
  i_wdelay<=0;
  i_wreq_mem<='0';
ELSIF i_wdelay<5 THEN
  i_wdelay<=i_wdelay+1;
END IF;
```
contains this magic line 1633:
```
i_write<=NOT i_write;
```

Whenever a new write to the external memory is needed, the signal `i_write` is
toggled, i.e. 0-to-1 or 1-to-0 and is then guaranteed to remain unchanged for
at least 5 clock cycles (due to the `i_wdelay` signal).

Then, in lines 1743-1745 we have these lines in the destination clock domain
that detect a level change:
```
avl_write_sync<=i_write; -- <ASYNC>
avl_write_sync2<=avl_write_sync;
avl_write_pulse<=avl_write_sync XOR avl_write_sync2;
```

A careful analysis will show that this indeed works as intended, but the tool
is not able to make this inference, and thus reports this as a Critical CDC
error (when using the Report CDC command). In other words, the message from Vivado
is to be expected, and can be safely ignored in this situation.

## Data flow

* The video data stream enters on the input clock domain `i_clk` and is the
  written into `i_dpram` internal Dual Port memory (in lines 1691-1699).
* From there it is read out using the `avl_clk` clock domain in line 1701
* and written to the external memory using the `avl_*` port signals.
* Then the data read out of the external memory is written into the `o_dpram`
  internal Dual Port memory (in lines 1872-1880).
* From there it is read out using the output clock domain `o_clk` in line 1882.

In this way, the video data stream safely crosses between the three clock domains
using the two Dual Port memories.

## Triple buffering

The video rescaler support triple buffering in the sense that it reserves (uses)
three different address ranges in the external memory for video data.
The choice of address ranges is controlled by the signals declared in line 429:
```
SIGNAL o_ibuf0,o_ibuf1,o_obuf0,o_obuf1 : natural RANGE 0 TO 2;
```
When triple buffering is disabled, these buffer selectors are hardwired to zero
as shown in lines 2022-2028:
```
-- Triple buffer disabled
IF o_mode(3)='0' THEN
  o_obuf0<=0;
  o_obuf1<=0;
  o_ibuf0<=0;
  o_ibuf1<=0;
END IF;
```

