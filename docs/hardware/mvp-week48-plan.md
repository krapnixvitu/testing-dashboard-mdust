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

### Status and decisions (updated Tue 24 Nov 2026)

These apply to the MVP only and supersede the options discussed further down. The
competition dashboard is a separate design.

| Topic | Decided / current state |
| :--- | :--- |
| People | Juan Garcia (lead), Sara Zrno. |
| Display | **Riverdi 7″ `RVT70HSHNWN00`.** The 5″ `RVT50HQHNWN00` is a spare, with no frame planned for it. |
| Display frame and bracket | **3D printed**, no other material. Size not known yet. |
| Pi and CAN HAT | The HAT connects to the Pi by the 40-pin flat cable (§5 items 9–10), and **both sit in one 3D-printed case** that holds them mounted and steady. The Pi stays in its Joy-it aluminium case with the fans, inside the 3D-printed one. Case design and size not known yet. |
| Parts | Electrokit order and the local parts (fuses, wire, heat shrink, cable ties) all received. |
| Spares | No spare Pi. |
| Where it is | Built at home until the week 48 delivery, then kept in ST Studio. |
| Subsystem folder | Teams: [Juan Production System / Dashboard](https://studentmdh.sharepoint.com/:f:/r/sites/MDUSolarTeam/Delade%20dokument/Juan%20Production%20System/Dashboard?d=wf01a78ed6836411080dc312dc58c9ecc&csf=1&web=1&e=c9A8Z6), holding the JuanPaper. |
| Meetings | None during the MVP; progress tracked in ClickUp. |
| CAN topology (24 Nov) | **Daisy chain:** every device has a CAN **in** and a CAN **out** connector, and the bus passes through each device. There are no stubs to a backbone. See §4.3. |
| CAN connector (24 Nov) | **Würth WR-MPC3**, 2×3, 3.00 mm pitch. The cable side uses receptacle housing `662006113322` with WR-MPC3 crimp contacts. Housings, male and female contacts are in ST Studio. |
| CAN cable (24 Nov) | **LAPP UNITRONIC BUS PB FD P `2170222`**, violet: one twisted pair (red, green), 0.25 mm² (24 AWG), aluminium foil plus tinned-copper braid. **No ground core.** It is a Profibus cable rated 150 Ω; CAN expects 120 Ω, which is acceptable over car-length runs at 500 kbit/s. Keep the terminators at 120 Ω. |
| CAN pinout (24 Nov) | The team's chart from Ludwig (VCU / telemetry), revised 20 Nov: §4.4. The dashboard follows the **VCU v2 ("rätt")** layout. Where the dashboard sits in the chain, and the questions in §4.4, are still open (ClickUp). |
| 12 V feed (24 Nov) | From the car's **fuse box** (about 8 fused outputs), not the inline holder. The inline holder stays for the bench supply. One 3 A slot feeding a WAGO split works; two (panel and buck separately) is better if slots are free. Asked of Valentina. |

---

## 1 What is on hand today

| Item | Status |
| :--- | :--- |
| Raspberry Pi 4 Model B (2 GB) | Boots Raspberry Pi OS. Dashboard bring-up at Stage 1 (`pi-setup.md`). |
| Joy-it aluminium "armor" case, two fans | Fitted. Fans take **5 V and GND from the GPIO header**; nothing else uses GPIO. |
| MCP2515 module, TJA1050 swapped for an SN65HVD23x | Hand-modified, **never tested**. **Not on the MVP path**: the Waveshare HAT is used instead (§4). Test it later (Appendix A). |
| Riverdi 7″ `RVT70HSHNWN00` and 5″ `RVT50HQHNWN00`, **frameless** | Bought (`display-hardware.md`). The 7″ is the MVP display; the 5″ is a spare. |
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

The fans and the CAN HAT share the header without conflict. The HAT takes these pins
through its own header; the table is what to check if it is wired by hand (on a ribbon
or with jumper wires).

| Pin | Used by | Notes |
| :--- | :--- | :--- |
| 4 | Fan + (5 V) | Already wired |
| 6 | Fan − (GND) | Already wired. If wiring the CAN board by hand, use another GND (9, 14, 20 or 25) |
| 1 or 17 | CAN board VCC, **3.3 V** | Never 5 V: the Pi's GPIO is not 5 V tolerant |
| 9 / 14 / 20 / 25 | CAN board GND | |
| 19, 21, 23 | MOSI, MISO, SCLK (SPI0) | |
| 24 | CS (CE0) | |
| 22 | INT (GPIO25) | Matches `interrupt=25` in the overlay |

> **The case and a HAT.** The Joy-it armor case covers the top of the board. Check in the
> team room whether the GPIO header is reachable with the case closed (§6). If a HAT
> cannot sit on it, the HAT goes outside the case on a 40-pin GPIO ribbon cable, which is
> fine for the MVP.
>
> **Decided (19 Nov):** the HAT goes on the ribbon, and the Pi and HAT share one
> 3D-printed case so the HAT is held in place. The Pi keeps its Joy-it case inside it.

### Powering the Pi

Feed the Pi through **USB-C from a 5 V buck converter**, not through the GPIO 5 V pins.
The USB-C input has the Pi's own fuse and protection; the GPIO pins bypass both.

The buck must deliver **≥ 3 A at 5.0–5.2 V**. The recommended part is Electrokit's
**EKM006** module (TI LMR14050, 4–40 V in, 5 A out, 5 V by jumper, measured 5.15 V,
149 SEK, in stock). It has headroom for the Pi plus the fans plus a micro-USB-powered
fallback screen. **Fit the VSEL jumper**: open gives 3.3 V, shorted gives 5 V. Check the
output with a multimeter before the Pi is connected. The module ships with its screw
terminals unsoldered.

A **3 A-rated USB-C lead** connects it to the Pi: Electrokit's "USB-C to 5.5×2.1 mm DC
plug, 5 V 3 A" adapter cable, with the DC plug cut off and the two wires screwed into the
buck, shortened to about 30 cm. The page's warning that it is limited to 500 mA applies
only to USB-PD chargers, which need resistors to negotiate; a buck converter just
supplies 5 V and the Pi draws what it needs. (Electrokit's open-end USB-C cables are
rated 2 A, so they are not used.)

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

| | Riverdi 7″ `RVT70HSHNWN00` | Riverdi 5″ `RVT50HQHNWN00` | AliExpress HDMI screen |
| :--- | :--- | :--- | :--- |
| Power | DC jack 5.5 × 2.1 mm, **7–30 V, straight from 12 V** | DC jack 7–36 V **or USB-C** | Micro-USB 5 V, needs the buck's 5 V |
| Brightness | 1000 cd/m², readable in sun | 1000 cd/m² | Unknown, probably ~250–400 cd/m² |
| Resolution | 1024×600 (`--panel 7in`) | 800×480 (`--panel 5in`) | Check (`--panel` or plain fullscreen) |
| Mounting | No frame: 3D-printed frame (decided) | No frame | Bare PCB |
| Brightness control | OSD menu, no software needed | External PWM only | Switch only |
| Connectors in a car | DC jack: locking-ish, can be swapped for a pigtail | DC jack or USB-C | Micro-USB: fragile under vibration |
| On hand | Yes | Yes | Yes |

**Recommendation: use the Riverdi 7″ for the MVP**, with the AliExpress screen as the
fallback. It is not more complex to wire than the AliExpress one: it is an HDMI cable
plus a DC jack, and the DC jack takes 12 V directly, which is exactly the "connect it to
our 12 V" setup wanted for the car. It is also readable in daylight, which the
AliExpress screen probably is not.

**Mounting for the MVP.** Both Riverdi panels are frameless. **Decided (19 Nov): the frame
and bracket are 3D printed.** They must hold the panel by its edges or mounting points rather than by the glass, leave
the HDMI and DC connectors reachable with strain relief, and leave air around the back.
**Do not let the frame block the MVP**: bench testing and the first in-car test can run
with the panel temporarily secured. The competition mount is a separate design (crash
and vision rules, `wiring.md` §3) and benefits from the MVP showing where the panel
actually has to sit.

Fallback rule: **if the 7″ does not show a picture within an hour of bench work, switch
to the AliExpress screen** and move on. The dashboard's UI scales to either, so nothing
in the software changes. The only Riverdi-specific risk is EDID not offering 1024×600;
the fix is one line in `config.txt` (`display-hardware.md`, "Raspberry Pi bring-up
notes").

What to buy for it: a **5.5 × 2.1 mm** DC barrel plug pigtail (from the 7″ datasheet:
pin 1 VDD, pin 2 GND), and a micro-HDMI-to-HDMI cable if the team's one is not available.

---

## 4 The CAN interface

**Decision (13 Nov): the MVP uses the Waveshare RS485 CAN HAT**, ordered new. The
hand-modified MCP2515 board is set aside: testing it is not worth the time under week 48
pressure. Its test procedure is kept in Appendix A for later.

### 4.1 The Waveshare RS485 CAN HAT

MCP2515 controller + **SN65HVD230** transceiver, 3.3 V logic, CAN on a screw terminal,
120 Ω terminator switched by a DIP switch. Same Linux driver as the old module, so **the
software does not change**; only `config.txt` does:

```
dtparam=spi=on
dtoverlay=mcp2515-can0,oscillator=12000000,interrupt=25,spimaxfrequency=2000000
```

**Read the crystal first.** Current boards have 12 MHz; boards made before August 2019
had 8 MHz (`oscillator=8000000`). A wrong value gives a wrong bitrate, silently.

Update `wiring.md` §2 (crystal value) once the HAT is in use.

### 4.2 Bring-up, in order

1. **Driver and SPI.** `dmesg | grep -i mcp` shows `MCP2515 successfully initialized`.
2. **Loopback.** `pi-setup.md` Stage 3, "Test the chip without using the wires". Proves
   Pi, SPI, overlay and controller.
3. **Second node.** The real test needs another node that acknowledges frames: the
   team's ESP32 motor-controller simulator if it has a working transceiver
   (`pi-setup.md` Stage 4), or the car's bus itself in listen-only mode (§4.3).

That is the whole list. The HAT is a known-good, purpose-built board, so if steps 1–2 pass
the remaining risk is the wiring and the bitrate, which step 3 settles.

### 4.3 Connecting to the car's bus

**The bus is daisy-chained (decided 24 Nov).** Each device has an **in** and an **out**
connector with the same pinout, wired straight through: CANH in ↔ CANH out, CANL in ↔
CANL out, GND in ↔ GND out. The device taps the bus at that point. This is still one
continuous bus, electrically the same as a backbone, so the termination rule does not
change.

**Proposed build: a small pass-through board** (perfboard / stripboard), not a cable
splice.

```
  previous device ──► [WR-MPC3 IN] ══ CANH / CANL / GND ══ [WR-MPC3 OUT] ──► next device
                      └──────────── pass-through board ────────────┘
                                           │
                                           │  short twisted pair + GND, < ~0.3 m
                                           ▼
                         Waveshare HAT screw terminal (CAN_H, CAN_L); GND to the Pi
```

- Two **PCB-mount WR-MPC3 headers** (the in and out) soldered to the board, matching
  pins joined by short solder bridges or wire links. The car's cables plug into them with
  crimped receptacle housings, like the other subsystems. Match the board connectors'
  gender to what the other subsystems use, so any cable fits any device.
- One short twisted pair from the board to the HAT's **CAN_H / CAN_L** screw terminal
  (ferrules on the wire ends; not the RS485 A/B terminals). The HAT has no CAN ground
  terminal, as far as is known: take the bus GND to the Pi's ground (common GND WAGO, or
  a GND pin on the ribbon's pin header). Check the HAT's terminal labels.
- Why a board rather than splicing: the in/out connectors are held mechanically instead
  of hanging on wires, the pass-through stays intact if the dashboard lead is unplugged,
  and a terminator jumper can live on the board if the dashboard ever becomes a chain end.
- **Shield:** the cable has no ground core, so CAN ground goes either through the shield
  or a separate wire. Follow the harness team's convention, and ground the shield at one
  end only unless that convention says otherwise. **Ask Valentina.**
- **Polarity:** CANH to CANH all the way. A swapped pair gives no frames and no error.

- **Termination.** Exactly two 120 Ω on the whole bus, one at each end of the chain. The
  dashboard is a chain end only if nothing plugs into its out connector. If it is not an
  end, **turn the HAT's terminator off** (DIP switch).
  Check ≈ 60 Ω across CANH–CANL with the car's LV off.
- **Stub.** The only stub is the lead from the pass-through board to the HAT: keep it
  short (under ~0.3 m at 500 kbit/s).
- **Bitrate.** 500 kbit/s, same as every node. Confirm with the motor-controller and BMS
  owners.
- **Listen before you speak.** Bring the interface up in listen-only mode first, so a
  wrong bitrate cannot disturb the car's bus:
  ```bash
  sudo ip link set can0 type can bitrate 500000 listen-only on
  ```
  Then `candump -ta can0`. Only switch listen-only off once frames arrive cleanly.

### 4.4 The team's CAN pinout (WR-MPC3 2×3)

Source: Ludwig's crimp chart "Krimpning av kablage", revised 2026-11-20, saved as
[`can-crimp-chart.png`](can-crimp-chart.png). It is drawn **from the cable side** (where
the crimp contacts are pushed in), **latch up**; the small numbers are the board's pin
numbers.

**Correct layout ("rätt", VCU v2, Prohelion)**, cable side, latch up:

| | left | middle | right |
| :--- | :--- | :--- | :--- |
| **Top row (latch side)** | 6 · Shield earth, tied to net GND (bare) | 5 · **CAN-L** (blue) | 4 · **CAN-H** (white) |
| **Bottom row** | 3 · Shield (bare) | 2 · **GND** (black) | 1 · **+12 V** (red) |

A variant **without +12 V / GND** leaves pins 1 and 2 empty.

**The telemetry and logger boards (printed) are mirrored left–right**, a design error on
those boards: there, pin 6 is CAN-H, pin 4 is shield earth, pin 3 is +12 V and pin 1 is
shield. A cable crimped the same at both ends would therefore put **+12 V onto a shield
pin** and swap CAN-H with shield earth. **A cable end that plugs into a telemetry or
logger board must be crimped mirrored**, following the "speglad" panels of the chart.
Their 2-pin 12 V connector is reversed the same way.

**What this means for the dashboard:**

- Lay out the pass-through board to the **"rätt" (VCU v2)** pinout on both the in and the
  out header. Then a cable to the VCU is straight, and only a cable end that goes into a
  telemetry or logger board is crimped mirrored, as for every other device.
- Join **all six pins** straight across, in ↔ out, so +12 V, GND and both shield pins
  pass through to the next device even though the dashboard taps only CAN-H, CAN-L and
  GND. The dashboard is powered from the fuse box, not from pin 1.
- Take the board's header **pin 1 from Würth's PCB footprint**, never from looking at the
  cable side. The chart is the cable-side view, and a footprint read from it comes out
  mirrored: exactly the telemetry boards' mistake.
- Before the first plug-in, check with a multimeter that pin 1 (+12 V) has no
  continuity to any other pin, and that CAN-H/CAN-L land on the HAT's CAN_H/CAN_L.

**Pins 1–2 (+12 V, GND)** carry the chain's 12 V to the devices that need it (most likely
the WaveSculptor 22, which takes its 12 V supply through its CAN connector). The dashboard
passes them through untouched and does not draw from them.

**The cable is unchanged.** The shielded LAPP cable still runs between devices
(previous device → dashboard IN, dashboard OUT → next device). The board only replaces
the joint inside the dashboard, and the lead from the board to the HAT is a few
centimetres of twisted wire.

**Still open** (ClickUp task "CAN pinout"):

1. Board gender: look at what is soldered on the VCU board (pins or sockets) and use the
   same on the dashboard board.
2. WR-MPC3 PCB headers (2×3) and a crimp tool, both expected to be in ST Studio.
3. Which LAPP core is CAN-H. The chart's white/blue come from another cable. (Profibus
   convention makes red the "+" line, suggesting red = CAN-H, green = CAN-L; confirm.)
4. Where the dashboard sits in the chain, which two devices are the ends with the 120 Ω
   terminators, and the bitrate (500 kbit/s expected). Ask Valentina and Ludwig.

---

## 5 Shopping list

> **Status (19 Nov):** everything below except item 14 has been received.

Prices from Electrokit on 13 Nov 2026, incl. VAT. Electrokit states 1–3 weekdays
delivery: **an order placed tonight or this weekend ships Monday 16 Nov and should
arrive Tue 17 – Wed 18 Nov**, leaving all of weeks 47 and 48. Kjell & Company and Biltema
have stores, so their items can be picked up the same day.

### Order now (Electrokit, one order)

Every link below has been checked against what the plan needs.

| # | Item | Qty | Price | Notes |
| :--- | :--- | :--- | :--- | :--- |
| 1 | [RS485 CAN HAT for Raspberry Pi](https://www.electrokit.com/en/rs485-can-bus-hat-for-raspberry-pi) (Waveshare) | 1 | 179 SEK | The CAN board for the MVP (§4). |
| 2 | [DC/DC step-down 3.3 V/5 V 5 A](https://www.electrokit.com/en/dcdc-omvandlare-step-down-3.3v/5v-5a) (EKM006) | 2 | 2 × 142 SEK | 12 V → 5 V for the Pi; one spare. Fit the 5 V jumper (§2). |
| 3 | [HDMI cable, HDMI to micro-HDMI, 1 m](https://www.electrokit.com/hdmi-kabel-hane-micro-hane-1m-svart) | 1 | 69 SEK | Micro-HDMI (type D) to full-size HDMI, correct for the Pi 4. |
| 4 | [DC cable 2.1/5.5 mm male to open end, 2 m, red/black](https://www.electrokit.com/dc-kabel-2.1/5.5mm-hane-till-open-end-2m-svart/rod) | 1 | 22 SEK | Panel power from 12 V. 3 A max. Coil the spare length for now; cut it for the car. **Check polarity with a multimeter**: centre should be + (datasheet pin 1 VDD). The [0.3 m version](https://www.electrokit.com/dc-kabel-2.1/5.5mm-30cm-oppen-anda) is equally fine if in stock. |
| 5 | [Adapter cable USB-C to 5.5×2.1 mm DC plug, 5 V 3 A](https://www.electrokit.com/adapterkabel-usb-c-till-5.5x2.1mm-dc-plugg-5v-3a) | 2 | 2 × 55 SEK | Buck → Pi. Cut the DC plug off, screw the wires into the buck, shorten to ~30 cm (§2). Centre pin is +, so the wire to the centre is +. One spare. |
| 6 | [WAGO 221-413, 3-pole](https://www.electrokit.com/en/skarvdon-3-pos-0.2-4mm2-wago) | 6 | 6 × ~8 SEK | Split 12 V + and GND to panel and buck; spares. 0.2–4 mm², 32 A. |
| 7 | [WAGO 221-415, 5-pole](https://www.electrokit.com/en/skarvdon-5-pos-0.2-4mm2-wago) | 2 | 2 × 15 SEK | A common ground point. |
| 8 | [Inline fuse holder, MINI/ATM blade, 10 A, with leads](https://www.electrokit.com/mini-atm-flatsakringshallare-med-kabel-10a) | 2 | 2 × 29 SEK | First thing after the 12 V tap. 1.31 mm² leads, IP54, no fuse included. One spare. |
| 9 | [Flat cable IDC 40-pin for Raspberry Pi GPIO, 200 mm](https://www.electrokit.com/flatkabel-40p-for-raspberry-pi-gpio-200mm) | 1 | 28 SEK | Only needed if the HAT cannot sit on the Joy-it case (§2), but cheap enough to order now. **Both ends are female**, so it needs item 10 to take the HAT. |
| 10 | [Pin header 2.54 mm 2×20, male](https://www.electrokit.com/stiftlist-2.54mm-2x20p) | 1 | 15 SEK | Plugs into the ribbon's far end so the HAT's female header has pins to sit on. Check pin 1 before fitting the HAT (§8). |

About 900 SEK in all. 120 Ω resistors are not on the list: the ones from an Arduino kit are fine (§8).

WAGO lever connectors are fine for the bench and the MVP. For the competition car,
crimped and locking connectors are the better choice (vibration, `wiring.md` §4).

### Pick up locally (Kjell / Biltema)

| # | Item | Why |
| :--- | :--- | :--- |
| 11 | **MINI (ATM)** blade fuses, **3 A** (violet) | For the holder in item 8. Must be the MINI size. Electrokit also sells them ([3 A MINI](https://www.electrokit.com/flatsakring-3a-32vdc-mini-atm-violett), ~3 SEK) |
| 12 | Automotive wire, 0.75–1 mm², red and black | 12 V runs to the WAGOs |
| 13 | Heat shrink, cable ties | Securing and strain relief |

Already on hand: a 12 V bench supply and spare microSD cards (team room), 120 Ω resistors (Arduino kit).

### CAN connector (resolved 24 Nov)

| # | Item | Why | Before week 48? |
| :--- | :--- | :--- | :--- |
| 14 | Housings and crimp pins for the team's 2×3 CAN connector | Plugging into the car the way the other PCBs do | **Not needed (24 Nov):** the connector is Würth WR-MPC3, and housings plus male and female contacts are in ST Studio |

**Confirm the team has a crimp tool for WR-MPC3 / 3.0 mm contacts**; pliers or a generic
tool make crimps that fail under vibration. The pass-through board (§4.3) also needs two
PCB-mount WR-MPC3 headers.

### Not ordering

- **AliExpress:** typical delivery to Sweden is longer than the two weeks available.
- **USB-to-CAN adapters at Electrokit** (Waveshare USB-CAN-A, USB-CAN-FD-B): neither page
  confirms they work as a native Linux SocketCAN interface. A candleLight/gs_usb adapter
  would, and is a useful laptop sniffing tool later, but it is not needed for the MVP.
- **PiCAN3** (1 399 SEK): CAN plus a 6–24 V supply for the Pi on one board. Worth
  revisiting for the competition car; the HAT plus the buck do the same job for the MVP.

---

## 6 Open questions for the team room (Sat 14 Nov)

> **Answered 24 Nov:** 1–5 (cable, connector and pinout, see the status table and §4.4),
> 11–12 (12 V from the fuse box), 14 (panel labels match). Questions 10 and 17 are handled in the
> software work. **Still open:** 6 (crimp tool), 7–9 (chain ends, where the
> dashboard sits in the chain, bitrate), 13, 15–16.

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

**On the bench**
13. Is the micro-HDMI cable still there? Are both Riverdi panels there?
14. Read the part-number label on the back of each Riverdi panel and confirm it matches
    `display-hardware.md` (frameless, 7″ `RVT70HSHNWN00`, 5″ `RVT50HQHNWN00`). The 7″
    jack should be 5.5 × 2.1 mm.
15. Can a HAT plug on to the Pi with the Joy-it case closed, or is the header covered?
16. Is the ESP32 simulator in the room with a working transceiver (second node for
    §4.2 step 3)?

**Using the dashboard in the car**
17. How will someone switch between the driver screen and the debug screen in the car,
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
   car's bus in listen-only mode (§4.3).

3. **Starts by itself.** In the car there is no keyboard: the Pi must boot straight into
   the dashboard (`--kiosk`, autostart at boot). This is roadmap Stage 5 work, pulled
   forward because the MVP needs it.

4. **Remove leftover code that is not for BWSC.** The main candidate is **lap mode** (a
   circuit-racing feature: `L` key, lap delta, "LAP MODE" caption, `lapModeActive`,
   `targetDeltaTime`), already on the roadmap's Should list. A search finds no other
   iESC-specific code left after the refocus commit.

### Should, if time allows

- Read-only root filesystem, because the Pi loses power abruptly at every key-off.
  Until then, expect an occasional corrupted SD card and keep a pre-flashed spare microSD card.
- Measure the Pi + panel power draw on the 12 V side.

### Not for the MVP

BMS charge/discharge limits, ESS threshold values, panel choice for BWSC, enclosure and
mount design, read-only root. All stay on `roadmap.md`.

---

## 8 Bench checklist — the one place to follow

Every check from this plan, in the order you meet them. Tick them off as you go. A failed
check is fixed before moving on, because each later step depends on the earlier ones.

### Before anything is connected

- [ ] **Buck output.** Fit the EKM006's VSEL jumper (open = 3.3 V, shorted = 5 V). Feed it
  12 V from the bench supply with nothing on its output: multimeter reads **5.0–5.2 V**.
- [ ] **USB-C lead.** Cut the DC plug off the adapter cable, find + with continuity (the
  wire to the plug's centre pin), screw it into the buck, shorten to ~30 cm. With 12 V on
  the buck, measure **5.0–5.2 V between VBUS and GND at the USB-C plug** (outer contacts of
  the plug are awkward; measuring at the buck end and checking continuity to the plug's
  shell for GND is enough).
- [ ] **Panel pigtail polarity.** On the DC pigtail, find which wire goes to the centre
  pin (continuity). Centre = **+12 V** (datasheet: pin 1 VDD). Mark it.
- [ ] **Fuse.** On the bench: 3 A MINI blade fuse in the inline holder, holder on the +
  lead, first thing after the 12 V source. In the car, the fuse box replaces the inline
  holder (status table).
- [ ] **120 Ω resistors** (only if building a bench bus). Measure one: anything from about
  114 to 126 Ω is fine. Ordinary ¼ W resistors are plenty: across a CAN bus they dissipate
  well under 0.1 W.

### Pi and panel on the bench supply

- [ ] Pi boots from the buck. Bench supply current noted: ______ A at 12 V.
- [ ] **Under-voltage.** With the dashboard running for a few minutes:
  `vcgencmd get_throttled` prints **`throttled=0x0`**.
- [ ] **Voltage at the Pi under load.** Multimeter on **GPIO pin 2 (5 V) and pin 6 (GND)**:
  **≥ 4.9 V**. If it is lower, shorten or thicken the USB-C lead.
- [ ] Riverdi panel on 12 V shows a picture. If not within an hour, swap to the AliExpress
  screen (§3).
- [ ] Panel resolution: the dashboard fills the screen with `--panel 7in` (or `5in`). If the
  7″ comes up at the wrong resolution, add `video=HDMI-A-1:1024x600M@60D` to
  `/boot/firmware/config.txt` (`display-hardware.md`).
- [ ] Total current with panel and Pi running: ______ A at 12 V (expect around 1–1.5 A).

### CAN HAT

- [ ] **If using the ribbon:** plug the ribbon on the Pi and the 2×20 pin header into its
  far end, **without the HAT**. Power the Pi and measure at the far end: **3.3 V at the
  position where the HAT's pin 1 lands, 5 V at pin 2**. Only then fit the HAT. Reversed,
  the HAT would get 5 V on its 3.3 V pin.
- [ ] Read the HAT's crystal: `12.000` → `oscillator=12000000`, `8.000` → `8000000`.
- [ ] `config.txt` overlay added (§4.1), reboot, `dmesg | grep -i mcp` shows
  `MCP2515 successfully initialized`.
- [ ] Loopback test passes (`pi-setup.md` Stage 3).
- [ ] Case fans still spin with the HAT fitted (pins 4 and 6).

### On the car's bus

- [ ] Pass-through board (§4.3): continuity CANH in ↔ CANH out ↔ HAT CAN_H, same for
  CANL and GND, and **no** continuity between CANH and CANL.
- [ ] Car LV off: **≈ 60 Ω across CANH–CANL**. The HAT's terminator DIP switch **off**
  unless the dashboard is a chain end.
- [ ] `listen-only on` first (§4.3), then `candump -ta can0` shows frames.
- [ ] Every ID seen written down (finds the missing gear / blinker / pedal IDs).
- [ ] Listen-only off; dashboard shows live values and a green CAN dot.

---

## 9 Timeline

| When | What |
| :--- | :--- |
| **Fri 13 Nov** | Place the Electrokit order (§5 items 1–5). |
| **Sat 14 Nov** | Team room: answer §6. Photograph the connector and cable. |
| Sun 15 Nov | Pick up Kjell/Biltema items (11–13) if stores are open; otherwise Monday. |
| **Mon 16 Nov** | Order connector housings/pins (item 14). Pi: finish Stage 1 and Stage 2 (`vcan0`). |
| Tue 17 – Wed 18 Nov | Electrokit order arrives. Bench: 12 V → buck → Pi, `vcgencmd get_throttled`. Riverdi panel on 12 V. HAT bring-up (§4.2). |
| Thu 19 – Sun 22 Nov (wk 47) | Debug dashboard. Kiosk autostart. Remove lap mode. Build the harness with the real connector. 3D-print the panel frame and bracket, and the Pi + HAT case. |
| Mon 23 – Wed 25 Nov (wk 48) | In the car: listen-only on the real bus, `candump`, then the dashboard. Note every ID seen. |
| Thu 26 – Sun 29 Nov (wk 48) | Fix what the real bus showed. Drive test. Buffer. |

---

## Appendix A — Testing the modified MCP2515 board (later, not on the MVP path)

The hand-modified board (TJA1050 removed, SN65HVD23x fitted) may have been overheated
while soldering. It is not needed for the MVP, but once the HAT works it is worth
testing: if it passes, it is a spare and a second bench node. Each step tests one more
part, so the first failure points at the fault.

**A. Look (unpowered).** Read the chip marking: SN65HVD230, 231 and 232 all work at
3.3 V and are pin-compatible with the TJA1050 (1 D/TXD, 2 GND, 3 VCC, 4 R/RXD, 5 Vref,
6 CANL, 7 CANH, 8 Rs). Look for lifted pins, bridges and a discoloured board. Read the
crystal (`8.000` / `16.000`).

**B. Measure (unpowered).** VCC to GND is not a short. CANH to CANL ≈ 120 Ω (onboard
terminator). **Pin 8 (Rs) to GND ≈ 0 Ω**: a high Rs puts the SN65HVD230 in standby, where
it receives but never transmits (the 232 has no Rs; skip this for it).

**C. Loopback.** Wire it as in §2 (VCC on **3.3 V**) and follow `pi-setup.md` Stage 3.
Proves SPI and the MCP2515, but not the transceiver.

**D. "Nobody answers" test, one node.** Normal mode, a second 120 Ω at the end of a short
lead, then `cansend can0 402#0000F04200002041` and `ip -details -statistics link show
can0`. A lone node gets no acknowledgement and keeps retrying:

| Result | Meaning |
| :--- | :--- |
| `ERROR-PASSIVE`, `berr-counter tx 128`, stays there | Transceiver works: the only error is the missing acknowledgement, which stops counting at 128 |
| `BUS-OFF` | It reads its own bits back wrong: transceiver path broken or CANH/CANL shorted |
| `ERROR-ACTIVE`, counters 0, nothing sent | The frame never left: check Rs, transceiver VCC, the TXD pad |

**E. Two nodes.** With the HAT as `can0` on the same Pi, wire the old module by jumper
wires as `can1`: its CS to **pin 26 (CE1)**, INT to **pin 18 (GPIO24)**, sharing power,
ground and the three SPI lines, plus
`dtoverlay=mcp2515-can1,oscillator=<its crystal>,interrupt=24`. Join CANH–CANH and
CANL–CANL (≈ 60 Ω across them unpowered), then `candump` on one and `cansend` on the
other, both ways.

---

## Where the truth lives

- **Pin assignments, overlay values, filter ranges:** `wiring.md` §2. Update it when the
  board in the car or a pin changes.
- **Step-by-step Pi and CAN bring-up:** `pi-setup.md`.
- **Panels:** `display-hardware.md` and Riverdi's datasheet for the exact part number.
- **Competition requirements for the installation:** `wiring.md` §3.
- **Prices and stock** above were read from Electrokit's product pages on 13 Nov 2026 and
  will drift. Check before ordering.
