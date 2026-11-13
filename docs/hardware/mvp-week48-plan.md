# MVP Plan — Dashboard Running in the Car by End of Week 48

Written Fri 13 Nov 2026. **Target: Sun 29 Nov 2026** (end of ISO week 48).

The MVP is the first prototype: the Pi and a screen powered from the car's 12 V, reading
the real CAN bus, and showing a driver screen plus a debug screen. The car has no other
telemetry yet, so **the dashboard is also the team's debugging tool**.

Hardware comes first because parts have lead times and the software cannot be tested on
the real bus until the wiring exists. Software follows in §7.

This is a plan for a bench-and-car prototype, not the competition installation. The
competition requirements (`wiring.md`) still apply later; where the MVP takes a shortcut,
it says so.

---

## 1 What is on hand today

| Item | Status |
| :--- | :--- |
| Raspberry Pi 4 Model B (2 GB) | Boots Raspberry Pi OS. Dashboard bring-up at Stage 1 (`pi-setup.md`). |
| Joy-it aluminium "armor" case, two fans | Fitted. Fans take **5 V and GND from the GPIO header**; nothing else uses GPIO. |
| MCP2515 module, TJA1050 swapped for an SN65HVD23x | Hand-modified, **never tested**. Possible heat damage during soldering. |
| Riverdi 7″ `RVT70HQHFWN00` and 5″ `RVT50HSHFWN00` | Bought (`display-hardware.md`). Confirm both are in the team room. |
| AliExpress HDMI screen | Used for testing. Micro-USB power, HDMI, on/off switch, no touch. |
| Purple shielded CAN cable, 2×3 connectors | In the team room, details unconfirmed (§6). |

---

## 2 How it all connects

```
  Car 12 V (LV bus)
      │
   [inline fuse 3 A]                       ← first thing after the 12 V tap
      │
      ├──────────────────────────────► Riverdi panel, DC jack (7–30 V / 7–36 V)
      │
      └──► [12 V → 5 V buck, ≥ 3 A] ──► Pi 4 USB-C  (5.1 V)
                                          │
                                          ├─ GPIO pin 4 (5 V) + pin 6 (GND) ─► case fans
                                          ├─ micro-HDMI 0 ───────────────────► panel HDMI
                                          └─ SPI0 + GPIO25 ──► CAN board ──► CANH / CANL / GND
                                                                                  │
                                                               stub to the car's CAN backbone
```

### GPIO pin budget

The fans and the CAN module share the header without conflict, as long as they do not
share a ground pin.

| Pin | Used by | Notes |
| :--- | :--- | :--- |
| 4 | Fan + (5 V) | Already wired |
| 6 | Fan − (GND) | Already wired. **Use a different GND for the CAN board** (9, 14, 20 or 25) |
| 1 or 17 | CAN board VCC, **3.3 V** | Never 5 V: the Pi's GPIO is not 5 V tolerant |
| 9 / 14 / 20 / 25 | CAN board GND | |
| 19, 21, 23 | MOSI, MISO, SCLK (SPI0) | |
| 24 | CS (CE0) | |
| 22 | INT (GPIO25) | Matches `interrupt=25` in the overlay |

If a HAT replaces the module (§4.3), it takes the same pins through its own header.

> **The case and a HAT.** The Joy-it armor case covers the top of the board. Check in the
> team room whether the GPIO header is reachable with the case closed (§6). If a HAT
> cannot sit on it, the HAT goes outside the case on a 40-pin GPIO ribbon cable, which is
> fine for the MVP.

### Powering the Pi

Feed the Pi through **USB-C from a 5 V buck converter**, not through the GPIO 5 V pins.
The USB-C input has the Pi's own fuse and protection; the GPIO pins bypass both.

The buck must deliver **≥ 3 A at 5.0–5.2 V**. The recommended part is Electrokit's
**EKM006** module (TI LMR14050, 4–40 V in, 5 A out, 5 V by jumper, measured 5.15 V,
149 SEK, in stock). It has headroom for the Pi plus the fans plus a micro-USB-powered
fallback screen. A screw-terminal-to-USB-C cable or adapter connects it to the Pi.

The **under-voltage check**: after a few minutes under load, run `vcgencmd get_throttled`.
`throttled=0x0` is good. Anything else means the supply sags and must be fixed before
anything else, because a sagging supply produces faults that look like software bugs.

Expected draw is roughly 10–15 W total (Pi 3–6 W, panel unknown — **measure it**). At
12 V that is about 1.3 A, so a 3 A fuse fits. Measure the real figure on the bench.

The **regulatory point** for later: in the competition car the supply must come from the
ESS through the LV bus that safe state de-energises (Reg. 2.25.2, 2.28.1, see
`wiring.md` §3). A bench 12 V supply is fine for testing; a power bank is never fine in
the car.

---

## 3 Which screen for the MVP

| | Riverdi 7″ `RVT70HQHFWN00` | Riverdi 5″ `RVT50HSHFWN00` | AliExpress HDMI screen |
| :--- | :--- | :--- | :--- |
| Power | DC jack, **7–30 V, straight from 12 V** | DC jack 7–36 V **or USB-C** | Micro-USB 5 V, needs the buck's 5 V |
| Brightness | 1000 cd/m², readable in sun | 1000 cd/m² | Unknown, probably ~250–400 cd/m² |
| Resolution | 1024×600 (`--panel 7in`) | 800×480 (`--panel 5in`) | Check (`--panel` or plain fullscreen) |
| Mounting | **Metal frame included** | Not listed | Bare PCB |
| Brightness control | OSD menu, no software needed | External PWM only | Switch only |
| Connectors in a car | DC jack: locking-ish, can be swapped for a pigtail | DC jack or USB-C | Micro-USB: fragile under vibration |
| On hand | Yes | Yes | Yes |

**Recommendation: use the Riverdi 7″ for the MVP**, with the AliExpress screen as the
fallback. It is not more complex to wire than the AliExpress one: it is an HDMI cable
plus a DC jack, and the DC jack takes 12 V directly, which is exactly the "connect it to
our 12 V" setup wanted for the car. It also comes with a mounting frame and is readable
in daylight, which the AliExpress screen probably is not.

Fallback rule: **if the 7″ does not show a picture within an hour of bench work, switch
to the AliExpress screen** and move on. The dashboard's UI scales to either, so nothing
in the software changes. The only Riverdi-specific risk is EDID not offering 1024×600;
the fix is one line in `config.txt` (`display-hardware.md`, "Raspberry Pi bring-up
notes").

What to buy for it: a DC barrel plug pigtail matching the panel's jack (**size to be
confirmed**, §6), and a micro-HDMI-to-HDMI cable if the team's one is not available.

---

## 4 The CAN interface

### 4.1 Checking the modified MCP2515 board

Do these in order. Each step tests one more part, so the first failure points at the
fault. Steps A–D need only the Pi, the module, a multimeter and a 120 Ω resistor, so
**they can be done in the team room tomorrow**, before anything arrives.

**A. Visual and identity check (unpowered).**
- Read the chip's marking. SN65HVD230, 231 and 232 all work at 3.3 V. They are
  pin-compatible with the TJA1050 that was removed (1 D/TXD, 2 GND, 3 VCC, 4 R/RXD,
  5 Vref, 6 CANL, 7 CANH, 8 Rs/S).
- Look for lifted pins, solder bridges, and a discoloured board around the chip.
- Read the crystal: `8.000` = 8 MHz, `16.000` = 16 MHz. This goes into the overlay.

**B. Resistance checks (unpowered, multimeter).**
- VCC to GND: **not a short** (should read kΩ, not 0–10 Ω).
- CANH to CANL: **≈ 120 Ω** (the onboard terminator). 0 Ω means a bridge; open means the
  terminator is not connected through.
- **Pin 8 (Rs) to GND: ≈ 0 Ω.** This is the one that matters most. On the SN65HVD230 a
  high Rs puts the chip in standby, where it receives but **never transmits**. On most
  TJA1050 modules pin 8 is already tied to GND, so it should be fine, but check it.
  (SN65HVD232 has no Rs pin, so skip this for a 232.)

**C. SPI and controller: loopback.** Wire to the Pi (§2 pin table, VCC on **3.3 V**),
add the overlay with the right crystal, then follow `pi-setup.md` Stage 3 "Check that
Linux found it" and "Test the chip without using the wires (loopback)". Pass =
`MCP2515 successfully initialized` in `dmesg` and the frame echoed by `candump`.

This proves the Pi, SPI wiring, overlay and MCP2515. **It does not test the
transceiver**: in loopback the frames never leave the MCP2515.

**D. Transceiver, with only one node: the "nobody answers" test.** On a CAN bus, the
receiver acknowledges each frame. A node alone on a bus gets no acknowledgement, keeps
retransmitting, and its error counter climbs. How far it climbs tells whether the
transceiver works:

```bash
# normal mode, not loopback; a second 120 Ω across CANH/CANL at the far end of a short lead
sudo ip link set can0 down
sudo ip link set can0 type can bitrate 500000
sudo ip link set can0 up
cansend can0 402#0000F04200002041
ip -details -statistics link show can0
```

| Result | Meaning |
| :--- | :--- |
| `state ERROR-PASSIVE`, `berr-counter tx 128` (stays there) | **Transceiver works.** It drives the bus and reads its own bits back correctly; the only error is the missing acknowledgement, which stops counting at 128. |
| `state BUS-OFF`, or tx counter past 255 | The controller sees its own bits come back wrong: transceiver TX or RX path broken, or CANH/CANL shorted. |
| `state ERROR-ACTIVE`, counters at 0, nothing sent | The frame never left: check Rs (pin 8), VCC on the transceiver, and the TXD pad. |

While it is retransmitting, a multimeter across CANH–CANL reads a small DC voltage
(a few hundred mV, the average of the dominant bits); idle it reads ≈ 0 V. That is
the transceiver driving the bus.

**E. Two-node test, the real proof.** One node sends, another receives and acknowledges.
Pass = `candump` on each side shows the other's frames and both stay `ERROR-ACTIVE`.

Three ways to get a second node, cheapest first:
1. **The team's ESP32 motor-controller simulator** (`pi-setup.md` Stage 4), if it is in
   the room and has a transceiver.
2. **The backup HAT on the same Pi, as `can1`.** Two MCP2515s can share SPI0 with
   separate chip selects. Connect the HAT with jumper wires instead of plugging it on:
   its CS to **pin 26 (CE1)**, its INT to **pin 18 (GPIO24)**, power, ground and the three
   SPI lines shared. Add a second overlay line:
   ```
   dtoverlay=mcp2515-can1,oscillator=12000000,interrupt=24
   ```
   Join CANH–CANH and CANL–CANL, and check ≈ 60 Ω across them unpowered (both onboard
   terminators on). Then `candump can1` in one terminal and `cansend can0 …` in another,
   and the reverse.
3. The car's bus itself, once it is reachable (week 48).

**Verdict rule.** If A–D fail, or E fails twice with the wiring checked, stop debugging
the modified board and use the HAT. It costs 179 SEK; the time does not come back.

### 4.2 Which board in the car for the MVP

The hand-modified board with dupont leads is fine on the bench. In a car, loose jumper
wires and flying leads are the most likely failure. For the MVP, use whichever board
passes test E, and **secure every jumper with hot glue or heat shrink**. For the
competition car, a HAT soldered or screwed in place is the better answer
(`wiring.md` §5).

### 4.3 The backup CAN board

| Board | What it is | Price (Electrokit) | Overlay |
| :--- | :--- | :--- | :--- |
| **Waveshare RS485 CAN HAT** (recommended) | MCP2515 + **SN65HVD230**, the same 3.3 V design as the modified board. CAN screw terminal, 120 Ω by DIP switch. | **179 SEK**, 64 in stock, 1–3 weekdays | `oscillator=12000000,interrupt=25` (boards from before Aug 2019: 8 MHz). **Read the crystal.** |
| PiCAN3 (SK Pang) | MCP2515 + MCP2551, **6–24 V input with a 3 A 5 V supply for the Pi**, RTC, screw terminal or DB9, 120 Ω on board. | 1 399 SEK, 12 in stock, 1–3 weekdays | `interrupt=25`; crystal **check** (SK Pang boards are usually 16 MHz) |

The Waveshare HAT is the backup and the second node for test E. The PiCAN3 is the
option to consider for the car rather than the MVP: it would replace both the CAN board
and the buck converter with one board that takes 12 V directly. It is eight times the
price, and the buck plus HAT do the same job for the MVP.

Either board uses the same Linux driver as the modified module, so **the software does
not change**; only the `oscillator=` value in `config.txt` may. Update `wiring.md` §2
when the board in the car changes.

### 4.4 Connecting to the car's bus

- **Termination.** Exactly two 120 Ω on the whole bus, one at each physical end. Find out
  where the ends are (§6). If the dashboard is not an end, **turn its terminator off**
  (DIP switch on the HAT; on the modified module, lift the resistor or cut its jumper).
  Check ≈ 60 Ω across CANH–CANL with the car's LV off.
- **Stub.** Keep the drop from the backbone to the Pi short (under ~0.3 m at 500 kbit/s).
- **Ground.** Run the CAN ground (or the shield, per the team's convention) alongside
  CANH/CANL so the Pi and the bus share a reference.
- **Bitrate.** 500 kbit/s, same as every node. Confirm with the motor-controller and BMS
  owners.
- **Listen before you speak.** Bring the interface up in listen-only mode first, so a
  wrong bitrate cannot disturb the car's bus:
  ```bash
  sudo ip link set can0 type can bitrate 500000 listen-only on
  ```
  Then `candump -ta can0`. Only switch listen-only off once frames arrive cleanly.

---

## 5 Shopping list

Prices from Electrokit on 13 Nov 2026, incl. VAT. Electrokit states 1–3 weekdays
delivery: **an order placed tonight or this weekend ships Monday 16 Nov and should
arrive Tue 17 – Wed 18 Nov**, leaving all of weeks 47 and 48. Kjell & Company and Biltema
have stores, so their items can be picked up the same day.

### Order now (Electrokit, one order)

| # | Item | Why | Price | Before week 48? |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Waveshare RS485 CAN HAT | Backup CAN board, and the second node for test E | 179 SEK | Yes, 1–3 weekdays |
| 2 | DC/DC step-down 5 V 5 A, **EKM006** (×2, one spare) | 12 V → 5 V for the Pi | 2 × 142 SEK | Yes, 1–3 weekdays |
| 3 | 120 Ω resistors (a few) | Bench termination for tests D and E | ~10 SEK | Yes |
| 4 | Dupont jumper wires, F-F and M-F | CAN module and HAT wiring for test E | ~50 SEK | Yes |
| 5 | 40-pin GPIO ribbon cable (and a T-cobbler breakout, optional) | If the HAT cannot sit on the case (§2) | ~60–100 SEK | Yes |

### Pick up locally (Kjell / Biltema), once §6 answers are in

| # | Item | Why |
| :--- | :--- | :--- |
| 6 | Inline blade fuse holder + 3 A fuses | First thing after the 12 V tap |
| 7 | Automotive wire, 0.75–1 mm², red and black | 12 V and 5 V runs |
| 8 | DC barrel plug pigtail, **size matching the Riverdi jack** | Panel power from 12 V |
| 9 | USB-C plug to screw terminal / open-ended USB-C cable | Buck → Pi |
| 10 | Micro-HDMI to HDMI cable, 0.5–1 m | Only if the team's one is missing |
| 11 | Heat shrink, cable ties, WAGO 221 lever connectors | Securing and splitting |
| 12 | 12 V bench supply or 12 V ≥ 2 A adapter | Only if the team room has no lab supply |
| 13 | Spare microSD card, 32 GB | Pre-flashed spare; SD cards die on power cuts |

### Order Monday, once the connector is identified (Mouser / DigiKey / Farnell)

| # | Item | Why | Before week 48? |
| :--- | :--- | :--- | :--- |
| 14 | Housings and crimp pins for the team's 2×3 CAN connector | Plugging into the car the way the other PCBs do | Yes: these distributors typically deliver to Sweden in 2–3 working days |

If it is the common Molex Micro-Fit 3.0 2×3 (an educated guess, not confirmed), that is
a receptacle housing, a matching plug housing and loose crimp terminals. **Confirm the
team has the matching crimp tool**; the genuine one is expensive, and a wrong tool makes
unreliable crimps.

### Not ordering

- **AliExpress:** typical delivery to Sweden is longer than the two weeks available.
- **USB-to-CAN adapters at Electrokit** (Waveshare USB-CAN-A, USB-CAN-FD-B): neither page
  confirms they work as a native Linux SocketCAN interface, so they would not show up as
  `can1` for the dashboard or `candump`. A candleLight/gs_usb adapter would, and is a
  useful laptop sniffing tool later, but it is not needed for the MVP.
- **PiCAN3:** see §4.3. Worth revisiting for the competition car.

---

## 6 Open questions for the team room (Sat 14 Nov)

**CAN cable**
1. The purple cable: how many cores, and which colours? Is it CANH + CANL only, or does
   it carry a ground or 12 V too?
2. Is it twisted pair? Is the shield foil, braid, or both, and where is the shield
   grounded on the other PCBs (one end only, or both)?
3. What is written on the cable jacket? (Part number, impedance, usually 120 Ω for CAN.)

**Connector**
4. Photograph the 2×3 connector, both halves. Brand and series markings (Molex, JST,
   TE…) are usually moulded on the side. Measure the pin pitch (3.0 mm = Micro-Fit,
   4.2 mm = Mini-Fit, 2.54 mm = generic).
5. What is the pinout on the other PCBs? Which pins are CANH, CANL, GND, and are any
   carrying 12 V?
6. Is there a crimp tool for it in the room, and spare housings and pins?

**The bus**
7. Where are the two physical ends of the CAN backbone, and where are the two 120 Ω
   terminators? Measure CANH–CANL with the LV off: ≈ 60 Ω is correct.
8. Where on the backbone will the dashboard connect? Is it an end?
9. Bitrate: confirm 500 kbit/s with the motor-controller and BMS owners.
10. Which CAN IDs are still missing (gear, blinker/hazard, pedal)? Who owns each, and can
    any of them be on the bus by week 48? Remember the kernel filter (`wiring.md` §2):
    a new ID outside `0x400`–`0x41F`, `0x500`–`0x51F` or extended `0x100`–`0x107` is
    invisible until the filter is widened.

**12 V source**
11. Where does the 12 V come from in the car today: a DC-DC off the pack, or an auxiliary
    battery? (For the MVP either works. For BWSC it must be from the pack, Reg. 2.25.2.)
12. How much current is available on it, and is there a free fused output or a
    connector to tap into?
13. Is there a 12 V bench supply in the room for testing the harness?

**On the bench**
14. Is the micro-HDMI cable still there? Are both Riverdi panels there?
15. What size is the Riverdi DC jack? (Measure the plug diameter, or check the datasheet
    for the exact part number.)
16. Can a HAT plug on to the Pi with the Joy-it case closed, or is the header covered?
17. The SN65HVD chip's exact marking and the MCP2515 crystal marking (§4.1 A).
18. Is the ESP32 simulator in the room with a working transceiver (second node for
    test E)?

**Using the dashboard in the car**
19. How will someone switch between the driver screen and the debug screen in the car,
    with no keyboard? Options: a small USB keypad, a push button on a GPIO pin, or simply
    starting the Pi in a chosen mode. Decide before building the switch, because of the
    rule in §7.

---

## 7 Software for the MVP (after the hardware)

Hardware-first, so these start once the bench rig works, but stages 1–2 of `pi-setup.md`
need no hardware and can run in parallel.

### Must, by end of week 48

1. **Debug dashboard (new).** The car's only telemetry for now, so it has to show what is
   happening on the bus, not just pretty values. It replaces the current
   `DebugDashboard.qml`, which is unreadable and duplicates the alert logic (roadmap
   Known Issues). Contents:
   - every decoded value, with **its age** (time since the last frame), so a stale value
     is visible as stale;
   - per-source liveness: motor controller, BMS, and later lights, gear and pedal;
   - bus health: frames per second, error counters, bus state (`ERROR-ACTIVE` /
     `ERROR-PASSIVE` / `BUS-OFF`);
   - a short list of **recent raw frames by ID** (a small `candump` on screen), which is
     how missing IDs get found;
   - the values the race screen no longer shows but the backend still decodes (DSP
     board temperature, bus current, amp-hours, motor RPM). This turns the "dead
     plumbing" known issue into something useful.

   **The compliance rule still applies** (`CLAUDE.md` invariants, Reg. 2.25.1): speed,
   indicators, hazard and ESS warnings must stay visible while the car moves. So either
   the debug screen keeps a strip with those items, or it is only reachable when
   `backend.vehicleStopped`. For the MVP, the strip is the useful choice, because the
   point is debugging while driving.

2. **Real CAN tested.** Stage 2 (`vcan0`) now, then Stage 3 and 4 on the bench, then the
   car's bus in listen-only mode (§4.4).

3. **Starts by itself.** In the car there is no keyboard: the Pi must boot straight into
   the dashboard (`--kiosk`, autostart at boot). This is roadmap Stage 5 work, pulled
   forward because the MVP needs it.

4. **Remove leftover code that is not for BWSC.** The main candidate is **lap mode** (a
   circuit-racing feature: `L` key, lap delta, "LAP MODE" caption, `lapModeActive`,
   `targetDeltaTime`), already on the roadmap's Should list. A search finds no other
   iESC-specific code left after the refocus commit.

### Should, if time allows

- Read-only root filesystem, because the Pi loses power abruptly at every key-off.
  Until then, expect an occasional corrupted SD card and keep a pre-flashed spare (item 13).
- Measure the Pi + panel power draw on the 12 V side.

### Not for the MVP

BMS charge/discharge limits, ESS threshold values, panel choice for BWSC, enclosure and
mount design, read-only root. All stay on `roadmap.md`.

---

## 8 Timeline

| When | What |
| :--- | :--- |
| **Fri 13 Nov** | Place the Electrokit order (§5 items 1–5). |
| **Sat 14 Nov** | Team room: answer §6. Run §4.1 A–D on the modified board. Photograph the connector and cable. |
| Sun 15 Nov | Pick up Kjell/Biltema items (6–13) if stores are open; otherwise Monday. |
| **Mon 16 Nov** | Order connector housings/pins (item 14). Pi: finish Stage 1 and Stage 2 (`vcan0`). |
| Tue 17 – Wed 18 Nov | Electrokit order arrives. Bench: 12 V → buck → Pi, `vcgencmd get_throttled`. Riverdi panel on 12 V. Test E with the HAT. |
| Thu 19 – Sun 22 Nov (wk 47) | Debug dashboard. Kiosk autostart. Remove lap mode. Build the harness with the real connector. |
| Mon 23 – Wed 25 Nov (wk 48) | In the car: listen-only on the real bus, `candump`, then the dashboard. Note every ID seen. |
| Thu 26 – Sun 29 Nov (wk 48) | Fix what the real bus showed. Drive test. Buffer. |

---

## Where the truth lives

- **Pin assignments, overlay values, filter ranges:** `wiring.md` §2. Update it when the
  board in the car or a pin changes.
- **Step-by-step Pi and CAN bring-up:** `pi-setup.md`.
- **Panels:** `display-hardware.md` and Riverdi's datasheet for the exact part number.
- **Competition requirements for the installation:** `wiring.md` §3.
- **Prices and stock** above were read from Electrokit's product pages on 13 Nov 2026 and
  will drift. Check before ordering.
