# Regulatory Compliance — driver's screen

What the competition rules require the driver's screen to show, and where the dashboard
currently stands against each item. Written so the audit survives: several of these are
deferred on purpose, and the reasons matter as much as the statuses.

**Source and its limits.** This tracks
`iLumen European Solar Challenge Dashboard Design Standards.md` at the repo root, which
is a **secondary summary of the 2024 regulations**, not the regulation text. iESC is
biennial, so the **official current-year regulations are the authority** and this file is
an index into them. Re-check every row against the current rulebook before scrutineering.

Last reviewed: 2026-09-05.

---

## §1 Mandatory display elements (Reg. 2.26.1)

Must be provided to the driver **at all times while driving**.

| # | Requirement | Status |
| :--- | :--- | :--- |
| 1 | Vehicle speed | **Done** |
| 2 | Direction indicator verification | **UI done, no live source** |
| 3 | Hazard lights verification | **UI done, no live source** |
| 4 | ESS warnings | **Sources decoded; thresholds pending datasheet — see §3** |
| 5 | Electronic rear-vision feed | **Out of scope — decision recorded below** |

### 1. Vehicle speed — done

`SpeedGauge.qml` renders it as the hero element from `backend.vehicleSpeed`, decoded from
the WaveSculptor velocity frame `0x403`. Real source, decoded, tested.

### Occlusion — found and fixed 2026-09-08

Applies to items 1, 2 and 3 together, so it is recorded once here rather than three times.

**The alert UI used to hide the mandatory displays at the worst moment.**

- The warning banner was a top strip spanning y `0-68` at the 800x480 reference. The
  blinker arrows span `26-60` and the hazard triangle `21-65`. It covered both
  **entirely** — not partially — so while any warning was up, items 2 and 3 were not
  displayed.
- `CriticalOverlay.qml` was `anchors.fill: parent`, opaque, at any speed. During a
  critical fault items 1, 2 and 3 all disappeared at once.

**Fixed by moving alerts into non-content space.** The banner is now bottom-anchored over
the footer (device dots and odometer — our diagnostics, not regulated content), and the
alert colour flashes in the background between the cards. The full-screen takeover is
gated on `backend.vehicleStopped`, a C++ property with 5/6 km/h hysteresis, so it can only
appear once the car has stopped. Verified against the simulator drive cycle: the takeover
appears only during the ~10 s idle phase of each 60 s cycle.

> **This reading is an inference, and worth confirming.** The standards file lists what
> must be *displayed*; it does not explicitly say those elements may never be obscured.
> That a mandatory display has to be available while driving is our interpretation. Per
> CLAUDE.md that file is a secondary summary of the 2024 rules, so check the current-year
> regulation before treating the occlusion requirement as settled. The change is an
> improvement either way.

### 2. Direction indicator verification — UI done, no live source

`ArrowIndicator.qml`, placed top-left and top-right of the centre card, bound to
`backend.leftBlinker` / `rightBlinker`. **No longer covered by an active alert** — see the
occlusion note above.

**The gap is the source.** Nothing decodes a blinker message — `ws22::decode()` handles
motor-controller frames only, and while `kDriverControlsBase` (`0x500`) is declared in
`src/WaveSculptorDecoder.h`, no message from that range is parsed. The only writer today
is `VehicleSimulator::tickBlinkers()`. **On a live bus the arrows never light.** Same
shape of gap as gear, and blocked the same way.

> **Blocked on:** the team member responsible for the car's lights, who has not yet
> confirmed a message layout. Nothing to build until that lands.

**Decide with them:** does the source send *actual lamp state* (dashboard mirrors the real
flashing) or *"indicator requested"* (dashboard generates its own rhythm)? The regulation
says **verification**, which argues for mirroring the lamp — a locally generated flash
would blink happily while the bulb is dead, which is the exact failure the rule exists to
catch.

**Flash rate**, when a real source exists: the regulation requires 90 ± 30 flashes/min,
i.e. **60–120**. The simulator targets the middle — `kBlinkerFlashesPerMinute = 90` in
`src/VehicleSimulator.cpp`, a 333 ms toggle. When a real blinker source is decoded, keep
the displayed rate at 90/min rather than mirroring whatever the lamp hardware happens to
do, unless the lamp itself is already within 60–120.

### 3. Hazard lights verification — UI done, no live source

Added 2026-09-03. `HazardIndicator.qml` renders a red triangle centred between the two
arrows and level with them, bound to `backend.hazardActive`.

**Semantics chosen:** `hazardActive` means *hazard mode is engaged*, and the triangle is
**steady**. The flashing verification the regulation asks for is carried by the two arrows
flashing **together** — which is literally what Reg. 2.26.1 asks to verify. The triangle's
job is to distinguish hazard from a turn signal. `VehicleSimulator::tickBlinkers()`
overrides the turn cycle and drives both arrows in sync while hazard is engaged.

`VehicleData::setHazardActive()` **rejects writes unless the backend is simulator-fed**,
mirroring the gear rule: announcing that lamps are flashing when nobody has measured them
is exactly the failure this project is designed against. `H` toggles it in development. A
real source will write through the CAN ingest path, as gear will.

> **Blocked on:** the same lights owner as item 2.

### 5. Electronic rear-vision feed — out of scope

**Decision, 2026-09-03: not implemented, and not planned.** Rear-vision is not the focus
of this dashboard. The requirement is conditional in the regulations — it applies only if
a camera feed is used instead of, or alongside, mirrors.

Recorded here so it is not re-opened every time someone reads the rulebook. **If the car
later adopts a camera**, this becomes a large piece of work with its own constraints
(§2 below) and would reshape the layout entirely.

---

## §2 Rear-vision screen specifications (Reg. 2.18)

**Not applicable** while §1.5 stays out of scope. Retained so the constraints are on
record if that decision reverses:

- Continuous operation whenever the car is moving under its own power or about to be
  driven.
- **Mirroring orientation** — objects on the right of the car must appear on the right of
  the image.
- Coverage of the ground area defined by UNECE Regulation 46, viewable while belted in.

---

## §3 ESS warnings (Reg. 2.5 & 3.5) — sources decoded, thresholds pending

**Status: every trigger quantity now has a real source. The limits do not.**

Updated 2026-09-05, when the Lithium Balance n-BMS was decoded. Protocol detail lives in
`docs/LithiumBalance_BMS_CAN_Reference.md`.

| Regulation trigger | Source | Threshold |
| :--- | :--- | :--- |
| Cell voltage below minimum | `CELL_V_MIN_VAL` (`0x100`) | **unset** |
| Cell voltage above maximum | `CELL_V_MAX_VAL` (`0x100`) | **unset** |
| Charge/discharge current above maximum | `PACK_I_MASTER` (`0x101`) | **unset** |
| Cell temperature above maximum | `CELL_T_MAX_VAL` (`0x102`) | **unset** |
| Cell temperature below minimum | `CELL_T_MIN_VAL` (`0x102`) | **unset** |

The gap flagged in the previous review — that every temperature threshold in the codebase
was one-sided, so cell under-temperature had nowhere to go — is closed at the backend:
`packTempMin` is decoded, signed, and has its own warning bit.

### The thresholds are deliberately unset

`src/BmsLimits.h` holds all nine limits and every one is `NaN`. Comparisons against NaN
are false, so **no ESS alert can fire yet**. That is the intended state, not an oversight:
the safe window depends on cell chemistry (LiFePO4 tops out near 3.65 V, NMC near 4.2 V),
the pack is being rebuilt, and a plausible-looking wrong limit is worse than none. The
`essLimitsConfigured` property exposes the state so an unconfigured dashboard cannot be
mistaken for one that is watching.

**To finish this item:** enter the figures from the cell datasheet into `BmsLimits.h`.
Nothing else needs to change.

### Severity mapping

Split on whether the driver can recover the condition by acting immediately.

| Trigger | Layer | Reasoning |
| :--- | :--- | :--- |
| Cell over-temperature | warning → critical | Thermal mass is slow, so the warning tier is what actually buys time to reduce current; by the critical limit the heating is committed and the driver must stop. |
| Cell over-voltage | warning → critical | Plating and internal shorting, driven by regen or solar charging. The warning says ease regen; critical means power flow must stop. |
| Cell under-voltage | warning → critical | Sag under acceleration is recoverable — the banner says lift off, before the BMS trips contactors. |
| Over-current | warning → critical | Spikes on overtakes and climbs. Feedback to reduce draw before the BMS I²t timer expires. |
| Cell under-temperature | warning only | Cold cells mean higher resistance and worse performance, not an immediate hazard. |

Computed in `VehicleData::recomputeEssFlags()` as the `essFlags` bitfield and masked in
`RaceDashboard.qml`, so the thresholds have one home in C++ rather than being duplicated
across the two dashboards.

### `bmsFault` still has no source

**The BMS configuration broadcasts no fault, status, alarm or error signal at all** —
every enabled and disabled frame carries measurements only. So `bmsFault`, which drives
the full-screen `BMS FAULT` overlay, is permanently false.

> **Action for the pack rebuild:** enable a TX frame carrying **Data ID 34 (`STATUS`)**,
> the n-BMS state machine (INIT / READY / ACTIVE / ERROR / SLEEP). `ERROR` means the BMS
> has already forced the contactors open — its own verdict, which beats the dashboard
> inferring a fault from thresholds. It also gives the footer BMS dot a real meaning.
>
> Blocked twice over: it is not enabled in the current configuration, and Lithium Balance
> omit the numeric enumeration from the manual, so which uint8 value means `ERROR` is
> unknown. See `docs/LithiumBalance_BMS_CAN_Reference.md` §5.

The alternative is the error-frame range at `0x200`–`0x2C7`, which already reaches our
bus but whose payload layout is undocumented.

**Resolved:** `_criticalBmsFault` in `RaceDashboard.qml` is now gated on `bmsValid`, which
matters since `bmsValid` reflects a real 3 s staleness timer rather than just simulator
mode.

### Not the dashboard's job

**Fail-safe isolation.** The regulation requires critical faults to automatically drive an
electrical safe state isolating the main battery. That is **BMS/BPS hardware**. The
dashboard is display-only and must never sit between a fault and the contactor. Stated
explicitly so nobody assumes the screen covers it.

---

## §4 Power and electrical architecture (Reg. 2.26.2 & 2.30)

**Constraint on the hardware, not the software** — but it constrains a decision that is
currently open, so it is recorded here and in `docs/display-hardware.md`.

- The display and instrumentation **must be powered from the main energy storage system**,
  not from a separate isolated battery. Bus voltage is far above either candidate panel's
  input range, so a DC-DC converter is required regardless of which panel is chosen. The
  5-inch panel's USB-C input is a **bench convenience only** — a power bank is not a legal
  supply in the car.
- Mandatory systems (emergency hazard lights, the external safe-to-touch green indicator)
  are backed by a **separate auxiliary battery** — min 10 Wh, max 48 V, at least 60
  minutes during a main-battery cut-off.

> **Open question for the electrical team.** These two rules interact badly for us: the
> dashboard runs off the main pack, but hazards run off aux. **So when the main battery is
> isolated, the screen dies while the hazards keep flashing.** The on-screen hazard
> verification is therefore unavailable in precisely the scenario where hazards matter
> most. This may mean hazard verification cannot live on the dashboard alone. Flagged, not
> solved — it is an architecture question, not a QML one.

---

## Elements removed on purpose

Recorded so nobody re-adds them believing a requirement was missed. **None of these is
mandatory** under Reg. 2.26.1, which requires only speed, direction-indicator
verification, hazard verification, ESS warnings and (conditionally) rear-vision.

| Removed 2026-09-07 | Why |
| :--- | :--- |
| Controller temperature readout | The driver's response to a hot controller is identical to a hot motor — back off — and the `HEATSINK TEMP WARNING` banner already says so. The controller also self-limits before damage. **The banner was kept.** |
| Pack ΔV (cell spread) | Satisfies none of the four ESS triggers. Drifts over hours and no driving input changes it. Still decoded and telemetered. |
| Pack current readout | Duplicated the POWER figure above it, which already shows regeneration in blue. **The ESS over-current warning was kept** — it uses the same value from the C++ side. |
| Motor controller limit summary | Controller limits are race-strategy information for the pits. The driver cannot act on them and should be watching the road. |

The principle: race engineers own car health, the driver owns the laps. Anything the
engineers need travels over telemetry rather than competing for the driver's attention.
**Warnings survived their readouts** in every case — what was removed is the number to
watch, not the alert that demands action.

---

## §5 Control and state indicators (Reg. 2.27)

**Not applicable today.** The dashboard integrates no cruise control and no autonomous
functions. If either is ever fitted:

- Cruise control status must be reflected in the UI, and must disengage automatically on
  brake application or vehicle shutdown.
- Any automatic function must show its active state and disengage immediately on manual
  input.

The existing D/N/R gear readout is a state indicator and is already handled correctly:
gear is owned by CAN and the dashboard only displays it, with all three letters dimmed
when nothing is reported.

---

## Known inconsistency

`setHazardActive()` is guarded on simulator mode; `setLeftBlinker()` and
`setRightBlinker()` are **not**. Harmless today because no keyboard or QML path writes the
blinkers — the simulator is their only writer — but the two should match once a real
blinker source exists, and the guard is the correct side to converge on.

## Where the truth lives

1. **The official current-year iESC regulations** — authoritative, and not in this repo.
2. **`iLumen European Solar Challenge Dashboard Design Standards.md`** — the 2024 summary
   this file tracks. Convenient, secondary, possibly out of date.
3. **This file** — status of our implementation against that summary, accurate as of the
   review date at the top.
