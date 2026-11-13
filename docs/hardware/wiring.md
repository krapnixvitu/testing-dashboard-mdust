# Dashboard Subsystem — Wiring Requirements and Interface

What the physical installation of the dashboard (Raspberry Pi 4 + display panel) has to
satisfy, and which hardware facts the software depends on. **This is a requirements
brief, not a design.** The design itself lives elsewhere — see §1.

Written 2026-11-13, ahead of the Phase 4 installation work in `docs/roadmap.md`.

---

## 1 Scope and boundary

**This subsystem owns:**
- the Raspberry Pi 4 and the display panel;
- their power supply, from the point where it leaves the car's low-voltage bus;
- the CAN drop from the car's bus to the Pi, and the Pi's CAN interface board;
- HDMI, connectors and cabling between those parts;
- the mount and enclosure.

**It needs from the electrical team** (car-level, not ours to design):
- the low-voltage bus voltage, and where on it the dashboard may connect;
- confirmation that this bus is de-energised in safe state (§3);
- the CAN backbone topology — where its two ends are, and whether the Pi is one of them;
- the dashboard drawn into the safe-state diagram and HV block diagram for scrutineering.

**Where things live.** Split by kind of file:

| Kind | Where |
| :--- | :--- |
| Software, and the written docs for this subsystem (this file, `pi-setup.md`, `display-hardware.md`) | This repo |
| ECAD harness, schematics, enclosure and mount CAD, BOM, datasheets | Team subsystem storage — **link: TBD** |

Git suits text that changes together with code; it cannot diff, merge or lock SolidWorks
files. The reason this file *does* live here is §2: those hardware facts are encoded in
the software, and they must change together.

---

## 2 Interface contract — hardware facts the software depends on

Change one side of any row without the other and the failure is **silent**: no error, just
a dead bus, a wrong bitrate, or a black or misscaled screen. Any change to a row needs a
matching software change in the same go.

| Fact | Current value | Where the software encodes it | Status |
| :--- | :--- | :--- | :--- |
| CAN controller | MCP2515 on **SPI0**, chip select **CE0** (pin 24) | `dtoverlay=mcp2515-can0` in `/boot/firmware/config.txt` | Bench-verified wiring per `pi-setup.md` Stage 3 |
| SPI pins | MISO pin 21, MOSI pin 19, SCLK pin 23 | Fixed by SPI0 | — |
| CAN interrupt | `INT` → **GPIO25** (pin 22) | `interrupt=25` in the overlay | — |
| Logic supply to the CAN board | **3.3 V** (pin 1 or 17), not 5 V — Pi GPIO is not 5 V tolerant | — | — |
| MCP2515 crystal | Configured **8 MHz** | `oscillator=8000000` in the overlay | **Not confirmed** — read the can's marking. Wrong value = wrong bitrate, silent |
| Bitrate | **500 kbit/s** | `ip link set can0 type can bitrate 500000` | Must match every node on the car |
| Interface name | `can0` | `--can-interface` default | — |
| Frames accepted | Standard `0x400`–`0x41F`, `0x500`–`0x51F`; extended `0x100`–`0x107` | Kernel filter in `src/SocketCanReader.cpp` | A new device outside these ranges is invisible |
| Frame length | DLC 8 only | `src/SocketCanReader.cpp` drops `can_dlc < 8` | — |
| Display | HDMI via the Pi's **micro**-HDMI port | — | |
| Case fans | Joy-it aluminium case, two fans on **5 V pin 4 and GND pin 6** | — | Keep the CAN board on a different GND pin. MVP wiring: `mvp-week48-plan.md` §2 |
| Panel resolution | 800×480 (5″) or 1024×600 (7″) | `--panel 5in\|7in`; UI scales from an 800×480 reference | Panel not yet chosen |
| Power loss | Abrupt, every safe-state event | Read-only root filesystem — **planned**, roadmap Stage 5 | Not yet done |

Facts above come from `docs/hardware/pi-setup.md` (Stage 3) and `src/SocketCanReader.cpp`.

---

## 3 BWSC requirements

Each with its regulation and page. Rules in full:
`docs/reference/BWSC2027_Regulations_Reference.md`.

### Power and safe state
- **Supply from the energy storage system, not separate batteries** — Reg. 2.25.2, p. 42.
  No dedicated battery, power bank or USB supply in the car.
- **De-energised in safe state.** In safe state no current may flow in any conductor loop
  outside the packs — Reg. 2.28.1, p. 44. So the dashboard's supply must come from the part
  of the LV bus that safe state switches off, and **the Pi loses power abruptly** each time
  (design for it, §4).
- **Drawn for scrutineering.** The safe-state diagram must show how the LV bus outside the
  packs is de-energised — Reg. 1.29.1, p. 19. Due with Group B, **5 Mar 2027**, and
  presented **on paper** at scrutineering.
- **Capacitor discharge.** All capacitors outside the packs must discharge below 60 V
  within 5 s of safe state — Reg. 2.5.11, p. 25. Relevant if any converter in our supply
  path sits on HV.

### Electrical safety — Reg. 2.27, pp. 43–44
"High voltage" is above 60 V dc. Our pack is HV.
- HV inside the driver compartment needs **IPXXD** protection (nothing over 1 mm gets in) —
  2.27.2. Elsewhere IPXXB (finger-proof) — 2.27.3.
- Protection by double insulation, enclosure or barrier, not removable without tools —
  2.27.1. Electrical tape, flimsy covers and removable Kapton do not count — 2.27.4.
- HV symbol on any enclosure reachable without tools if removing it exposes HV — 2.27.6.

Simplest compliance: **keep all HV out of the driver compartment** and bring only the LV
supply to the dashboard.

### Mount and enclosure
- **Vision** — the belted driver must read 75 mm letters at 4 m across 100° left to 100°
  right, from 0.4 m below to 0.7 m above eye level, with at most two pillars of under 6°
  each — Reg. 2.16.1–2.16.2, pp. 33–34. The panel and housing are not a pillar; they are
  obstruction with no allowance. **Mount below the 0.4 m-below-eye-level floor**, or get
  the certifying engineer to confirm it is outside the envelope.
- **Occupant cell** — components must minimise injury and entrapment risk in a crash —
  2.11.2, p. 29. A rigid panel in front of a helmeted driver is a head-strike candidate.
  At least 50 mm clearance from every point of the helmet to the occupant cell's hull —
  2.11.5.
- **Egress** — every occupant out unaided in under 15 s, belted and helmeted at the start —
  2.14.1, p. 33. Keep the mount out of the exit path.
- **Scrutineering access** — the solar collector or top shell may have to come off, and be
  refitted in reasonable time — 3.12.4–3.12.5, p. 52. Use connectors that let the shell
  separate cleanly.

### Freeze and spares
- **Hardware design freezes at Static Scrutineering, 16 Aug 2027** — 3.15.1, p. 54.
- Parts used in the event must travel with the car; broken parts may only be replaced with
  **equivalent spares carried in the support vehicles** — 3.15.2. Carry an identical,
  pre-flashed Pi and panel.
- The certifying engineer signs off the mount and electrical install in the Roadworthiness
  Certificate — Group E, **15 Aug 2027**.

---

## 4 Engineering requirements (not regulatory)

- **Panel input ranges:** 7″ 7.0–30.0 V, 5″ 7.0–36.0 V (`display-hardware.md`). Both
  accept a 12 V or 24 V bus directly, so the panel may not need its own converter. **Confirm
  the LV bus voltage** before assuming that.
- **Pi supply:** a regulated 5 V, 3 A, from a converter off the LV bus. Under-voltage makes
  the Pi throttle and corrupt writes.
- **Abrupt power loss:** tolerated by software (read-only root, roadmap Stage 5), not by
  hold-up hardware. If hold-up hardware is ever added it must still satisfy 2.5.11 and be
  declared.
- **CAN termination:** exactly **two** 120 Ω terminators, one at each physical end of the
  backbone — measure ≈ 60 Ω across CANH/CANL with the bus unpowered. The Pi's CAN module
  has an onboard 120 Ω; **remove or disable it unless the Pi is an end node.**
- **CAN cabling:** twisted pair for CANH/CANL, a ground reference shared with the bus,
  short stub from the backbone to the Pi.
- **Vibration:** about 3000 km of highway. Locking connectors throughout; strain relief on
  HDMI, which is the weakest connector in the stack.
- **Heat:** under a canopy in Northern Territory sun for about 9 hours a day. Check Pi
  temperature in the real enclosure (roadmap Stage 5) and the panel's rated operating range.

---

## 5 Open decisions

- **Which panel** — 5″ or 7″. Comparison in `display-hardware.md`. Needed before
  **5 Mar 2027**.
- **LV bus voltage and connection point** — from the electrical team.
- **Pi 5 V converter** — part and placement.
- **Connector family** for power, CAN and the shell separation point.
- **Is the Pi a CAN bus end?** Decides the onboard terminator.
- **CAN board for the car.** Keep the hand-modified MCP2515 + SN65HVD230 module, or use a
  purpose-built 3.3 V MCP2515 CAN HAT. A HAT uses the same driver and overlay, so the
  software does not change **if the interrupt pin and crystal match** §2; otherwise update
  the overlay line. Flying-lead modifications and long-term road vibration are a poor
  match.
- **Mount concept** — position against the vision envelope, energy-absorbing or
  frangible bracket, enclosure.
- **Where the design files live** — fill in the link in §1.
