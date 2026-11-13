# BWSC 2027 Regulations — dashboard-relevant extract

An index into the **2027 Bridgestone World Solar Challenge Event Regulations, V1.0,
published 7 May 2026** (`docs/vendor/bwsc2027/2027-BWSC-Event-Regulations-V1.0-Published-07052026.pdf`,
72 pages), covering only what touches this project: the driver's screen, its physical
installation, its power supply, and the paperwork that has to describe it.

**This is a navigation aid, not the authority.** The PDF is. Where this file paraphrases,
the regulation number and page are given so the original can be read in seconds. V1.0 is
the first release of a biennial rulebook and will be amended by **Regulation Bulletins**
and **Team Notices** during 2026–27 — re-check anything load-bearing before scrutineering.

Extracted 2026-10-01. Companion document: `2027-Solar-Wombat-incl-drawing.pdf`, summarised
in §7.

The PDFs are deliberately **not tracked in git** (`docs/vendor/` is ignored). The
regulations are public: <https://www.worldsolarchallenge.org/the-challenge/regulations>.
The Solar Wombat document comes from the BWSC team portal.

---

## Contents

1. [The one regulation that governs the screen — 2.25](#1-the-one-regulation-that-governs-the-screen--225)
2. [What the warnings have to warn about — 2.5](#2-what-the-warnings-have-to-warn-about--25)
3. [Indicators and hazards — what "operating" means — 2.23](#3-indicators-and-hazards--what-operating-means--223)
4. [Rear vision — 2.17](#4-rear-vision--217)
5. [Physical installation — vision, occupant cell, electrical safety](#5-physical-installation--vision-occupant-cell-electrical-safety)
6. [Power, safe state, and the Pi — 2.25.2, 2.27, 2.28](#6-power-safe-state-and-the-pi--2252-227-228)
7. [Scrutineering and compulsory documentation — 1.29, 3.11–3.15](#7-scrutineering-and-compulsory-documentation--129-311315)
8. [Operating environment the dashboard has to survive](#8-operating-environment-the-dashboard-has-to-survive)
9. [Sections confirmed irrelevant](#9-sections-confirmed-irrelevant)
10. [Dates that constrain this project](#10-dates-that-constrain-this-project)
11. [Where the truth lives](#11-where-the-truth-lives)

---

## 1 The one regulation that governs the screen — 2.25

**Reg. 2.25 "Instrumentation", p. 42.** Two clauses, and they are the entire mandate. Short
enough to carry verbatim:

> **2.25.1** The following information must always be visible to the driver (i.e., not
> behind menus) while the competition vehicle is in motion:
> - the speed of the competition vehicle
> - whether the direction indicators are operating
> - whether the hazard lights are operating
> - energy storage system warnings
> - electronic rear vision images (if fitted).
>
> **2.25.2** This instrumentation must be powered from the energy storage system, and not
> from separate batteries.

That is the whole of it. Everything else in this document is a constraint that arrives from
somewhere other than 2.25 — the ESS rules that define what a warning is, the lighting rules
that define what "operating" means, the vision rules that constrain where the panel can be
mounted, and the safe-state rules that cut its power.

### The three phrases that do work

**"always visible … not behind menus."** The parenthetical is explicit: no tab, no page, no mode switch, no overlay may be the only
route to a mandatory item. The five items share one screen, permanently.

**This makes the 2026-09-08 occlusion fix a requirement.** Moving the warning banner to
the footer and gating `CriticalOverlay` on `backend.vehicleStopped` is what keeps the five
items visible while an alert is up. **Debug mode does not comply**: it has no blinker arrows
or hazard triangle, so it must not be reachable while moving — see
`docs/regulatory-compliance.md`.

**"while the competition vehicle is in motion."** The obligation is scoped to motion. A
full-screen takeover while stopped is therefore permitted, which is exactly what the
`vehicleStopped` gate (5/6 km/h hysteresis) already implements. Keep that gate: it is the
thing that makes the critical overlay legal.

**"whether … are operating."** See §3 — "operating" is a low bar, and that matters.

### Nothing else is mandatory

Everything else on our screen — power, efficiency, battery bar, temperatures, gear, pedal
bar, odometer, device dots, BMS status — is **our choice**, justified by race priorities and
removable without regulatory consequence. The "Elements removed on purpose" table in
`docs/regulatory-compliance.md` records why each removed readout was safe to remove.

### A COTS phone or tablet as the display — Reg. 2.5.9, p. 25

Not our architecture (Pi 4 + HDMI panel), but the clause is worth knowing because it shows
how the organiser thinks about driver displays, and because it would bite if anyone proposed
a tablet as a fallback:

- must be powered from the vehicle's electrical system;
- the connection must block reverse power flow into the vehicle, with the blocking diode
  **mounted within 200 mm of the device**;
- must not be charged from an external source during the Event;
- **its internal battery counts against the 11 MJ energy storage capacity**.

A Pi with no internal battery avoids all four problems. That is a point in favour of the
current design, and worth a line in the Electrical System Specification.

---

## 2 What the warnings have to warn about — 2.5

2.25.1 requires "energy storage system warnings" without saying what they are. The content
comes from **Reg. 2.5.5 / 2.5.6, p. 24** (clause numbering in V1.0 is visibly off here — the
bullet list is printed under 2.5.6 but belongs to the 2.5.5 stem; read them as one rule).

Teams must supply manufacturer's specifications containing, and must not at any time operate
cells outside:

| Manufacturer limit (2.5.5/2.5.6) | Our source | `BmsLimits.h` |
| :--- | :--- | :--- |
| minimum operating cell voltage | `CELL_V_MIN_VAL` (`0x100`) | unset |
| maximum operating cell voltage | `CELL_V_MAX_VAL` (`0x100`) | unset |
| maximum discharge current | `PACK_I_MASTER` (`0x101`) | unset |
| maximum charge current | `PACK_I_MASTER` (`0x101`), sign-split | unset |
| maximum temperature while discharging | `CELL_T_MAX_VAL` (`0x102`) | unset |
| minimum temperature while charging | `CELL_T_MIN_VAL` (`0x102`) | unset |
| maximum temperature while charging | `CELL_T_MAX_VAL` (`0x102`) | unset |

**Seven limits.** Temperature is split by direction of current flow: *maximum while
discharging*, *maximum while charging* and *minimum while charging* are three separate
figures, and the charge-side maximum is typically the lower of the two. Charge current and
discharge current are likewise separate limits.

Our decoded quantities already cover all seven — `packTempMax`, `packTempMin`, `cellVMax`,
`cellVMin` and a signed pack current are enough to evaluate every row, since the sign of
`PACK_I_MASTER` tells us which direction we are in. What has to change is `BmsLimits.h`,
which needs **charge/discharge-aware thresholds** rather than one temperature ceiling and one
current ceiling. Doing this before the limits are known costs nothing: the fields are all
`NaN` today, so adding fields adds more `NaN`.

> **Where the numbers come from.** The dashboard takes its thresholds from the BMS's own
> **Operational Limits** (`docs/reference/LithiumBalance_BMS_CAN_Reference.md` §5a), so the
> warning and the protection the pack actually has can never disagree. Those BMS limits
> must in turn sit inside the **manufacturer's** figures: 2.5.5 makes the cell
> manufacturer the authority — "specifications endorsed by the cell manufacturer" — and
> Reg. 2.5.3 (p. 24) adds that third-party or internet figures may be rejected outright,
> with the Chief Energy Scientist deciding on conflict. Keeping the BMS inside the datasheet
> is the BMS configurer's and certifying engineer's job; the dashboard follows the BMS. The
> deliberate-NaN design in `BmsLimits.h` is right until that export exists.

### Automatic protection is the BMS's job, not the screen's — Reg. 2.5.5, p. 24

> The competition vehicle must automatically prevent electrochemical cells from being
> operated outside the operating ranges … Teams must provide endorsement by their certifying
> engineer that an adequate and effective automatic battery management system has been
> designed and implemented so that fault conditions will be managed safely.

The dashboard is display-only and must never sit between a fault and a contactor. The
enforcement is also a **certifying-engineer sign-off** item, which raises the stakes on being able to
show that the screen is advisory. Keep saying so explicitly in the Electrical System
Specification.

### Capacitor discharge — Reg. 2.5.11, p. 25

All capacitors outside the packs or collector must discharge to **below 60 V within five
seconds** of safe state. A constraint on whatever DC-DC feeds the panel and Pi, not on
software, but it belongs in the same conversation as §6.

---

## 3 Indicators and hazards — what "operating" means — 2.23

**Reg. 2.23, pp. 39–42.** The lighting section is long; three clauses reach the dashboard.

**2.23.11, p. 41** — "Direction indicators must flash at 90 ± 30 flashes per minute."
The legal window is **60–120/min**, and `kBlinkerFlashesPerMinute = 90` in
`src/VehicleSimulator.cpp` sits mid-range.

**2.23.12, p. 42** — "It must be possible to flash the left and right direction indicator
lamps simultaneously, as a hazard warning signal." Hazard is defined as *both indicators
flashing together*, with no separate hazard lamp. This is precisely the semantics
`HazardIndicator.qml` already implements: a steady triangle to distinguish the mode, with
the two arrows flashing in sync carrying the actual signal. The rule's own definition backs that design.

**2.23.1, p. 39** — the required lamp set. Relevant because it bounds what a blinker source
could ever report: **front, side and rear** indicators on each of left and right, plus two
rear stop lamps, one central stop lamp, two daytime running lamps. Headlamps and tail lamps
are **not required**. So a left turn is up to three lamps, and "left indicator operating" is
an aggregate over them — worth settling with the lights owner, since it decides whether the
CAN message carries one bit per side or one per lamp.

### "Operating" is a low bar — and that is a real decision

**2.25.1 asks only whether the indicators "are operating."** It does not ask the screen to
verify that the lamps are lit.

That is satisfiable by a "requested" signal. It does not demand lamp-current sensing.

**Keep mirroring real lamp state anyway, if the lights owner can provide it.** The weaker
wording relaxes a legal requirement, not an engineering one — a dead indicator on the Stuart
Highway is a safety problem whether or not a rule names it, and the whole project is built
on not rendering absent data as a plausible number. But the relaxation is genuinely useful
in one way: it **unblocks the dashboard side**. "Indicator requested" is the easier message
for the driver-controls owner to produce, and under this rulebook it is sufficient to pass
scrutineering. Take it if that is what is on offer, and record the choice.

> **Still blocked on:** the lights owner confirming a byte layout. Nothing decodes a blinker
> message today — `VehicleSimulator::tickBlinkers()` is the only writer, so on a live bus
> the arrows never light. This is a scrutineering failure under 2.25.1, and it is the single
> largest compliance gap in the project.

---

## 4 Rear vision — 2.17

**Reg. 2.17, p. 35.** Two clauses:

- **2.17.1** — rear vision must let the belted driver see the ground in the areas of
  **UNECE Regulation 46, Section 15** (diagrams in the PDF).
- **2.17.2** — "Rear vision systems may be electronic, mirrors, or both. It must not be
  possible to drive the competition vehicle without effective rear vision. Rear vision
  images must be upright and oriented so that objects on the right of the competition
  vehicle are on the right of the image."

**The existing out-of-scope decision survives.** Mirrors satisfy 2.17 completely; electronic
rear vision is one permitted option, and 2.25.1's rear-vision bullet is explicitly
conditional — "(if fitted)". So as long as the car uses mirrors, this dashboard has no
rear-vision obligation. The decision recorded on 2026-09-03 stands unchanged under the new
rulebook.

**If the car ever adopts a camera**, 2.25.1 pulls the feed onto the always-visible screen,
and "not behind menus" means it cannot be a page the driver switches to. That would reshape
the layout entirely and is a far larger commitment than it looks — flagged, not planned.

---

## 5 Physical installation — vision, occupant cell, electrical safety

Nothing here is about software, but it constrains where a 5″ or 7″ panel can physically go,
and these are scrutineering checks (Reg. 3.12.6 lists "vision" as a station).

### Forward and sideward vision — Reg. 2.16, pp. 33–34

The hard one. The belted, helmeted driver must be able to **identify 75 mm high letters** at
every point of forward travel that is 4 m from the eyes, between 0.4 m below and 0.7 m above
eye level, and **between 100° left and 100° right** of the direction of travel.

- **2.16.2** — no more than **2 pillars** in that field, each obscuring **less than 6°** of
  horizontal field of view, measured left-eye-to-left-edge and right-eye-to-right-edge with
  eyes 65 mm apart. The informal note: an A-pillar under 65 mm diameter at eye level will
  comply.
- **2.16.3** — forward and sideward vision must be achieved **without** mirrors, lenses or
  electronic vision systems.

**The practical consequence for the enclosure.** The 200° field is wide and starts 0.4 m
below eye level, so a display and its enclosure mounted high or centrally can eat into it.
The pillar budget is only two, and the panel housing is not a pillar — it is simply
obstruction, with no allowance of its own. **Mount the screen below the 0.4 m-below-eye-level
floor**, or confirm with the certifying engineer that it falls outside the specified volume.
This is worth settling before the enclosure is built, because 3.15.1 makes post-scrutineering
design changes close to impossible.

### Occupant cell — Reg. 2.11.2, p. 29

> Vehicle components within the occupant cell must be designed to minimise the risk of
> injury or entrapment in a crash.

A rigid panel on a bracket in front of a helmeted driver is a head-strike candidate. Both
Riverdi panels are the frameless versions, so the bezel and bracket are designed in-house
with the mechanics team, and can be designed for this from the start. Needs certifying-engineer input, and the energy-absorbing
or frangible mount is a design decision, not an afterthought.

Also relevant: **2.11.5** requires at least 50 mm between every point of the helmet and the
convex hull of the occupant cell — the mount must not be what closes that gap.

### Egress — Reg. 2.14.1, p. 33

Every occupant must exit unaided in **under 15 seconds**, belted and helmeted at the start.
A display bracket in the egress path is a direct failure of a demonstrated, timed test. Check
the mount against the egress route, with the actual driver.

### Electrical safety — Reg. 2.27, pp. 43–44

"High voltage" means **> 60 V dc** or > 30 V rms ac (2.27 preamble), so our ~80–150 V pack is
HV and the DC-DC input is HV wiring.

- **2.27.2** — HV protection **inside the driver, passenger and luggage compartments** must
  exclude objects larger than **1 mm** diameter (IPXXD). Stricter than the IPXXB (finger-proof)
  required elsewhere. If HV wiring runs to a DC-DC near the dash, it is inside the driver
  compartment and takes the stricter rating.
- **2.27.1** — protection by double insulation, enclosure or barrier, not removable without
  tools. **2.27.4** — electrical tape and flimsy covers will not pass as supplementary
  insulation; Kapton is called out as unsuitable as an outer layer if removable without tools.
- **2.27.6** — the HV symbol must appear on any enclosure reachable without tools, if removing
  it exposes HV parts.
- **2.27.7** — isolation resistance > 100 Ω per volt between any exposed conductive part and
  either ESS terminal (≈ 10 mA maximum leakage), and **2.27.9** requires a permanently
  connected electronic device monitoring that isolation.

**2.27.9 is worth one question to the electrical team, and no more.** Those three lines are
its entire text: a permanently connected electronic device must monitor chassis/body
isolation. The regulation says **nothing** about reporting it — no display requirement, no
alert, no bus, no driver indication. A compliant monitor could be a sealed box with a single
LED, and 2.25.1 does not list isolation among the mandatory display items.

So this is **not** a dashboard obligation. The only reason it appears in this document is
that it is one piece of hardware the rules guarantee will exist on the car, unlike
`bmsFault`, whose problem is that no source exists at all. **If** the chosen monitor happens
to broadcast on CAN, it would be a cheap and genuinely meaningful footer dot. If it does not,
nothing is owed and nothing changes. One question, then drop it.

---

## 6 Power, safe state, and the Pi — 2.25.2, 2.27, 2.28

### The supply — Reg. 2.25.2, p. 42

> This instrumentation must be powered from the energy storage system, and not from separate
> batteries.

Bus voltage is far above either panel's input
range (7.0–30.0 V on the 7″, 7.0–36.0 V on the 5″), so a **DC-DC converter is required
regardless of panel choice**, and the 5″ panel's USB-C input remains a bench convenience
only. A power bank is not a legal supply in the car. See `docs/hardware/display-hardware.md` and
`docs/hardware/wiring.md`.

### Safe state kills the screen — Reg. 2.28, pp. 44–46

**Reg. 2.28.1** requires that in safe state every conductor leaving each pack is galvanically
isolated by contactors on both poles, no voltage is present across any pack or collector
conductor pair, and **no current flows through any conductor loop external to the packs or
collectors**. The Solar Wombat description (§7) shows the mechanism in practice: the e-stop
loop drops a relay that unpowers the 12 V DC-DC, and the loss of 12 V is what opens every
contactor.

Combine with 2.25.2 and the conclusion is unavoidable:

> **The dashboard is powered from the pack, and the pack is isolated in safe state.
> Therefore the screen loses power, without warning, every time safe state is invoked.**

**2.28.5** gives the driver a single-action safe-state control reachable while belted; **2.28.6**
puts a second one on the exterior in a 180 mm yellow disc within 100 mm of the windscreen's
lower edge, operable by a first responder; **2.28.3** makes the whole mechanism fail-safe, so
any failure of the activation path also drops into safe state. So the power cut is not an
edge case — it is the designed behaviour of three separate paths, one of which is a stranger
pressing a button.

#### Two engineering consequences

**1. Abrupt power loss will corrupt the SD card.** A Pi 4 with a read-write ext4 root that is
hard-powered-off repeatedly will eventually fail to boot, and it will do it at the least
convenient moment. This is not hypothetical and it is not a software bug we can fix after the
fact. Mitigations, in order of preference:

- **Read-only root with an overlay** (`overlayfs` via `raspi-config`, or
  `raspberrypi-sys-mods`), so the filesystem is never dirty at power-off. Costs: logs and any
  persisted state must be explicitly directed to tmpfs or a small writable partition. **This
  is the right answer** and should be adopted during Pi bring-up, not after a failure.
- A small supercapacitor or holdup on the Pi's 5 V rail plus a GPIO "power failing" line to
  trigger a clean shutdown. More hardware, more to go wrong, and the holdup must not violate
  2.5.11 (capacitors outside the packs discharging below 60 V in five seconds — a 5 V holdup
  is trivially compliant, but it must be declared).
- Nothing, and reflash the card when it breaks. Not acceptable for a 3000 km event.

Planned as Stage 5 of Pi bring-up in `docs/roadmap.md`.

**2. Nothing requires the dashboard to work in safe state.** BWSC has **no
auxiliary-battery requirement**, so in safe state the hazards and the screen are both
unpowered — consistent rather than contradictory — and 2.25.1's obligation is scoped to
"while the competition vehicle is in motion", which a vehicle in safe state is not.

The one function BWSC requires to survive safe state is
**voice radio**: Reg. 3.8.1–3.8.2, p. 49 — two-way radio to the rear escort must work
"whenever the driver is in the competition vehicle, including when the main energy storage
contactors are open and when the competition vehicle is in safe state."

**That does not imply a vehicle supply outliving safe state.** Reg. 2.5.8, p. 25 exempts
"batteries or cells inside devices such as handheld radios … carried by the driver or
passengers … if they are not electrically connected to the competition vehicle, its
instrumentation or control systems." A handheld UHF radio on the driver satisfies 3.8.2 with
its own battery and no vehicle wiring at all, which is almost certainly the intended reading
— the organiser issues the satellite phone and the escort-vehicle radios as hire items
(3.8.2–3.8.4).

The alternative, a fixed vehicle-mounted radio, needs a supply that survives contactor
opening, and that supply would be a battery that **counts against the 11 MJ** and, under
Reg. 2.5.4, must sit **inside one of the two permitted energy storage packs**. So the
handheld route is dramatically simpler. **Confirm which the team intends** — but either
way, nothing here gives the Pi a supply, and nothing should.

### The low-voltage bus is part of the safe-state story — Reg. 1.29.1, p. 19

The required safe-state diagram must show "how the low-voltage bus external to the energy
storage pack(s) is deenergised in safe state." The Pi and panel hang off that bus, so **the
dashboard's supply appears on a document a scrutineer reads**. It needs to be on the
e-loop-controlled side, and it needs to be drawn.

---

## 7 Scrutineering and compulsory documentation — 1.29, 3.11–3.15

### Documentation deadlines — Reg. 1.29.1, pp. 18–19

| Group | Due | Dashboard content |
| :--- | :--- | :--- |
| A — team info, promo, photographs | **5 Mar 2027** | — |
| B — Mechanical / **Electrical System** / Solar Collector / **Energy Storage System** Specifications | **5 Mar 2027** | **Where the display, its DC-DC, the Pi and the CAN wiring are described.** |
| C — Energy Storage System Incident Plan, Team Safety Plan | **30 Apr 2027** | — |
| D — logistics, travel, individual registrations | **28 May 2027** | — |
| E — **Roadworthiness Certificate** | **15 Aug 2027** | Certifying engineer signs off the mount, the vision check and the electrical install. |

> No vehicle enters Static Scrutineering until all Group A–D documentation is **approved**,
> and teams get no pit garage keys until A–D are approved. The Group B deadline is the real
> one for this project: **5 March 2027** is when the dashboard's electrical architecture has
> to be written down and defensible.

### Presented on paper at Static Scrutineering — Reg. 1.29.1, p. 19

Printed on A4 or US Letter. **"Diagrams on a laptop or mobile phone are not acceptable."**

- Final technical documentation describing the vehicle as built, highlighting changes.
- **Two copies** of a top-view diagram, front of vehicle at the top, showing emergency
  isolation switch locations.
- The original signed Roadworthiness Certificate.
- A **single-sheet block diagram**: plan view, where each HV functional block sits (PV arrays,
  packs, main fuses, motors) and the routing of HV wiring between them.
- A **legible simplified electrical diagram with a written description** showing how safe
  state is implemented — the e-stop loop, how it controls the HV contactors, the system that
  deenergises the e-stop loop in safe state, **how the external low-voltage bus is
  deenergised**, and the battery fuses. The **Solar Wombat** example sets the expected level
  of detail.

### The Solar Wombat companion document

`docs/vendor/bwsc2027/2027-Solar-Wombat-incl-drawing.pdf`, 2 pages: one page of prose, one page of
hand-drawn schematic. **The drawing does not survive text extraction** — it is a scanned
sketch and must be read visually from the PDF.

Its own framing is worth keeping in mind: the circuit "does not represent the only way, or
even the best way" and "is far from optimum" — it names its own flaw, powering the 12 V DC-DC
from only one pack, which causes cell imbalance. It exists **only to show the level of detail
expected in the block diagram**, and the document notes a car built exactly to it might still
fail scrutineering, e.g. if the 12 V bus decays slowly enough that quickly re-closing the
e-loop switches exits safe state, violating 2.28.3 and 2.28.6.

Its safe-state mechanism, which is the pattern our 12 V bus will follow:

- In safe state, relay **Y1** is open, so there is **no power to the 12 V DC-DC converter**.
  With no 12 V, **all contactors are open**, isolating both packs and all PV arrays. The only
  thing still energised is the BMS, whose only external connection is Bluetooth.
- To exit safe state, a mechanism outside Pack 1 closes momentary switch **S1** inside the
  pack, powering the 12 V DC-DC, which — if every e-stop-loop switch is closed — closes Y1.
  Y1 latches when S1 is released. **Vehicle systems are then powered up progressively over
  CAN** via a relay controller.
- Pressing any normally-closed switch in the series e-stop loop opens Y1, unpowering the 12 V
  DC-DC and immediately opening every other contactor, and prevents Y1 from re-closing until
  S1 is pressed again.

Two things for us. First, **"powered up progressively over CAN via the relay controller"** is
likely how the dashboard itself gets switched on, which means a boot-order question:
the Pi may be powered after the CAN bus is already live, or before. Either way the no-source
`--` states have to look deliberate during the first seconds. Second, the Wombat shows the
BMS surviving safe state on its own supply — but with **Bluetooth** as its only external link,
not CAN. If our n-BMS is wired the same way, the BMS footer dot goes dark in safe state
regardless of what the Pi is doing.

### What gets checked, and when the design freezes

**Reg. 3.12.6, p. 52** — road-ready checks include signage, dimensions, solar collector,
egress (all drivers), **vision (all drivers)**, **lights, indicators and horn**, and
**electrical compliance**. Four of those seven touch this project.

**Reg. 3.12.4, p. 52** — dismantling (solar collector, top shell) may be required to inspect
mechanical, electrical and energy storage systems, and **3.12.5** requires reassembly in a
reasonable time in the Chief Scrutineer's opinion. A display install that makes the top shell
hard to remove is a practical problem on the scrutineering floor.

**Reg. 3.15.1, p. 54** — once Static Scrutineering is passed, **no design changes** are
permitted except in exceptional circumstances approved by the Chief Scrutineer. **3.15.3** —
after Dynamic Scrutineering and until release from the start line, no component exchange,
modification or repair without approval, tyres excepted.

> **The deadline that actually matters.** Static Scrutineering commences **Monday 16 August
> 2027**. Software on an unchanged installation is not a "design change", but the mount, the
> panel choice, the DC-DC and the wiring freeze then. **Reg. 3.15.2** also requires that all
> parts used during the event be carried by the vehicle along the entire route, with broken
> parts replaceable only by equivalent spares carried in support vehicles — so a spare panel
> and a spare Pi, pre-flashed and identical, travel with the team or they do not exist.

---

## 8 Operating environment the dashboard has to survive

Not regulations in themselves, but they are the facts the regulations describe, and they bear
on the software far more than the compliance list does.

| Fact | Reg. | Consequence |
| :--- | :--- | :--- |
| ~**3000 km**, Darwin (NT) → Adelaide (SA), major highways | 3.20.1, p. 57 | Continuous operation for days. A slow memory leak or a drifting odometer has 3000 km to express itself. |
| **08:00 start, 17:00 finish, daily**, 22–26+ Aug 2027 | 3.21.1–3.21.3, p. 57 | ~9 h uninterrupted runtime per day, five or more days. Pi thermals under a canopy in the sun, and the SD-card lifetime question in §6. |
| **No driving after sunset**; late finishes penalised | 3.21.4, p. 57 | Daylight operation only. Sunlight readability is everything; night-mode styling is not needed, consistent with removing day mode on 2026-09-10. |
| **Mandatory control stops**, locations in the route notes | 3.20.3, p. 57 | Repeated stop/start cycles — the `vehicleStopped` path runs many times a day, so it needs to be as solid as the driving path. |
| **Compulsory driver changes**, 5 min stops at specified locations | 3.23.4, p. 58 | Multiple drivers per day. The screen is read by people of different heights and eyesight; nothing may depend on one driver's seating position. |
| Australian outback, dry season | — | Dust, vibration, 1000 cd/m² of panel against a very bright sky. Both Riverdi panels are specified for this; connectors and the HDMI cable are the weak link. |
| Energy capacity **11 MJ** for Challenger | 2.5.2, p. 23 | ≈ 3.06 kWh. The Pi and panel draw perhaps 10–15 W; over 9 h that is ~100–135 Wh, i.e. **3–4 % of total stored energy**. Not negligible. Efficiency in Wh/km stays the right hero metric, and the display's own draw is worth measuring once on the bench. |

---

## 9 Sections confirmed irrelevant

Read and ruled out, recorded so they are not re-read. The full regulation list is in the
PDF's Contents, pp. 3–6.

- **§1 Administration** except **1.12** (schedule) and **1.29** (documentation) — fees,
  visas, freight, insurance, media, drones, team identification.
- **2.1–2.4** classes, dimensions, wheels, solar collector — except the 11 MJ figure used
  in §9 and the Challenger/Cruiser distinction. **We are Toyota Challenger class**: single
  seat, one occupant, solar-only, no external recharging.
- **2.6 Cruiser recharging**, **2.7 signage**, **2.8 ballast** — no dashboard content.
- **2.9 Tracker and telemetry** — the tracker is **organiser-supplied, self-powered and
  requires no electrical connection to the vehicle** (2.9.2, p. 28). It does not interact
  with our CAN bus or our screen. Its only constraint is mechanical: a 120 × 120 × 70 mm box
  needing a 120° radio-transparent cone above it, unobstructed by carbon fibre, solar cells
  or metal. **Not a telemetry integration point** — if the team wants live telemetry to the
  chase car, that is our own system to build, unrelated to this regulation.
- **2.10 safety**, **2.11 occupant cell** (except 2.11.2 / 2.11.5, §5), **2.12 seats**,
  **2.13 safety-belts**, **2.14 egress** (except 2.14.1, §5), **2.15 ventilation**.
- **2.18 steering**, **2.19 stability**, **2.20 brakes**, **2.21 tyres**, **2.22 driving and
  reversing** — note **2.22.2** requires the vehicle to be drivable backwards under its own
  power with the driver seated normally, which is why a reverse gear exists for D/N/R to
  report, but the regulation imposes nothing on its display.
- **2.24 audible warning device** — a horn complying with UNECE R28. Not dashboard-connected.
- **2.26 Automatic functions** — cruise control must auto-deactivate on brake or shutdown and
  must not auto-resume; automatic driving functions must deactivate on manual input. **No
  display requirement attaches.** N/A while neither is fitted.
- **§3 The Adventure** except **3.8** (radio in safe state), **3.11–3.15** (scrutineering),
  **3.19–3.23** (operations, §8).
- **§4 Achievement and Celebration**, **Glossary** (pp. 68–72) — note the glossary's
  two-column layout extracts scrambled; read it from the PDF if a definition is needed.

---

## 10 Dates that constrain this project

From Reg. 1.12.2, pp. 10–11, filtered to what bears on the dashboard.

| Date | Event | Why it matters here |
| :--- | :--- | :--- |
| Fri **9 Oct 2026** | Standard Applications for Entry close | Entry must be in. |
| Fri **5 Mar 2027** | **Group A & B documentation deadline** | **The Electrical System Specification describing the display, DC-DC, Pi and CAN wiring is due.** The first hard deadline this project owns. |
| Fri 30 Apr 2027 | Group C deadline | ESS Incident Plan, Team Safety Plan. |
| Fri 28 May 2027 | Group D deadline | Logistics, registrations. |
| Sat 7 Aug 2027 | Event HQ opens, Darwin; Event period commences | |
| Wed 11 Aug 2027 | All competition vehicles based at Event HQ | Car and dashboard must be in Darwin, working. |
| Sun **15 Aug 2027** | **Group E — Roadworthiness Certificate** | Certifying engineer has signed the mount, vision and electrical install. Required before on-road test permits. |
| Mon **16 Aug 2027** | **Static Scrutineering commences** | **Hardware design freeze** (3.15.1). Vision, lights/indicators and electrical compliance are checked. |
| Sat **21 Aug 2027** | Dynamic Scrutineering; closes **12:30** | 07:00 roll call mandatory. No start without passing. |
| Sun **22 Aug 2027** | **Official Start, Darwin**, 08:00 | |
| Thu 26 Aug 2027 | Official Finish Line opens, Adelaide | |
| Sun 29 Aug 2027 | Award ceremony | |

> Working backwards from 5 March 2027: the panel choice, the DC-DC specification and the
> mounting concept all have to be settled by then, because they are what the Electrical
> System Specification describes. **`docs/hardware/display-hardware.md` lists the panel choice as
> still open — that is now a dated decision, not an open-ended one.**

---

## 11 Where the truth lives

1. **`docs/vendor/bwsc2027/2027-BWSC-Event-Regulations-V1.0-Published-07052026.pdf`** —
   authoritative, 72 pages, untracked (download link at the top). Every clause cited here is quoted or paraphrased from it with a
   page number.
2. **Regulation Bulletins and Team Notices** — the organiser amends the rules through these,
   and V1.0 is dated 7 May 2026 with the event in August 2027. They are published to the team
   portal and are authoritative over the PDF. Anything in §1 or §2 above should be re-read
   against the current bulletins before scrutineering.
3. **`teams@worldsolarchallenge.org`** — Reg. 1.30.1: the Team Manager asks regulation
   questions here. Reg. 1.30.2 is worth knowing: if the answer restricts what a team may do,
   it is published to everyone anonymously; if it does not, it is answered privately. So
   asking is free, and the published Q&A is itself a source worth checking.
4. **This file** — a dashboard-scoped index into the PDF, accurate as of the extraction date
   at the top. It paraphrases. Where a figure matters, read the clause.
5. **`docs/regulatory-compliance.md`** — our implementation status against these rules.
