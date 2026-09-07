# Notes

Short, findable notes on things worth remembering or raising with the team — so they can
be re-read in a minute rather than by digging through reference documents that keep
growing.

Grouped by topic. Each note says what the thing is, why it matters, and what (if
anything) needs doing about it.

> **This file is only ever added to on explicit request.** Nothing lands here
> automatically — not as a by-product of explaining something, not after finishing a
> piece of work. If it is in here, Juan asked for it.

---

## BMS — Lithium Balance n-BMS

### The ESS thresholds already exist in our own BMS configuration

We do **not** need to transcribe them from a cell datasheet. Whoever configured the BMS
already entered them, because the n-BMS ships with **no factory defaults** for these — the
manual is explicit that *"safety thresholds must be configured by the user"* (p. 32), since
the safe window depends entirely on cell chemistry.

They live in the **"Operational Limits"** view of BMS Creator. That view is **not** part of
the `CAN Settings` export we currently have in `docs/CAN-Database-(DBC)-BMS.xlsx` — ours
covers the CAN configuration only. **Someone needs to export the Operational Limits view.**

What is in there, and the error code each one raises when crossed:

| Quantity | Parameter name in BMS Creator | Unit | Error code |
| :--- | :--- | :--- | :--- |
| Cell under-voltage | `Min. cell voltage` | mV | 2000 `ERROR_SYS_LIM_CELL_V_MIN` |
| Cell over-voltage | `Max. cell voltage` | mV | 2001 `ERROR_SYS_LIM_CELL_V_MAX` |
| Cell under-temperature | `Min. cell temperature` | °C | 2004 `ERROR_SYS_LIM_CELL_T_MIN` |
| Cell over-temperature | `Max. cell temperature` (range −35.0…100.0) | °C | 2005 `ERROR_SYS_LIM_CELL_T_MAX` |
| Continuous charge current | `DCLI` table | A | 2008 `ERROR_SYS_LIM_PACK_I_IN` |
| Continuous discharge current | `DCLO` table | A | 2009 `ERROR_SYS_LIM_PACK_I_OUT` |
| Peak-current integral | `Max. i2t` | A²s | 2010 `ERROR_SYS_LIM_PACK_I2T` |

There are also per-channel auxiliary temperature limits (`Min./Max. temp channel 1-6`) and
a separate **"Error Timers"** view holding the LOW → NORMAL → CRITICAL escalation delays
for each alarm, where 0 means trip immediately.

**Why it matters.** These are the numbers the pack is *actually* protected by. If the
dashboard warns on a second, separately-transcribed set, the two can drift apart — and the
failure mode is the dashboard staying quiet while the BMS is about to open the contactors,
or crying wolf when nothing is wrong. Taking both from the same configuration keeps the
warning and the protection in agreement by construction.

**What to do:** export the Operational Limits view, then fill in `src/BmsLimits.h`. Every
limit in that file is currently `NaN`, so no ESS alert can fire until this happens.

Manual references: §3.2 pp. 32–37 (narrative), appendix §8.9 pp. 145–159 (the parameters),
§8.2.2 p. 96 (the error codes), §3.6.1 p. 48 (escalation timers).

### The real current limit is a 2-D table, not a single number

`kPackCurrentWarning` / `kPackCurrentCritical` in `BmsLimits.h` are single constants. The
BMS does not work that way.

`DCLI` (charge) and `DCLO` (discharge) are **two-dimensional lookup tables over state of
charge × cell temperature** — the parameters are named `DCLI temperature N` and
`DCLI temperature N, SOC X %`. The allowed current genuinely changes as the pack warms,
cools and empties. A cold pack at low SoC will accept far less current than a warm one at
mid SoC, and the BMS enforces that continuously.

So a single constant can only ever be one of:

- **The worst-case value** from the table — safe, but it would nag constantly under
  perfectly legitimate conditions, and a warning the driver learns to ignore is worse than
  no warning.
- **A typical value** — quiet most of the time, but silent exactly when the pack is cold
  or nearly empty and the real limit has dropped below it. That is the dangerous direction.

There is a third option, and it is better than both. The BMS **publishes its own live
limits**, recalculated as conditions change:

| Data ID | Name | Type | Scaling | Meaning |
| :--- | :--- | :--- | :--- | :--- |
| 32 | `DYN_LIM_I_IN` | uint16 | 0.1 A | current charge limit, right now |
| 33 | `DYN_LIM_I_OUT` | uint16 | 0.1 A | current discharge limit, right now |
| 31 | `DYN_LIM_I2T_REMAIN` | uint32 | A²s | remaining peak-current budget |

Warning on *headroom* against these — how close `PACK_I_MASTER` is to the limit the BMS is
enforcing at this moment — is both more honest and more useful to the driver than a fixed
threshold, and it tracks the pack automatically instead of needing retuning.

`DYN_LIM_I2T_REMAIN` is worth a thought too: the i2t budget is a melting-fuse model, so it
depletes during a hard overtake and refills afterwards. A driver who can see it draining
has information no fixed current threshold can give them.

**Neither of these three is currently broadcast**, so enabling them is a request for the
next configuration change — they would each need a slot in a TX frame.

Manual references: §3.2.1 pp. 33–35 (DCLI/DCLO), §3.2.1.2 pp. 35–36 (i2t), p. 100
(the Data IDs).

### What the `0x200` error frames are

Separate from the TX frames entirely. Instead of putting a fault signal inside a data
frame, the BMS broadcasts its **list of currently active errors** across a block of
sequential CAN IDs, starting wherever `CAN ID start error frames` points. Ours is set to
512, so the block begins at `0x200`, extended, on S-CAN.

Three kinds of frame, all big endian like everything else from this BMS:

| ID | Contents |
| :--- | :--- |
| `0x200` | **Summary.** Byte 7 = count of active CRITICAL errors, byte 6 = NORMAL, byte 5 = LOW, bytes 3–2 = total active. |
| `0x201` | **Statistics.** Bytes 7–4 = total errors since boot. |
| `0x202` … | **One frame per active error**, packed consecutively. Byte 3 = severity, bytes 1–0 = the 16-bit error code. Up to 48 of them. |

The CAN ID of an error frame is only a slot number, not the error code — with two active
errors the BMS sends `0x200`, `0x201`, `0x202`, `0x203`. The code itself is in the payload.
Full code table in the manual, §8.2.2 pp. 91–99; the limit errors from the Operational
Limits note above (2000, 2001, 2004, 2005, 2008, 2009, 2010) all appear there.

**Why this matters to us.** It is the only available source for `backend.bmsFault`, which
drives the full-screen `BMS FAULT` overlay and has never had one. It answers a different
question from the five ESS values: those ask *"is a measurement out of range"*, this asks
*"does the BMS itself say it has a fault"*. The BMS knows things we cannot see from
voltage, current and temperature alone — balancing failures, CMU communication loss, a
welded contactor, internal self-test failures. And because `0x200` separates the three
severity levels, it can drive a banner and an overlay rather than only an overlay.

> **Not confirmed to be transmitting.** The export sets an ID, a channel and the extended
> flag, and unlike the TX frames there is no `Enable frame` parameter beside them — which
> hints that error broadcasting is always on. That is an inference from an absence, not
> evidence. **Check with `candump` on the real bus: look for extended `0x200`.** The
> format above is documented; whether the frames are actually being sent is a separate
> question and nobody has looked yet.

### DLC and bit numbering run in opposite directions — a trap for whoever edits the config

**DLC (Data Length Code)** is the field in a CAN frame header saying how many data bytes
it carries, 0 to 8. It is how a receiver knows a frame holds 3 bytes rather than 8.

Every frame in our config is DLC 8, and the export's own Instructions sheet calls that
*"poor practise"* where fewer bytes are used. It is tempting to tidy up. **Do not, without
reading this first.**

The manual (p. 60): *"the DLC counts from byte 0 (leftmost byte), but bits count from byte
7 (rightmost byte). Thus, for a DLC of 4 … only bits 32-63 are available."*

So reducing the DLC truncates from **byte 7 downwards**, while signals placed at **low bit
numbers live in exactly those bytes**. Low start bits are the first thing to disappear.

Concretely, for frame `0x102` — the one carrying both our temperatures:

| Signal | Bits | Byte | Survives DLC 7? | DLC 6? | DLC 4? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `CELL_T_MAX_VAL` | 7..0 | 7 | **no** | no | no |
| `CELL_T_MIN_VAL` | 23..16 | 5 | yes | yes | **no** |
| `PACK_Q_SOC_TRIMMED` | 63..48 | 0–1 | yes | yes | yes |

Any DLC below 8 silently loses the hottest-cell temperature — which drives `packTemp`, the
PACK readout and the ESS over-temperature warning. The SoC signals at the high bit numbers
would keep working perfectly, so the frame would look healthy while the safety-critical
part of it was gone.

**Second edge:** `src/SocketCanReader.cpp` discards any frame with `can_dlc < 8`. So we
would not even get partial data — the frame would vanish and the pack readouts would drop
to `--` with no error anywhere. Arguably the better failure mode, since it is at least
visible, but worth knowing it is what would happen.

**In short: leave every DLC at 8, or tell the dashboard side before changing one.**

### SoC is not working — what to check, in order

From the n-BMS manual, most likely cause first. The BMS computes SoC by **coulomb
counting**: it integrates measured pack current into a "remaining capacity" counter and
divides by expected full capacity (§3.3.2, p. 38). Almost everything below is a way that
sum can be wrong or never anchored.

**1. Compare Data ID 18 against Data ID 19 — this is the 30-second check.**

`PACK_Q_SOC_TRIMMED` (ID 19, the one we would display) is a *remapped and clamped*
version of `PACK_Q_SOC_INTERNAL` (ID 18), bounded by **Minimum SoC trim** and **Maximum
SoC trim** in the System Configuration view. **If Maximum SoC trim is 0, or Min equals
Max, ID 19 is pinned regardless of the real charge** while ID 18 underneath may be
perfectly healthy.

If 18 looks sane and 19 is stuck, that is the whole problem and it is one parameter.

**2. `Initial Capacity` (System Configuration, Ah).**

SoC is *remaining ÷ expected full capacity*, and this is the divisor — the manual calls
it "the reference point for the SoC estimation" (p. 38). There is **no** separate cell
capacity, cells-in-parallel or nominal capacity field; this single whole-pack figure is
the only capacity input. Zero or left at a default makes the division meaningless.

Cross-check without opening BMS Creator: read `PACK_Q_DESIGN` (ID 21) and `PACK_Q_FULL`
(ID 22) on CAN. If those are zero or wrong, this is confirmed.

**3. `Currrent source type` (System Configuration — spelled with three r's in the tool).**

`0` = none, `1` = HALL, `2` = Shunt, `3` = CAN sensor, and only one can be active. **At 0
no ampere-seconds are ever accumulated, so SoC never moves.** It must match what is
physically wired.

**4. A floating or mis-scaled current input.**

This is the failure the manual explicitly names. A floating input makes the counter
integrate noise until it runs to the ±300 % limit and raises
**`ERROR_SYS_PACK_SOC_CALC`, code 2036 (0x7F4)** — *"the ampere hour summation is much
too big … caused by having a floating current measurement input for a while"* (§8.2.2,
p. 98).

Read `PACK_I_MASTER` (16), `PACK_I_SHUNT` (15) and `PACK_I_HALL` (14) with the pack at
rest. They should sit near zero and be quiet. A standing offset with no current flowing
makes SoC drift continuously; there is a zero-current offset-trim procedure in §3.1.1,
p. 31. Shunt resistance accuracy directly affects SoC accuracy (§6.3.1, p. 79).

### The structural problem, and it is specific to solar cars

Coulomb counting drifts, so it has to be **anchored** periodically. The n-BMS has exactly
two anchors, and **we may have neither**:

- **End-of-charge calibration** (§3.7.5, pp. 53–54) resets the counter to full capacity —
  but it requires the BMS to be in **Charge mode** with cells reaching the target voltage
  inside the configured deadbands. **A solar array charging through MPPTs outside the BMS
  charge contactor may never produce a "charge complete" event**, so the reset never
  fires.
- **Power-up OCV calibration** (§3.3.3, p. 39) corrects from a rest-voltage lookup — but
  only if OCV datasets have been loaded (`Enable data sets` > 0 in the **SOC-OCV
  settings** view, §8.9 p. 158) *and* the pack has rested, more than 20 minutes (§8.7,
  p. 141). If nobody entered those datasets, it never runs.

With both unavailable the count free-runs indefinitely, and no amount of dashboard work
fixes that. **Worth raising with whoever owns the charging architecture**: either give
the BMS a charge path it can recognise as completing, or load the OCV datasets.

### There is no SoC validity flag

Confirmed absent from the whole Data ID map — no confidence value, no capacity-learning
state, no per-signal valid flag. The closest proxies:

- **`FLAGS_FULLY_CHARGED` (ID 47)** and **`FLAGS_FULLY_CHARGED_LATCHED` (ID 48)** tell you
  whether an end-of-charge calibration has *ever* happened. If the latched one has never
  set, the counter has never been anchored.
- Comparing ID 18 against ID 19 exposes a trim misconfiguration; comparing IDs 21/22
  against the true pack Ah exposes a capacity misconfiguration.

None of these are currently broadcast, so seeing any of them means adding them to a TX
frame during the config rebuild.
