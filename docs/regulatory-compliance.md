# Regulatory Compliance — driver's screen

What the competition rules require the driver's screen to show, and where the dashboard
currently stands against each item. Written so the audit survives: several of these are
deferred on purpose, and the reasons matter as much as the statuses.

**Source and its limits.** This tracks
`iLumen European Solar Challenge Dashboard Design Standards.md` at the repo root, which
is a **secondary summary of the 2024 regulations**, not the regulation text. iESC is
biennial, so the **official current-year regulations are the authority** and this file is
an index into them. Re-check every row against the current rulebook before scrutineering.

Last reviewed: 2026-09-03.

---

## §1 Mandatory display elements (Reg. 2.26.1)

Must be provided to the driver **at all times while driving**.

| # | Requirement | Status |
| :--- | :--- | :--- |
| 1 | Vehicle speed | **Done** |
| 2 | Direction indicator verification | **UI done, no live source** |
| 3 | Hazard lights verification | **UI done, no live source** |
| 4 | ESS warnings | **Deferred — see §3** |
| 5 | Electronic rear-vision feed | **Out of scope — decision recorded below** |

### 1. Vehicle speed — done

`SpeedGauge.qml` renders it as the hero element from `backend.vehicleSpeed`, decoded from
the WaveSculptor velocity frame `0x403`. Real source, decoded, tested.

### 2. Direction indicator verification — UI done, no live source

`ArrowIndicator.qml`, placed top-left and top-right of the centre card, bound to
`backend.leftBlinker` / `rightBlinker`.

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

## §3 ESS warnings (Reg. 2.5 & 3.5) — deferred deliberately

**Status: mechanism exists, inert, and under-modelled.** Deferred until a BMS is chosen,
because there is nothing to bind to until then. This is a scheduling decision, not an
oversight — the intent is to implement the BMS side and the dashboard side together once
its message codes are known.

**What exists.** `RaceDashboard.qml` maps `backend.bmsFault` to a full-screen
`CriticalOverlay` reading `BMS FAULT`. The overlay mechanism itself works and is exercised
by the `C` key.

**What is missing.** The regulation lists **four** trigger conditions. The backend models
**one opaque boolean**:

| Regulation trigger | Modelled? |
| :--- | :--- |
| Cell voltage below minimum | **No** |
| Cell voltage above maximum | **No** |
| Charge/discharge current above maximum | **No** |
| Cell temperature above maximum | Partly — `packTemp`, amber 45 °C / red 60 °C |
| Cell temperature below minimum | **No** |

Two things worth carrying forward:

- **Every temperature threshold in this codebase is one-sided (high only).** There is no
  low-temperature warning anywhere. Cell under-temperature is an explicit regulation
  trigger, so this is a real gap and not merely a missing constant.
- `packDeltaV` measures cell *spread*, which is useful but is **not** an absolute
  per-cell limit breach. It does not satisfy any of the four triggers.

> **Action when selecting the BMS:** require that it reports these conditions
> **individually**. A device exposing only a summary fault bit permanently caps what the
> dashboard can ever warn about, and that limitation would be inherited for the life of
> the car.

**Also tighten when a source lands:** `_criticalBmsFault` in `RaceDashboard.qml` is *not*
gated on `bmsValid`, unlike every other BMS-derived value. It is inert today only because
`m_bmsFault` defaults to false, so it is not currently wrong — but it is inconsistent with
the surrounding pattern.

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
