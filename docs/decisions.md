# Decision Log

Every system-level design decision for the dashboard (power, display, CAN, wiring, and
who does what), with the date, who made or confirmed it, and why. This is the source for the "first version"
documentation: write that from here, not from the plans.

Started 25 Nov 2026 and backfilled from `hardware/mvp-week48-plan.md`,
`hardware/wiring.md` and `hardware/pi-setup.md`, which still hold the full detail. Each
entry links to it.

## How this log works

- **One entry per decision**, under its area. An entry gets the next free number and keeps
  it, so `D07` always means the same thing.
- **Never delete an entry.** When a decision changes, add a new entry and set the old one's
  status to *Replaced by Dxx*. The history of why something changed is part of the record.
- **Scope** says whether it is decided for the **MVP** (week 48 prototype), for the
  **competition** car, or both. An MVP decision does not carry over to the competition car
  unless an entry says so.
- **Decided by** names the person who made or confirmed it. "Dashboard team" means Juan
  and Sara.
- Questions that are **not decided yet** go in [Open](#open-not-decided-yet) at the
  bottom, and move up into an entry once they are answered.
- **CAD lives in the mdust-cad repo**, designed as code. That repo is the master copy;
  only released files are copied to the team's subsystem storage
  ([Teams: Juan Production System / Dashboard](https://studentmdh.sharepoint.com/:f:/r/sites/MDUSolarTeam/Delade%20dokument/Juan%20Production%20System/Dashboard?d=wf01a78ed6836411080dc312dc58c9ecc&csf=1&web=1&e=c9A8Z6)).
  **A part's own design decisions** (layout, material, wall thickness, cable openings…)
  go in that project's `decisions.md` in mdust-cad, for example
  `projects/dashboard-pi-box/decisions.md`. This log keeps only what the rest of the
  system depends on, and points there for the rest. Do not repeat a decision in both.
- **Software** decisions live in `CLAUDE.md` (Invariants) and `implementation.md`. Add one
  here only when it affects the hardware or what the driver sees.

## Index

| # | Decision | Date | Scope | Status |
| :--- | :--- | :--- | :--- | :--- |
| [D01](#d01-pi-powered-by-usb-c-from-a-12--5-v-buck) | Pi powered by USB-C from a 12 → 5 V buck | 13 Nov | MVP | Current |
| [D02](#d02-12-v-from-the-cars-fuse-box-two-3-a-slots) | 12 V from the car's fuse box, two 3 A slots | 25 Nov | MVP | Current |
| [D03](#d03-one-common-ground-wago-can-pin-2-not-wired-c2-optional) | One common ground WAGO; CAN pin 2 not wired (C2 optional) | 25 Nov | MVP | Current |
| [D04](#d04-riverdi-7-is-the-mvp-display) | Riverdi 7″ is the MVP display | 19 Nov | MVP | Current |
| [D05](#d05-3d-printed-panel-frame-by-mousa-no-taped-panel-in-the-car) | 3D-printed panel frame by Mousa; no taped panel in the car | 19 + 25 Nov | MVP | Current |
| [D06](#d06-hand-modified-mcp2515-board-tja1050-replaced-by-sn65hvd230) | Hand-modified MCP2515 board: TJA1050 → SN65HVD230 | Before 13 Nov | — | Set aside by D07 |
| [D07](#d07-waveshare-rs485-can-hat-is-the-mvps-can-board) | Waveshare RS485 CAN HAT is the MVP's CAN board | 13 Nov | MVP | Current |
| [D08](#d08-can-hat-on-a-40-pin-ribbon-outside-the-pis-case) | CAN HAT on a 40-pin ribbon, outside the Pi's case | 19 Nov | MVP | Replaced by D20 |
| [D09](#d09-can-bus-is-daisy-chained) | CAN bus is daisy-chained | 24 Nov | Team-wide | Current |
| [D10](#d10-can-connector-würth-wr-mpc3-23) | CAN connector: Würth WR-MPC3 2×3 | 24 Nov | Team-wide | Current |
| [D11](#d11-can-cable-lapp-2170222) | CAN cable: LAPP 2170222 | 24 Nov | Team-wide | Current |
| [D12](#d12-can-pinout-rätt-vcu-v2-from-ludwigs-chart) | CAN pinout: "rätt" (VCU v2) from Ludwig's chart | 24–25 Nov | Team-wide | Current |
| [D13](#d13-pass-through-board-with-bent-leg-male-wr-mpc3-connectors) | Pass-through board with bent-leg male WR-MPC3 connectors | 25 Nov | MVP | Current |
| [D14](#d14-hat-lead-screwed-in-with-ferrules-not-soldered) | HAT lead screwed in with ferrules, not soldered | 24 Nov | MVP | Current |
| [D15](#d15-dashboard-passes-the-shield-through-and-earths-neither-pin) | Dashboard passes the shield through and earths neither pin | 25 Nov | MVP | Current |
| [D16](#d16-any-chain-position-hat-terminator-on-only-at-a-chain-end) | Any chain position; HAT terminator on only at a chain end | 25 Nov | MVP | Current |
| [D17](#d17-pi-and-can-hat-share-one-3d-printed-case) | Pi and CAN HAT share one 3D-printed case | 19 Nov | MVP | Replaced by D18 |
| [D18](#d18-one-pi-box-for-the-whole-pi-side-juan--sara-inside-mousa-outside) | One Pi box for the whole Pi side; Juan + Sara inside, Mousa outside | 25 Nov | MVP | Current |
| [D19](#d19-wiring-split-juan-inside-the-dashboard-valentina-car-side) | Wiring split: Juan inside the dashboard, Valentina car side | 25 Nov | MVP | Current |
| [D20](#d20-can-hat-wired-to-the-pi-by-eight-jumper-wires) | CAN HAT wired to the Pi by eight jumper wires | 26 Nov | MVP | Current |
| [D21](#d21-can-wire-colours-red-can-h-green-can-l) | CAN wire colours: red CAN-H, green CAN-L | 26 Nov | MVP | Current |

All dates are 2026.

---

## Power

### D01: Pi powered by USB-C from a 12 → 5 V buck

- **Date:** 13 Nov · **Decided by:** Dashboard team · **Scope:** MVP · **Status:** Current
- **Decision:** The Pi 4 takes 5 V through its **USB-C** input, from an Electrokit
  **EKM006** buck (TI LMR14050, 4–40 V in, 5 A out, VSEL jumper fitted for 5 V), via a
  3 A-rated USB-C lead cut to about 10 cm (26 Nov: the Pi box layout puts the buck next to
  the Pi; first planned at about 30 cm).
- **Why:** USB-C goes through the Pi's own input fuse and protection; the GPIO 5 V pins
  bypass both. The EKM006 has headroom for the Pi, the case fans and a fallback screen.
- **Considered:** Feeding the GPIO 5 V pins (no protection). Electrokit's open-end USB-C
  cables (rated only 2 A).
- **Details:** `hardware/mvp-week48-plan.md` §2 "Powering the Pi".

### D02: 12 V from the car's fuse box, two 3 A slots

- **Date:** 24 Nov (fuse box), 25 Nov (two slots, fuse size) · **Decided by:** Valentina
  (electrical) · **Scope:** MVP · **Status:** Current
- **Decision:** The dashboard's 12 V comes from the car's **fuse box**, on **two slots**:
  slot 1 (3 A) feeds the Riverdi panel through its DC pigtail, slot 2 (3 A) feeds the
  buck. The holder takes **standard ("Midi") blade fuses**, so the car uses standard-size
  3 A fuses. The inline fuse holder and the MINI fuses are for the bench only.
- **Why:** A short in the panel does not cut the Pi, or the reverse. The fuse box has
  about eight fused outputs, so a separate inline holder is not needed in the car.
  Expected draw is about 1.3 A at 12 V, so 3 A fits.
- **Considered:** One slot split by a + WAGO. The inline fuse holder in the car.
- **Details:** `hardware/mvp-week48-plan.md`, connection list P1a, P1b.

### D03: One common ground WAGO; CAN pin 2 not wired (C2 optional)

- **Date:** 25 Nov · **Decided by:** Dashboard team · **Scope:** MVP · **Status:** Current
- **Decision:** A **WAGO 221-415** joins the grounds: car ground (P2), panel −, buck
  input GND. The CAN connector's pin 2 (GND) is **not** wired to it unless Valentina
  says pin 2 is a separate ground (joint C2).
- **Why:** Pin 2 is the same LV ground the dashboard already reaches through P2, so the
  CAN transceiver already has its reference.
- **Considered:** Always fitting C2.
- **Details:** `hardware/mvp-week48-plan.md`, connection list and "Why C2 is optional".
  Where the car ground connects is still open (see Open).

---

## Display

### D04: Riverdi 7″ is the MVP display

- **Date:** 19 Nov · **Decided by:** Dashboard team · **Scope:** MVP · **Status:** Current
- **Decision:** The MVP uses the **Riverdi 7″ `RVT70HSHNWN00`** (1024×600, 1000 cd/m²),
  powered straight from 12 V through a 5.5 × 2.1 mm DC pigtail. The 5″
  `RVT50HQHNWN00` is a spare with no frame planned. The AliExpress HDMI screen is the
  fallback if the 7″ shows no picture within an hour of bench work.
- **Why:** It takes 12 V directly (7–30 V), is readable in sunlight, and has an OSD for
  brightness. The UI is drawn against 800 × 480 and scaled, so the software is the same
  on either Riverdi.
- **Considered:** Riverdi 5″. AliExpress screen (micro-USB power, dim, no frame).
- **Note:** The **competition** panel is not decided (see Open).
- **Details:** `hardware/mvp-week48-plan.md` §3, `hardware/display-hardware.md`.

### D05: 3D-printed panel frame by Mousa; no taped panel in the car

- **Date:** 19 Nov (3D printed), 25 Nov (Mousa; no tape) · **Decided by:** Dashboard
  team, Mousa (mechanics) · **Scope:** MVP · **Status:** Current
- **Decision:** The panel's frame and bracket are **3D printed** and designed by
  **Mousa**. They hold the panel by its edges or mounting points, not the glass, keep
  the HDMI and DC connectors reachable with strain relief, and leave air behind it.
  **A taped-down panel is not acceptable in the car**, so the in-car test waits for the
  frame. Bench testing can run without it.
- **Why:** Both Riverdi panels are frameless.
- **Considered:** A laser-cut bezel. Taping the panel for the first in-car test
  (rejected 25 Nov).
- **Details:** `hardware/mvp-week48-plan.md` §3 "Mounting for the MVP". CAD: Mousa.

---

## CAN interface

### D06: Hand-modified MCP2515 board: TJA1050 replaced by SN65HVD230

- **Date:** Before 13 Nov · **Decided by:** Juan · **Scope:** — · **Status:** Done, then
  set aside by D07
- **Decision:** On the MCP2515 module, the 5 V TJA1050 transceiver was desoldered and a
  3.3 V SN65HVD230 fitted, so the whole board runs at 3.3 V like commercial Pi CAN HATs.
- **Why:** The Pi's GPIO is not 5 V tolerant, and running the TJA1050 at 3.3 V is out of
  spec.
- **Details:** `hardware/pi-setup.md`, Stage 3 "Board modification". Its test procedure is
  kept in `hardware/mvp-week48-plan.md` Appendix A.

### D07: Waveshare RS485 CAN HAT is the MVP's CAN board

- **Date:** 13 Nov · **Decided by:** Dashboard team · **Scope:** MVP · **Status:** Current
- **Decision:** The MVP uses a new **Waveshare RS485 CAN HAT** (MCP2515 + SN65HVD230,
  12 MHz crystal, switchable 120 Ω). The hand-modified board (D06) is set aside.
- **Why:** It is a known-good board with the same Linux driver, so only `config.txt`
  changes. Testing the modified board was not worth the time before week 48.
- **Considered:** The hand-modified MCP2515 board.
- **Note:** The **competition** CAN board is not decided (see Open).
- **Details:** `hardware/mvp-week48-plan.md` §4.1.

### D08: CAN HAT on a 40-pin ribbon, outside the Pi's case

- **Date:** 19 Nov · **Decided by:** Dashboard team · **Scope:** MVP · **Status:**
  **Replaced by D20** (26 Nov): the ribbon's plug does not fit the Joy-it case
- **Decision:** The HAT connects by a **40-pin IDC ribbon** with a 2×20 header. The Pi
  stays in its Joy-it case with the two fans on GPIO pins 4 and 6.
- **Why:** The Joy-it case covers the header, and the fans already use pins 4 and 6. The
  HAT's pins do not conflict with them.
- **Details:** `hardware/mvp-week48-plan.md` §2 "GPIO pin budget".

### D20: CAN HAT wired to the Pi by eight jumper wires

- **Date:** 26 Nov · **Decided by:** Dashboard team · **Scope:** MVP · **Status:** Current
- **Decision:** Eight **Dupont jumper wires**, each from Pi pin N to HAT pin N on pins
  17–26: 17 3V3, 19 MOSI, 20 GND, 21 MISO, 22 INT (GPIO25), 23 SCLK, 24 CE0, 25 GND. Pins
  18 and 26 stay empty, and there is **no 5 V wire** (the HAT runs on 3.3 V). The wires are
  tied into one block with the pin 17 end marked, and the HAT sits on the Pi box floor,
  held by all four holes. The fans keep pins 4 and 6.
- **Why:** The GPIO header sits down in an opening in the Joy-it heatsink. Dupont housings
  fit in it, but the ribbon's 40-way plug is too wide.
- **Considered:** The ribbon (D08). A stacking header (Electrokit 41013127) on top of the
  case, kept as the **fallback** if the wires fail a shake test: the box gets about 9 mm
  taller, the HAT covers part of each fan, and the fans move to the buck's 5 V.
- **Replaces:** D08.
- **Details:** `hardware/mvp-week48-plan.md` §2 "How the HAT is wired", connection list P8.

### D09: CAN bus is daisy-chained

- **Date:** 24 Nov · **Decided by:** Team convention · **Scope:** Team-wide ·
  **Status:** Current
- **Decision:** Every device has a CAN **IN** and a CAN **OUT** connector, wired straight
  through. There are no stubs off a backbone.
- **Why:** This is how the team's devices and the WaveSculptor 22 are built.
- **Considered:** A backbone with stubs (the original assumption in `wiring.md`).
- **Details:** `hardware/mvp-week48-plan.md` §4.3.

### D10: CAN connector: Würth WR-MPC3 2×3

- **Date:** 24 Nov · **Decided by:** Team convention · **Scope:** Team-wide ·
  **Status:** Current
- **Decision:** **Würth WR-MPC3**, 2×3, 3.00 mm pitch. Cable side: receptacle housing
  `662006113322` with WR-MPC3 crimp contacts. Housings and contacts are in ST Studio.
- **Details:** `hardware/mvp-week48-plan.md` status table, §4.4.

### D11: CAN cable: LAPP 2170222

- **Date:** 24 Nov · **Decided by:** Team convention · **Scope:** Team-wide ·
  **Status:** Current
- **Decision:** **LAPP UNITRONIC BUS PB FD P `2170222`** (violet): one red/green twisted
  pair, 0.25 mm², foil plus braid shield, **no ground core**. Terminators stay at 120 Ω.
- **Why:** It is the team's stock cable. Its 150 Ω impedance (Profibus) is acceptable for
  CAN over car-length runs at 500 kbit/s.
- **Details:** `hardware/mvp-week48-plan.md` status table.

### D21: CAN wire colours: red CAN-H, green CAN-L

- **Date:** 26 Nov · **Decided by:** Vilma (group leader) · **Scope:** MVP (every
  dashboard cable) · **Status:** Current
- **Decision:** On the LAPP cable, **red is CAN-H** (pin 4) and **green is CAN-L**
  (pin 5). The short lead from the pass-through board to the HAT uses the same colours.
- **Why:** The colour itself does not matter, only that every cable follows the same
  rule. It is probably not a team-wide standard, so check other subsystems' cables
  before assuming it.
- **Details:** `hardware/mvp-week48-plan.md` §4.4.

### D12: CAN pinout: "rätt" (VCU v2) from Ludwig's chart

- **Date:** 24 Nov (chart), 25 Nov (checked against the WaveSculptor 22) · **Decided
  by:** Ludwig (VCU, telemetry) · **Scope:** Team-wide · **Status:** Current
- **Decision:** The dashboard follows the **"rätt" (VCU v2)** layout of Ludwig's crimp
  chart (revised 20 Nov). Wire side, latch up: top row 6 shield earth, 5 CAN-L, 4 CAN-H;
  bottom row 3 shield, 2 GND, 1 +12 V. The **telemetry and logger boards are mirrored**, so
  a cable end that plugs into one of them is crimped mirrored. Our side stays "rätt".
- **Why:** It matches the WaveSculptor 22's CAN connector position for position (Tritium
  TRI88.004 §8.3–8.5).
- **Consequence:** The WaveSculptor 22 has **no built-in 120 Ω**. If it is a chain end it
  needs a plug with a 120 Ω resistor between CAN-H and CAN-L.
- **Details:** `hardware/mvp-week48-plan.md` §4.4, chart in `hardware/can-crimp-chart.png`.

### D13: Pass-through board with bent-leg male WR-MPC3 connectors

- **Date:** 25 Nov · **Decided by:** Juan · **Scope:** MVP · **Status:** Current
- **Decision:** A **perfboard** (2.54 mm) carries the IN and OUT connectors as
  **PCB-mount male WR-MPC3**. The legs are bent about 0.5 mm to the nearest holes, any
  board-lock pegs are clipped, the legs are soldered, and **epoxy or hot glue** goes under
  each body. All six pins are joined straight across, IN to OUT, and pin 1 is taken from
  Würth's PCB footprint. Juan has two of these connectors at home; there are none in the
  MDU ST room.
- **Why:** The connectors are held mechanically instead of hanging on wires, and the bus
  stays intact if the dashboard lead or the HAT is removed. The glue takes the plug-in
  force off the solder joints.
- **Considered:** Splicing the cables (no mechanical hold). A junction board with crimped
  male housing pigtails, which is kept as the fallback.
- **Details:** `hardware/mvp-week48-plan.md` §4.3, §4.4.

### D14: HAT lead screwed in with ferrules, not soldered

- **Date:** 24 Nov · **Decided by:** Dashboard team · **Scope:** MVP · **Status:** Current
- **Decision:** A short twisted pair (under ~0.3 m) runs from the board's pins 4 and 5 to
  the HAT's **CAN_H / CAN_L** screw terminal, **screwed in with 0.25–0.5 mm² ferrules**
  (joint C1). The RS485 A/B terminals are not used.
- **Why:** The HAT can be removed without a soldering iron.
- **Details:** `hardware/mvp-week48-plan.md`, connection list C1.

### D15: Dashboard passes the shield through and earths neither pin

- **Date:** 25 Nov · **Decided by:** Dashboard team, after Ludwig's answer · **Scope:** MVP
  · **Status:** Current
- **Decision:** Pins 3 (shield) and 6 (shield earth) pass straight through the board. The
  dashboard earths neither.
- **Why:** The shield is earthed at one device only on the whole network (Tritium's rule).
  Ludwig confirmed the team has not chosen that device yet, and not every cable has a
  shield. Passing both through works whatever the team decides.
- **Details:** `hardware/mvp-week48-plan.md` §4.4.

### D16: Any chain position; HAT terminator on only at a chain end

- **Date:** 25 Nov · **Decided by:** Valentina · **Scope:** MVP · **Status:** Current
- **Decision:** The dashboard works at **any position in the chain**. Its HAT's 120 Ω
  switch is on only if nothing plugs into the dashboard's OUT. Check about 60 Ω across
  CAN-H and CAN-L with the LV off.
- **Why:** The board is the same wherever the dashboard sits, so it does not wait on the
  chain layout.
- **Details:** `hardware/mvp-week48-plan.md` §4.3 "Termination".

---

## Pi box and CAD

### D17: Pi and CAN HAT share one 3D-printed case

- **Date:** 19 Nov · **Decided by:** Dashboard team · **Scope:** MVP · **Status:**
  **Replaced by D18** (25 Nov)
- **Decision:** The Pi (still in its Joy-it case) and the HAT on its ribbon sit in one
  3D-printed case that holds them steady.

### D18: One Pi box for the whole Pi side; Juan + Sara inside, Mousa outside

- **Date:** 25 Nov · **Decided by:** Juan, Sara, Mousa · **Scope:** MVP · **Status:**
  Current
- **Decision:** One **3D-printed box** holds the buck, the Pi 4 in its Joy-it case, the
  CAN HAT (on jumper wires, D20), the pass-through perfboard and the CAN IN/OUT connectors.
  **Juan and Sara design the inside** (layout, connections, ease of work), taking that
  over from Mousa. **Mousa designs the outside** and how it mounts in the car.
- **Why:** Everything on the Pi side is held in one place, and the IN/OUT connectors are
  mounted on the box instead of hanging on cables.
- **Replaces:** D17, which held only the Pi and the HAT.
- **Box design:** The box is designed as code in the **mdust-cad** repo, project
  `dashboard-pi-box`, which holds the brief, the model and the box's own decisions
  (`projects/dashboard-pi-box/decisions.md`): layout, print material, and the single wall
  every cable leaves through. Look there for those, not here.
- **Details:** `hardware/mvp-week48-plan.md` status table.

---

## Responsibilities

### D19: Wiring split: Juan inside the dashboard, Valentina car side

- **Date:** 25 Nov · **Decided by:** Juan and Valentina · **Scope:** MVP · **Status:**
  Current
- **Decision:** **Juan** wires everything inside the dashboard that does not connect to
  the car or another subsystem: the GND WAGO, buck → Pi, the panel pigtail, HDMI, the
  ribbon → HAT, and the CAN board with its HAT lead. **Valentina** wires everything that
  connects to the car: the two fuse slots with their fuses and flat receptacles, the
  ground connection, and the CAN cables between devices. She works from the Dashboard MVP
  Wiring diagram.
- **Details:** `hardware/mvp-week48-plan.md` status table and connection list.

---

## Open (not decided yet)

Move each one into an entry above once it is answered.

| Question | Who | Needed by |
| :--- | :--- | :--- |
| Where the dashboard's ground connects in the car, and with what terminal (P2) | Valentina | In-car test, week 48 |
| Where the CAN chain's two ends are, so the right devices terminate (the WaveSculptor needs a resistor plug) | Team | In-car test |
| Which one device earths the CAN shield (pin 6) | Team (Ludwig) | Not blocking the dashboard (D15) |
| Competition panel: 5″ or 7″ | Dashboard team | Electrical System Specification, **5 Mar 2027** |
| Competition CAN board: Waveshare HAT, hand-modified board, or another HAT | Dashboard team | 5 Mar 2027 |
| LV bus voltage and connection point for the competition car | Electrical team | 5 Mar 2027 |
| Connector family for power and the shell separation point | Dashboard team, electrical | 5 Mar 2027 |
| Mount concept: position against the vision envelope, bracket, enclosure | Dashboard team, mechanics | Before Static Scrutineering, 16 Aug 2027 |

The competition questions come from `hardware/wiring.md` §5.

**Answered since the log started:** the CAN-H colour (D21, 26 Nov). The Pi box's inside
layout now exists in mdust-cad, `projects/dashboard-pi-box` (D18).

---

## Template

```markdown
### Dxx: Short statement of the decision

- **Date:** · **Decided by:** · **Scope:** MVP / Competition / Team-wide · **Status:** Current
- **Decision:** What was decided, specific enough to build from.
- **Why:** The reason, in a sentence or two.
- **Considered:** What else was on the table, and why it lost.
- **Details:** Where the full write-up, CAD or datasheet lives.
```

Add a row to the Index too.
