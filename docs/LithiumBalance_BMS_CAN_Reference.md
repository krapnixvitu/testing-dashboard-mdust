# Lithium Balance n-BMS CAN Reference

Spec-of-record for the battery management system, the counterpart to
`WaveSculptor22_CAN_Protocol_Reference.md`. Written from the configuration export in
`CAN-Database-(DBC)-BMS.xlsx` in this folder, which is what the Lithium Balance tool
actually flashed onto the BMS.

Every frame and signal in the configuration is listed here, **including the ones the
dashboard deliberately does not decode**, so nobody has to re-parse a spreadsheet to find
out what is available.

Last read from the export: 2026-09-05.
Cross-checked against the n-BMS User Manual 2.3.1 on 2026-09-05; page citations below
refer to it.

---

## 1. Two things that differ from the WaveSculptor

Both fail silently if forgotten, which is why they lead.

**All BMS frames use 29-bit EXTENDED identifiers.** The motor controller uses standard
11-bit ones. In SocketCAN, `can_id` is not just the identifier — bit 31 (`CAN_EFF_FLAG`)
carries the frame format, so an extended `0x100` arrives as `0x80000100`. The kernel
filter needs its own entry for these, and `SocketCanReader` routes on that flag so the
two decoders can never be handed each other's frames.

**The payload is BIG endian (Motorola).** The WaveSculptor is little endian. The export
describes each signal by bit range across a 64-bit word with bit 63 the most significant
bit of byte 0:

```
bits 63..56 -> byte 0      bits 31..24 -> byte 4
bits 55..48 -> byte 1      bits 23..16 -> byte 5
bits 47..40 -> byte 2      bits 15.. 8 -> byte 6
bits 39..32 -> byte 3      bits  7.. 0 -> byte 7
```

> **Confirmed against the manual**, Figure 4.4 "Big endian bit order for all CAN frame
> bits" (p. 60), and again by Figure 5.1 (p. 76) which works the same example: start bit
> 48 gives bytes 0-1, start bit 32 gives bytes 2-3, start bit 16 gives bytes 4-5, start
> bit 0 gives bytes 6-7. Manual p. 59: *"the leftmost byte is denoted byte 0 ... bit 0
> being the right most bit, while bit 63 is the left-most bit."*
>
> General rule for a big-endian signal: physical bit *N* lives in byte `7 - floor(N/8)` at
> bit position `N mod 8`, counting 0 as the LSB. A field spans bits
> `start_bit ... start_bit + length - 1`, most significant first.
>
> One consequence worth knowing: **the DLC counts from byte 0 but bits count from byte 7**
> (p. 60), so a DLC of 4 exposes only bits 32-63.

## 2. Bus settings

| Setting | Value | Meaning |
| :--- | :--- | :--- |
| CAN speed S-CAN | 2 | **500 kbit/s** — matches the car's bus |
| CAN speed I-CAN | 2 | 500 kbit/s, second channel, not wired to the dashboard |
| CAN ID start error frames | 512 (`0x200`) | Extended, on S-CAN. See §5 |
| CAN ID error extended? | 1 | 29-bit |
| CAN ID Frame Charger | 32 | Extended, on S-CAN, charger type 0 (zeroed output) |

All five RX frames are **disabled**, so the BMS currently listens for nothing. The
dashboard only ever listens, so this does not affect us.

## 3. Enabled TX frames

Five frames, all on **S-CAN (channel 0)**, all **extended**, all **DLC 8**. The export
sets DLC 8 even where fewer bytes are used, which its own Instructions sheet flags as
poor practice.

Interval is `update interval x 100 ms`.

### `0x100` — cell voltages, every 1000 ms

| Bits | Bytes | Signal | Type | Scale | Unit | Decoded? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 63..48 | 0–1 | `CELL_V_MAX_VAL` — highest cell voltage | uint16 | 0.1 | mV | **yes** |
| 47..32 | 2–3 | `CELL_V_MIN_VAL` — lowest cell voltage | uint16 | 0.1 | mV | **yes** |
| 31..16 | 4–5 | `CELL_V_AVG` — average cell voltage | uint16 | 0.1 | mV | no |
| 15..0 | 6–7 | `PACK_V_SUM_OF_CELLS` — sum of all cells | uint16 | 0.1 | V | no |

### `0x101` — pack current, every 900 ms

| Bits | Bytes | Signal | Type | Scale | Unit | Decoded? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 63..32 | 0–3 | `PACK_I_SHUNT` — shunt current | int32 | 0.01 | mA | no |
| 31..0 | 4–7 | `PACK_I_MASTER` — selected source, the system reference current | int32 | 0.01 | mA | **yes** |

`PACK_I_MASTER` is the one to use: it is whichever source (shunt or hall) the BMS has
selected as authoritative. Signed, so charging reads negative.

### `0x102` — cell temperatures and state of charge, every 1100 ms

| Bits | Bytes | Signal | Type | Scale | Unit | Decoded? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 63..48 | 0–1 | `PACK_Q_SOC_TRIMMED` — state of charge | uint16 | 0.01 | % | no |
| 47..32 | 2–3 | `PACK_Q_SOC_INTERNAL` — state of charge (internal) | int16 | 0.01 | % | no |
| 31..24 | 4 | `CELL_V_MIN_ID_CELL` — which cell is lowest | uint8 | 1 | – | no |
| 23..16 | 5 | `CELL_T_MIN_VAL` — lowest cell temperature | int8 | 1 | °C | **yes** |
| 15..8 | 6 | `CELL_T_AVG` — average cell temperature | int8 | 1 | °C | no |
| 7..0 | 7 | `CELL_T_MAX_VAL` — highest cell temperature | int8 | 1 | °C | **yes** |

Temperatures are **signed**, so sub-zero readings survive decoding — which the
under-temperature rule needs.

### `0x103` — timekeeping, every 1200 ms · not decoded

`UPTIME_S` (bits 63..32) and `EPOCH_TIME_S` (bits 31..0), both uint32 seconds.

### `0x104` — timekeeping, every 1500 ms · not decoded

`TIME_BETWEEN_BOOTS_S` (bits 31..0), uint32 seconds.

## 4. Disabled TX frames

Configured but switched off, **and on I-CAN**, so they would not reach the dashboard even
if enabled. Listed so nobody goes looking for them on our bus.

- **`0x105`** — charger control: `CHARGER_OUTPUT_ENABLED`, `CHARGER_OUTPUT_VOLTAGE`
  (0.1 V), `CHARGER_OUTPUT_CURRENT` (0.1 A), `CHARGER_CAN_ACTIVE`, `CHARGER_PWM_ACTIVE`,
  `CHARGER_PWM_ACTIVE_DUTY` (%).
- **`0x106`** — three unnamed 16-bit slots.
- **`0x107`** — `AUX_T1` … `AUX_T8`, eight auxiliary temperatures, int8 °C.

## 5. Faults: the error frames, not the status signal

No **TX frame** in the configuration carries a fault, status or alarm signal - every
enabled frame is a measurement. But the BMS broadcasts errors through a separate,
always-on mechanism that is fully documented, so `bmsFault` is **not** blocked.

### Error frames (manual 5.9, pp. 74-75)

Configured by `CAN ID start error frames = 512` (`0x200`), extended, on S-CAN. Payload is
**big endian**, same convention as section 1. Call the start identifier `X`.

> **Not yet confirmed to be transmitting.** The export sets an identifier, a channel and
> the extended flag, and unlike the TX frames there is no `Enable frame` parameter to go
> with them — which suggests error broadcasting is always on. But "no enable flag was
> found in the export" is not the same as "it is enabled", and no traffic has been
> observed. **`candump` on the real bus settles it**: look for extended `0x200` at all.
> Everything below is the documented format, which is a separate question from whether
> the frames are actually being sent.

**`X` (`0x200`) - summary of active errors.** This is the one that matters:

| Byte | Meaning |
| :--- | :--- |
| 7 | count of active **CRITICAL** errors |
| 6 | count of active **NORMAL** errors |
| 5 | count of active **LOW** errors |
| 3-2 | count of **all** active errors |
| 4, 1, 0 | unused |

**`X+1` (`0x201`) - statistics.** Bytes 7-4: total errors since boot. Bytes 3-0 unused.

**`X+2` through `X+49` - one frame per currently-active error**, packed consecutively:

| Byte | Meaning |
| :--- | :--- |
| 7-6 | Lithium Balance internal verification value |
| 5-4 | Lithium Balance internal verification value |
| 3 | **severity** |
| 2 | Lithium Balance internal verification value |
| 1-0 | **error code**, 16-bit |

The CAN identifier is only a slot number, not the error code: with two active errors the
BMS sends `X`, `X+1`, `X+2` and `X+3`. Maximum 48 error frames; beyond that it raises
`ERROR_SYS_TOO_MANY_BROADCAST_ERRORS`.

The 200-identifier reservation in the configuration export is conservative headroom
advice; the firmware documents usage only through `X+49`.

**Error code list:** manual appendix 8.2.2, pp. 91-99, as `Dec | Hex | identifier |
explanation`. Severity codes are in 8.2.1, p. 90.

### Data ID 34 (`STATUS`) - the enumeration is genuinely absent

The n-BMS state machine (INIT / Boot / SLEEP / READY / ACTIVE / ERROR) is described in
section 3.4 and Figure 3.15 (pp. 43-44), and Data ID 34 is listed on p. 101 as
`STATUS | UINT8 | 1 | - | BMS state`. **The numeric value of each state is documented
nowhere in the manual** - checked against section 3.4, the Data ID map, 4.5.4, 3.6, the
firmware error appendix and the configuration appendix. A raw `STATUS` byte therefore
cannot be interpreted without determining the values empirically or asking the vendor.

**Prefer the error frames.** Byte 7 of frame `X` counts active critical errors: non-zero
means the BMS has a critical fault, and no enumeration is required.

Coarser boolean Data IDs exist if a state readout is ever wanted (pp. 100-101):
`35 CONTACTORS_ENABLED`, `43 CONTACTORS_EMERGENCY_OFF`, `49 FLAGS_LOAD_ACTIVE`,
`50 FLAGS_CHARGER_ACTIVE`, `51 FLAGS_PRECHARGE_ACTIVE`, `60 CRITICAL_SEVERITY_COUNT`.

## 5a. The safety limits the BMS itself enforces

The manual documents the thresholds the BMS checks before tripping contactors
(section 3.2, pp. 32-37; parameters in appendix 8.9, pp. 145-159; error codes 8.2.2,
p. 96):

| Quantity | BMS Creator parameter | Unit | Error code |
| :--- | :--- | :--- | :--- |
| Cell under-voltage | **Min. cell voltage** | mV | 2000 `ERROR_SYS_LIM_CELL_V_MIN` |
| Cell over-voltage | **Max. cell voltage** | mV | 2001 `ERROR_SYS_LIM_CELL_V_MAX` |
| Cell under-temperature | **Min. cell temperature** | degC | 2004 `ERROR_SYS_LIM_CELL_T_MIN` |
| Cell over-temperature | **Max. cell temperature** | degC | 2005 `ERROR_SYS_LIM_CELL_T_MAX` |
| Continuous charge current | **DCLI** table, 2-D over SoC x temperature | A | 2008 `ERROR_SYS_LIM_PACK_I_IN` |
| Continuous discharge current | **DCLO** table, same shape | A | 2009 `ERROR_SYS_LIM_PACK_I_OUT` |
| Peak-current integral | **Max. i2t** | A^2 s | 2010 `ERROR_SYS_LIM_PACK_I2T` |

These live in the **"Operational Limits"** view of BMS Creator, which is **not** part of
the `CAN Settings` export in this folder. The manual is explicit that they have **no
factory defaults** and must be set per chemistry (p. 32: *"safety thresholds must be
configured by the user"*).

> **This is where `src/BmsLimits.h` should get its numbers.** Taking them from the same
> configuration the BMS acts on means the dashboard warns on the thresholds the pack is
> actually protected by, rather than a second set transcribed from a datasheet that could
> drift out of agreement. **Export the Operational Limits view** to fill them in.

The BMS also publishes its *live* limits, which move with state of charge and
temperature: `32 DYN_LIM_I_IN` and `33 DYN_LIM_I_OUT` (uint16, 0.1 A) and
`31 DYN_LIM_I2T_REMAIN` (uint32, A^2 s). Showing headroom against those would be more
honest than a fixed current threshold, since the real limit is a 2-D table over SoC and
temperature rather than a constant.

## 6. What the dashboard decodes

Three frames, five signals — the minimum that covers what the race dashboard displays
plus the quantities the iESC ESS rules name as triggers. Decoded in `src/BmsDecoder.cpp`.

| Signal | Dashboard property | ESS role |
| :--- | :--- | :--- |
| `CELL_V_MAX_VAL` | `cellVoltageMax` | cell over-voltage |
| `CELL_V_MIN_VAL` | `cellVoltageMin` | cell under-voltage |
| both, as max − min | `packDeltaV` | cell spread readout |
| `PACK_I_MASTER` | `netCurrent` | over-current |
| `CELL_T_MAX_VAL` | `packTemp` | cell over-temperature |
| `CELL_T_MIN_VAL` | `packTempMin` | cell under-temperature |

Thresholds live in `src/BmsLimits.h` and are **unset** until the cell datasheet exists.

### Injecting a test frame

`vcan0` exercises the extended-ID filter, the routing and the big-endian decode with no
BMS and no CAN hardware. **Eight hex digits before the `#` make it an extended frame** —
with fewer, `cansend` emits a standard frame and the dashboard will correctly ignore it.

```bash
# CELL_V_MAX = 37000 counts (0x9088) -> 3.700 V
# CELL_V_MIN = 36500 counts (0x8E94) -> 3.650 V
cansend vcan0 00000100#90888E9400000000
```

Expect `PACK DELTA V` to read `0.050 V` and the BMS dot to leave grey. If the readouts
stay `--`, the kernel filter is wrong. If the numbers are wrong, the byte mapping in
section 1 is - though that is now confirmed against the manual, so suspect the filter
first.

## Where the truth lives

1. **`CAN-Database-(DBC)-BMS.xlsx`** in this folder — the configuration actually flashed
   onto the BMS. Authoritative for identifiers, bit positions and scaling.
2. **The Lithium Balance n-BMS User Manual, version 2.3.1** - authoritative for the Data
   ID map, bit ordering, the error-frame format and the error codes.

   **Deliberately not tracked in git.** It is a 7.4 MB third-party document, roughly
   seventeen times the size of everything else in this repository, and git would keep it
   forever even if deleted. Obtain it from Lithium Balance and put it at
   `docs/vendor/n-BMS_User_Manual_2_3_1.pdf`, which `.gitignore` covers.

   **Every page citation in this file refers to version 2.3.1 specifically.** A different
   revision will have different page numbers, so check the version before trusting a
   citation.
3. **This document** - a readable transcription of 1 and 2, accurate as of the dates
   above. Every claim is either copied from the export or cited to a manual page.
4. **`src/BmsDecoder.cpp`** — what the dashboard actually reads, unit-tested in
   `tests/test_bms_decoder.cpp`.

> The pack is being rebuilt, and the configuration will change with it. Re-read the export
> and update this file when it does.
