# Regulatory Compliance — driver's screen

What the BWSC 2027 regulations require of the driver's screen, and where the dashboard
currently stands against each item. Written so the audit survives: several items are
deferred on purpose, and the reasons matter as much as the statuses.

**Source.** The 2027 Bridgestone World Solar Challenge Event Regulations V1.0
(7 May 2026), indexed in `docs/reference/BWSC2027_Regulations_Reference.md` with page
numbers. The organiser amends them through **Regulation Bulletins** and **Team Notices**,
which win over the PDF — re-check every row against them before scrutineering.

Last reviewed: 2026-11-13.

---

## §1 Mandatory display elements (Reg. 2.25.1, p. 42)

> The following information must always be visible to the driver (i.e., not behind
> menus) while the competition vehicle is in motion.

| # | Requirement | Status |
| :--- | :--- | :--- |
| 1 | Speed of the vehicle | **Done** |
| 2 | Whether the direction indicators are operating | **UI done, no live source** |
| 3 | Whether the hazard lights are operating | **UI done, no live source** |
| 4 | Energy storage system warnings | **Sources decoded; cannot fire — limits unset (§2)** |
| 5 | Electronic rear vision images (if fitted) | **Not applicable — mirrors (§4)** |

Nothing else on the screen is mandatory. Power, efficiency, battery, temperatures, gear,
the pedal bar, the footer dots and the odometer are our choices.

### 1. Speed — done

`SpeedGauge.qml` renders it as the hero element from `backend.vehicleSpeed`, decoded from
the WaveSculptor velocity frame `0x403`. Real source, decoded, tested.

### "Always visible, not behind menus" — occlusion fixed, one gap open

**Fixed 2026-09-08, and now explicitly required.** The alert UI used to hide the mandatory
displays at the worst moment:

- The warning banner was a top strip spanning y `0-68` at the 800x480 reference. The
  blinker arrows span `26-60` and the hazard triangle `21-65`, so while any warning was up
  items 2 and 3 were not displayed at all.
- `CriticalOverlay.qml` was `anchors.fill: parent`, opaque, at any speed, hiding items 1–3
  together.

The banner now sits at the bottom over the footer (our diagnostics, not regulated
content), and the full-screen takeover is gated on `backend.vehicleStopped` (C++, 5/6 km/h
hysteresis). That gate is legal because 2.25.1 applies **"while … in motion"**.

When this was first fixed it rested on our own reading of the old rules. BWSC's
"always visible … not behind menus" states it outright, so the fix is now a requirement.

> **Open gap: Debug mode.** `DebugDashboard.qml` has **no blinker arrows and no hazard
> triangle**. Switching to it while moving hides items 2 and 3 — a mode the driver has to
> switch out of is exactly "behind menus". Today only the `D` key reaches it, and the car
> has no keyboard, but the roadmap's planned physical mode button would put it in the
> driver's hand. **Debug mode must be retired, or made unreachable while moving, before
> any in-car mode input exists.** Tracked in `docs/roadmap.md`.

### 2. Direction indicators operating — UI done, no live source

`ArrowIndicator.qml`, top-left and top-right of the centre card, bound to
`backend.leftBlinker` / `rightBlinker`.

**The gap is the source.** Nothing decodes a blinker message — `ws22::decode()` handles
motor-controller frames only, and while `kDriverControlsBase` (`0x500`) is declared in
`src/WaveSculptorDecoder.h`, no message in that range is parsed. The only writer today is
`VehicleSimulator::tickBlinkers()`. **On a live bus the arrows never light**, which fails
2.25.1. This is the largest compliance gap in the project.

> **Blocked on:** the lights owner confirming a message layout.

**What the source has to say.** 2.25.1 asks only *whether the indicators are operating*,
so an **"indicator requested"** signal is enough to pass. Mirroring actual lamp state is
still better if the lights owner can provide it — a locally generated flash blinks
happily while a lamp is dead — but it is not required, so do not let it hold the message
up. Reg. 2.23.1 requires front, side and rear indicators on each side, so also agree
whether the message carries one bit per side or one per lamp.

**Flash rate.** Reg. 2.23.11: 90 ± 30 flashes/min, i.e. **60–120**. The simulator targets
the middle — `kBlinkerFlashesPerMinute = 90` in `src/VehicleSimulator.cpp`, a 333 ms
toggle. With a real source, keep the displayed rate at 90/min unless the lamps themselves
are already inside 60–120.

### 3. Hazard lights operating — UI done, no live source

`HazardIndicator.qml` renders a red triangle centred between the arrows, bound to
`backend.hazardActive`.

**Semantics.** Reg. 2.23.12 defines the hazard signal as the left and right indicators
flashing **simultaneously** — there is no separate hazard lamp. So the triangle is
**steady** and only says "this is hazard, not a turn"; the flashing is carried by the two
arrows flashing together. `VehicleSimulator::tickBlinkers()` drives both in sync while
hazard is engaged.

`VehicleData::setHazardActive()` **rejects writes unless the backend is simulator-fed**,
the same rule as gear: announcing that lamps are flashing when nobody has measured them is
the failure this project is designed against. `H` toggles it in development only.

> **Blocked on:** the same lights owner as item 2.

---

## §2 ESS warnings — content (Reg. 2.5.5–2.5.6, p. 24)

2.25.1 requires "energy storage system warnings" without defining them. The content comes
from 2.5.5/2.5.6: cells must never be operated outside the manufacturer's limits, and teams
must supply these seven:

| Manufacturer limit | Our source | `BmsLimits.h` today |
| :--- | :--- | :--- |
| Minimum operating cell voltage | `CELL_V_MIN_VAL` (`0x100`) | unset |
| Maximum operating cell voltage | `CELL_V_MAX_VAL` (`0x100`) | unset |
| Maximum discharge current | `PACK_I_MASTER` (`0x101`), discharge sign | unset — one shared limit |
| Maximum charge current | `PACK_I_MASTER` (`0x101`), charge sign | unset — one shared limit |
| Maximum temperature while discharging | `CELL_T_MAX_VAL` (`0x102`) | unset — one shared limit |
| Maximum temperature while charging | `CELL_T_MAX_VAL` (`0x102`) | unset — one shared limit |
| Minimum temperature while charging | `CELL_T_MIN_VAL` (`0x102`) | unset |

**Every quantity has a real source.** What does not fit is `BmsLimits.h`: it has one
current limit and one over-temperature limit, where the rules split both by direction of
current flow (the charge-side temperature ceiling is usually the lower one). The sign of
`PACK_I_MASTER` tells us which direction applies, so the restructure is all in
`BmsLimits.h` and `VehicleData::recomputeEssFlags()`. Tracked in the roadmap.

### Where the numbers come from

**The BMS's own Operational Limits** — the view in BMS Creator holding the thresholds the
pack is actually protected by (`docs/reference/LithiumBalance_BMS_CAN_Reference.md` §5a).
Taking the dashboard's limits from the same configuration the BMS acts on keeps the
warning and the protection in agreement by construction. That view is not in the export
we have, so **exporting it is what unblocks this item.**

Those BMS limits must in turn sit **inside the manufacturer's datasheet figures** — that is
the regulation (2.5.5), and it is the BMS configurer's and certifying engineer's duty, not
the dashboard's. Reg. 2.5.3: only manufacturer-endorsed specifications count.

### The thresholds are deliberately unset

`src/BmsLimits.h` holds every limit as `NaN`. Comparisons against NaN are false, so **no
ESS alert can fire yet**. That is the intended state: a plausible-looking wrong limit is
worse than none. `essLimitsConfigured` exposes it so an unconfigured dashboard cannot be
mistaken for one that is watching. **Until it is filled in, item 4 of §1 is not met.**

### Severity mapping

Split on whether the driver can recover the condition by acting immediately.

| Trigger | Layer | Reasoning |
| :--- | :--- | :--- |
| Cell over-temperature | warning → critical | Thermal mass is slow, so the warning tier is what buys time to reduce current; by the critical limit the driver must stop. |
| Cell over-voltage | warning → critical | Driven by regen or solar charging. The warning says ease regen; critical means power flow must stop. |
| Cell under-voltage | warning → critical | Sag under acceleration is recoverable — the banner says lift off, before the BMS trips contactors. |
| Over-current | warning → critical | Spikes on overtakes and climbs. Feedback to reduce draw before the BMS i²t timer expires. |
| Cell under-temperature | warning only | Higher resistance and worse performance, not an immediate hazard. |

When the limits are split by direction, the charge-side rows (charge current,
charge-temperature max/min) slot into the same layers: warn first, critical at the limit.

Computed in `VehicleData::recomputeEssFlags()` as the `essFlags` bitfield and masked in
`RaceDashboard.qml`.

### `bmsFault` still has no source

**The BMS configuration broadcasts no fault, status, alarm or error signal** — every
enabled frame carries measurements only. So `bmsFault`, which drives the full-screen
`BMS FAULT` overlay, is permanently false. Two routes, both recorded in
`docs/reference/LithiumBalance_BMS_CAN_Reference.md` §5: enable **Data ID 34 (`STATUS`)**
in a TX frame during the pack rebuild, or decode the **`0x200` error frames** (not yet
confirmed to be transmitting — check with `candump`).

`_criticalBmsFault` in `RaceDashboard.qml` is gated on `bmsValid`, which reflects a real
3 s staleness timer.

### Not the dashboard's job

Reg. 2.5.5 requires the vehicle to **automatically** prevent cells leaving their limits,
endorsed by the certifying engineer. That is the **BMS** acting on the contactors. The
dashboard is display-only and must never sit between a fault and a contactor. Say so
explicitly in the Electrical System Specification.

---

## §3 Power and safe state (Reg. 2.25.2, 2.28, 1.29.1)

**Constraints on the hardware, not the software.** Requirements are collected in
`docs/hardware/wiring.md`.

- **2.25.2** — the instrumentation must be powered **from the energy storage system, not
  from separate batteries.** Neither panel can take pack voltage, so a converter sits in
  between. The 5″ panel's USB-C input is a bench convenience only.
- **2.28.1** — in safe state the packs are isolated and no current flows in any loop
  outside them. So **the screen loses power, without warning, every time safe state is
  invoked** — by the driver, by a first responder at the exterior button, or by any
  failure in the fail-safe activation path (2.28.3, 2.28.5, 2.28.6).
- **1.29.1** — the safe-state diagram due with Group B must show how the low-voltage bus
  outside the packs is de-energised. The dashboard's supply hangs off that bus, so it
  appears on a document a scrutineer reads.

**This is consistent, not a conflict.** BWSC has no auxiliary-battery requirement, so in
safe state the hazards and the screen are both unpowered, and 2.25.1 only applies while
the car is in motion. The one function the rules require to survive safe state is voice
radio (3.8.2), which a driver-carried handheld satisfies (exempt under 2.5.8) — nothing
for the Pi.

**Two consequences for the Pi**, both on the roadmap:

1. **Repeated hard power-off will corrupt the SD card.** A read-only root filesystem
   (overlayfs) is the fix.
2. **The dashboard must be up before the car can move.** After leaving safe state the Pi
   boots from cold. If the car can be driven before the first frame is on screen, speed
   and indicators are not displayed while in motion. Measure boot-to-display and keep it
   inside the car's own power-up sequence.

---

## §4 Rear vision (Reg. 2.17) — not applicable

**Decision, 2026-09-03, still standing: not implemented, not planned.** 2.17.2 allows
mirrors, electronics or both, and 2.25.1's rear-vision item is conditional ("if fitted").
With mirrors, this dashboard has no rear-vision obligation.

**If the car ever adopts a camera**, 2.25.1 puts the feed on the always-visible screen —
it cannot be a page the driver switches to — and 2.17.2 requires an upright image with
objects on the right of the car on the right of the image. That would reshape the layout
entirely.

---

## §5 Automatic functions (Reg. 2.26) — not applicable

No cruise control and no automatic driving are fitted. If either is: cruise must
deactivate on brake or shutdown and never resume on its own; automatic driving must
deactivate on any manual input. **BWSC does not require a cruise status display**, though
showing one would be sensible.

The D/N/R readout is handled correctly: gear is owned by CAN, the dashboard only displays
it, and all three letters dim when nothing is reported.

---

## Elements removed on purpose

Recorded so nobody re-adds them believing a requirement was missed. **None is mandatory**
under Reg. 2.25.1.

| Removed 2026-09-07 | Why |
| :--- | :--- |
| Controller temperature readout | The driver's response to a hot controller is identical to a hot motor — back off — and the `HEATSINK TEMP WARNING` banner already says so. The controller also self-limits. **The banner was kept.** |
| Pack ΔV (cell spread) | Not one of the ESS limits. Drifts over hours and no driving input changes it. Still decoded and telemetered. |
| Pack current readout | Duplicated the POWER figure, which already shows regeneration in blue. **The ESS over-current warning was kept.** |
| Motor controller limit summary | Race-strategy information for the chase car. The driver cannot act on it. |

The principle: the engineers own car health, the driver owns the road. Anything the
engineers need travels over telemetry rather than competing for the driver's attention.
**Warnings survived their readouts** in every case.

---

## Known inconsistency

`setHazardActive()` is guarded on simulator mode; `setLeftBlinker()` and
`setRightBlinker()` are **not**. Harmless today because the simulator is the blinkers'
only writer, but the two should match once a real source exists, and the guard is the
side to converge on.

## Where the truth lives

1. **The BWSC 2027 regulations PDF**, in `docs/vendor/bwsc2027/` (untracked; download
   location in the reference doc), **plus any Regulation Bulletins and Team Notices** —
   authoritative.
2. **`docs/reference/BWSC2027_Regulations_Reference.md`** — dashboard-scoped index into
   the PDF, with page numbers.
3. **This file** — our status against those rules, accurate as of the review date at the
   top.
