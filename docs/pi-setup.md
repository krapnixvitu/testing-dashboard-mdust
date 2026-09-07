# Raspberry Pi Setup — Beginner Guide

Goal: get the dashboard running on a Raspberry Pi 4, reading real data from the
car's CAN bus.

This guide assumes no prior Linux or CAN experience and explains what each step
does and why. Work through the stages in order. **Each stage adds exactly one
new thing**, so when something breaks, the cause is whatever you just added.
That is the entire reason for doing it this way instead of wiring everything up
at once and hoping.

| Stage | What it proves | Hardware needed |
|---|---|---|
| 0 | Linux runs on the Pi | Pi + SD card |
| 1 | The dashboard builds and displays | + monitor |
| 2 | Our CAN software is correct | nothing extra |
| 3 | The CAN chip and wiring work | + MCP2515, SN65HVD230 |
| 4 | The full physical bus works | + a second CAN device |

Do not skip ahead to Stage 3. Stages 1 and 2 need no CAN hardware at all and
rule out every software fault first.

---

## Stage 0 — Get Linux running on the Pi

### What's happening

A Raspberry Pi has no built-in storage. It boots from a microSD card, and that
card must contain an operating system. **Raspberry Pi OS** is a version of Linux
(based on Debian) built for the Pi. "Installing the OS" means writing a complete
disk image onto the card — a process called *flashing*.

### What you need

- microSD card, 16 GB or larger, ideally class 10 / U1 or better
- An SD card reader on your Windows PC
- A monitor with HDMI — the Pi 4 uses **micro**-HDMI, so check your cable
- USB keyboard and mouse
- A good USB-C power supply, ideally the official 3 A one. Underpowered supplies
  cause random crashes that look convincingly like software bugs.

### Flash the card

1. Install **Raspberry Pi Imager** on Windows, from `raspberrypi.com`.
2. Insert the SD card.
3. In Imager, choose your device (Raspberry Pi 4), then the OS. Pick
   **Raspberry Pi OS (64-bit)**, the full version with desktop.
   - *64-bit* because the Pi 4 supports it and the Qt packages are built for it.
   - *With desktop* because the dashboard is a graphical app, and learning is
     much easier with a normal desktop available.
4. Before writing, open the **settings / customisation** screen (the gear icon).
   This is the biggest time-saver in the whole process:
   - **Hostname** — the Pi's name on your network, e.g. `solarpi`. You can then
     reach it as `solarpi.local` instead of hunting for an IP address.
   - **Username and password** — you will type these constantly.
   - **Wi-Fi name and password** — so it connects on first boot.
   - **Enable SSH** — explained below. Turn it on.
5. Write the card, put it in the Pi, and power up.

First boot takes a few minutes while it expands the filesystem.

### What SSH is, and why you want it

**SSH** (Secure Shell) lets you type commands on the Pi *from your Windows PC*.
That keeps the Pi's screen free for the dashboard, and — far more useful while
learning — lets you **copy and paste** commands from this guide instead of
retyping long ones on a Pi keyboard.

From Windows PowerShell:

```powershell
ssh yourusername@solarpi.local
```

Answer `yes` to the fingerprint prompt the first time, then enter your password.
The prompt changes to show the Pi's name, meaning you are now typing on the Pi.

A machine used with no monitor at all is called **headless**. We aren't fully
headless since the dashboard needs a screen, but SSH is still the easier way to
run commands.

### Update the system

Always the first thing on a new Linux install:

```bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

- **`apt`** is the package manager: it installs software from Debian's official
  servers. Think of it as a command-line app store.
- **`update`** refreshes the list of available software. It installs nothing.
- **`full-upgrade`** installs newer versions of what's already there.
- **`sudo`** means "run as administrator". System-wide changes need it.

---

## Stage 1 — Build and run the dashboard with fake data

### What this proves

That Qt, the compiler, the graphics stack and our code all work on the Pi
**before** CAN enters the picture. The app has a built-in simulator that
generates plausible fake data, so it runs happily with no CAN hardware at all.

### Install the tools

```bash
sudo apt install -y git cmake build-essential \
  qt6-base-dev qt6-declarative-dev qt6-svg-dev qt6-svg-plugins \
  qml6-module-qtquick qml6-module-qtquick-window qml6-module-qtquick-shapes
```

What each piece is for:

- **`git`** — downloads the source code and tracks changes.
- **`cmake`** — reads `CMakeLists.txt` and works out how to compile the project.
- **`build-essential`** — the C++ compiler and core build tools.
- **`qt6-base-dev` / `qt6-declarative-dev`** — Qt libraries and headers needed
  to *compile* against Qt and QML.
- **`qt6-svg-dev`** — headers/CMake config needed to *compile* against
  `Qt6::Svg`. Our blinker arrow icons (`ArrowIndicator.qml`) are SVGs loaded
  through a QML `Image`. Pulls in `libqt6svg6` (the `QSvgRenderer` library)
  as a dependency, but *not* the plugin below.
- **`qt6-svg-plugins`** — the *runtime* SVG image plugin
  (`imageformats/libqsvg.so`). This is the one that's easy to miss and is not
  a dependency of `qt6-svg-dev` or `libqt6svg6`: the app links and starts
  fine without it, but every `Image` pointed at an `.svg` file silently fails
  to render with `QML Image: Error decoding: ...: Unsupported image format`,
  because Qt has no plugin registered that knows how to decode SVG into a
  raster image.
- **`qml6-module-*`** — the QML pieces needed at *run time*. Our QML imports
  `QtQuick`, `QtQuick.Window` and `QtQuick.Shapes`. All three must be present or
  the app starts and immediately fails.
  - `QtQuick.Shapes` is required even though nothing it draws is currently
    visible. `SpeedGauge.qml` still *imports* it for the retired speed arc, and
    a missing import is fatal regardless of whether the elements are shown.

If it complains at startup about a missing QML module, find the package with:

```bash
apt search qml6-module | grep -i <module name>
```

> **Version note:** the Pi's Qt version comes from the OS release, not the board,
> so check it rather than assuming:
>
> ```bash
> qmake6 -query QT_VERSION
> ```
>
> **The car's Pi reports 6.8.2**, which means Raspberry Pi OS **Trixie**. (Bookworm,
> the previous release, ships 6.4.2 — if you flash an older image you get that
> instead, and anything below is worth re-checking before using a recent Qt feature.)
> The Windows dev machine has 6.10.1, so dev and target are two minor versions apart.
>
> What this permits: Qt 6.7 additions are safe. `PedalBar.qml` uses per-corner radius
> (`topLeftRadius`) and `font.features` for tabular figures, neither of which exists in
> 6.4. What it does not permit is assuming parity with the dev machine — Windows will
> still happily compile things the Pi cannot, so a Pi build remains the real check.

### Get the code and build it

```bash
git clone <your-repo-url> dashboard
cd dashboard
cmake -B build
cmake --build build
```

- **`cmake -B build`** is the *configure* step. It inspects the system, finds Qt,
  and generates real build instructions into a folder named `build`. Keeping
  output in its own folder means you can delete it and start fresh safely.
- **`cmake --build build`** is the *compile* step, producing the
  `SolarDashboard` program. This takes several minutes on a Pi. That's normal.

### Run it

The dashboard is a graphical app, so it has to draw on a screen. **Running it
straight from an SSH session fails**, because an SSH login is not attached to a
display:

```
qt.qpa.xcb: could not connect to display
qt.qpa.plugin: Could not load the Qt platform plugin "xcb" in "" even though it was found.
This application failed to start because no Qt platform plugin could be initialized.
```

Nothing is wrong with the build when this happens. Two ways round it.

**Either** open a terminal on the Pi's own desktop, using the monitor and
keyboard attached to it:

```bash
./build/SolarDashboard --simulate
```

**Or** stay on SSH and tell Qt to render on the Pi's attached screen:

```bash
DISPLAY=:0 ./build/SolarDashboard --simulate
```

`DISPLAY=:0` names the Pi's own display. Without it Qt looks for a screen in
your SSH session and finds none. This is the convenient one — you keep
copy-paste and a real keyboard, and the dashboard appears on the Pi.

If that reports `Authorization required`, the desktop session owns the display
and will not let a second login draw on it. Run `xhost +local:` once in a
terminal *on the Pi*, or just use the Pi's own terminal.

If Qt additionally complains that `xcb-cursor0 or libxcb-cursor0 is needed`,
install it: `sudo apt install -y libxcb-cursor0`. Not every image needs this.

`--simulate` forces the built-in fake data generator and skips CAN entirely.

Add `--kiosk` to run borderless and fullscreen instead of in a normal desktop
window:

```bash
./build/SolarDashboard --simulate --kiosk
```

This is the mode intended for the actual in-car display, since it covers the
Pi desktop's taskbar/panel instead of running alongside it. There is no window
chrome to close it with, so press `Esc` to quit. `--kiosk` changes the window's
frame and fullscreen state and **hides the mouse cursor** — there is no mouse in
the car, and a cursor parked on the display is just noise. It has no effect on
`--simulate` or `--can-interface`, so use whichever combination fits what you're
testing.

> If the Pi's desktop panel is still visible across the top with the dashboard
> squeezed underneath, check you are actually passing `--kiosk`. Without it the
> window is an ordinary desktop window and the panel keeps its space.

**Success looks like:** the dashboard appears with three rounded cards over a
dark footer. The large speed number in the middle rises and falls, and the
temperature and power values move.

Keys to try:

| Key | Expected |
|---|---|
| `M` | Whole screen switches between the dark night palette and the light day one |
| `→` `←` | Gear cycles D / N / R. In **N** the speed number is replaced by the team logo |
| `W` | Amber warning banner slides down from the top |
| `C` | Screen flashes red with "STOP VEHICLE IMMEDIATELY" |
| `D` | Switches to Debug mode |
| `Esc` | Quits (only wired up in `--kiosk` mode) |

> **Note on Debug mode:** it is a frozen pre-theme layout and most of its
> numbers currently render near-black on a near-black background, so it looks
> broken. That is a known issue, not something you have misconfigured. Press `D`
> again to return to Race mode.

Some readouts show `--` and the BMS dot is grey. That is correct and
intentional: those values come from a battery management system we have not
connected yet, and showing a plausible number for absent hardware is exactly the
failure mode we designed against.

Once this stage works, every remaining problem is CAN-related.

---

## Stage 2 — Fake CAN, still no hardware

### What CAN actually is

**CAN** (Controller Area Network) is the network vehicles use. The key ideas:

- It is **two wires** (CAN High and CAN Low) shared by every device.
- Every device hears every message. There are no addresses in the postal sense.
- Each message carries an **ID** (e.g. `0x402`) saying *what* it is, plus up to
  **8 bytes** of data.
- Devices ignore IDs they don't care about.

Our motor controller (a WaveSculptor22) broadcasts its measurements
continuously. The dashboard only listens; it never transmits.

### What vcan is

Linux can create a **virtual CAN interface** — a fake bus existing purely in
software. Nothing is wired up; the kernel just lets programs exchange frames
among themselves.

This is ideal now because it exercises our decoder, socket code, CAN filters and
every QML binding with **zero hardware risk**.

Linux treats CAN interfaces like network interfaces, which is why the commands
below look like networking commands.

```bash
sudo apt install -y can-utils

sudo modprobe vcan
sudo ip link add dev vcan0 type vcan
sudo ip link set vcan0 up
```

- **`can-utils`** — command-line CAN tools, notably `cansend` and `candump`.
- **`modprobe vcan`** — loads the virtual-CAN driver into the running kernel.
- **`ip link add ... type vcan`** — creates the fake interface, named `vcan0`.
- **`ip link set vcan0 up`** — switches it on.

Run the dashboard against it:

```bash
./build/SolarDashboard --can-interface vcan0
```

It shows no data and a red CAN dot, because nothing is transmitting yet. That's
expected. In a second terminal (SSH is handy here), send a frame:

```bash
# ID 0x402 is Bus Measurement: bus voltage, then bus current
# bytes 0-3 = 120.0 V, bytes 4-7 = 10.0 A, little-endian floats
cansend vcan0 402#0000F04200002041
```

**Success looks like:** bus voltage reads 120 V, current 10 A, power 1200 W, and
the CAN dot turns green. Stop sending and the dot returns to red after about
half a second — that is the watchdog noticing the bus went quiet.

Reading that frame: `402` is the ID, `#` separates, then 8 bytes of hex. The
numbers are IEEE-754 floats stored least-significant-byte-first, which is why
120.0 appears as `0000F042` rather than anything human-readable.

The BMS can be injected the same way, and this is the **only** check of the extended-ID
filter and the big-endian decoder short of a real pack:

```bash
# Eight hex digits before '#' make it an EXTENDED frame. With fewer, cansend
# emits a standard frame and the dashboard correctly ignores it.
# CELL_V_MAX = 37000 counts (0x9088) -> 3.700 V
# CELL_V_MIN = 36500 counts (0x8E94) -> 3.650 V
cansend vcan0 00000100#90888E9400000000
```

**Success looks like:** `PACK DELTA V` reads `0.050 V` and the BMS dot leaves grey. If the
readouts stay `--`, the kernel filter is wrong. If the numbers are wrong, the byte mapping
is. Stop sending and the pack readouts blank after about 3 s — the BMS has its own,
slower staleness timer than the CAN dot.

> `vcan0` vanishes on reboot. Re-run the three commands when you need it again.

---

## Stage 3 — Real CAN hardware

### What you're adding, and why there are two chips

The Pi has **no CAN hardware of its own**, so two separate parts are needed:

- **MCP2515 — the CAN controller.** Implements CAN's rules and timing. It talks
  to the Pi over **SPI**, a simple four-wire protocol for connecting chips to a
  computer.
- **SN65HVD230 — the CAN transceiver.** Converts the controller's logic-level
  signals into the actual differential voltages on the two bus wires, and back.

Controller = *what to say*. Transceiver = *how to physically say it*.

Shopping list:

- MCP2515 SPI CAN controller module
- SN65HVD230 3.3 V CAN transceiver
- 120 Ω termination at each physical end of the bus

### Why the module needs modifying

The common red **MCP2515 + TJA1050** module is a 5 V board. The TJA1050 needs
at least 4.75 V, so the whole module is designed to run at 5 V — and that is
the problem:

- At 5 V the MCP2515 drives its SPI output (`SO`) and `INT` at 5 V logic.
- Pi GPIO is 3.3 V and **not** 5 V tolerant.

Powering the module at 3.3 V instead is not a fix on its own: the MCP2515 is
happy (rated 2.7–5.5 V) but the TJA1050 is out of spec and the bus becomes
unreliable.

**Decision: desolder the TJA1050 and use the SN65HVD230 instead.** Both parts
then run at 3.3 V, which is the same combination commercial Pi CAN HATs use.

> **Status: done.** The TJA1050 has been removed and the SN65HVD230 fitted. The
> steps below are kept as a record of what was changed and as the reference for
> the wiring checks in Stage 3.

### Board modification

Remove the TJA1050 (an 8-pin surface-mount chip, package type SO-8). Once it's
gone, its solder pads give you access to the MCP2515's signals:

| TJA1050 pad | Signal | Connect to |
|---|---|---|
| 1 | TXD (from MCP2515 `TXCAN`) | SN65HVD230 `D` |
| 4 | RXD (to MCP2515 `RXCAN`) | SN65HVD230 `R` |
| 6 | CANL | SN65HVD230 `CANL`, or leave and use the transceiver's own pin |
| 7 | CANH | SN65HVD230 `CANH`, or leave and use the transceiver's own pin |

Power the SN65HVD230 from **3.3 V**, and feed the MCP2515 module **3.3 V**
rather than 5 V.

Reusing pads 6 and 7 keeps the module's screw terminal and its onboard 120 Ω
resistor in circuit. Skipping them means wiring CANH/CANL directly from the
SN65HVD230 board.

> Verify pad numbering against your board before cutting. Module layouts vary
> and the silkscreen is not always consistent.

### Wiring to the Pi

These are the **SPI** connections. SPI uses a clock line, two data lines (one
each direction) and a "chip select" line that says which chip is being addressed.
The Pi has two SPI buses; we use the first one, `SPI0`, with chip select `CE0`.

`INT` is separate from SPI: it's how the MCP2515 taps the Pi on the shoulder to
say "a message arrived", so the Pi doesn't have to keep asking.

| Module | Pi pin | Pi signal |
|---|---|---|
| VCC | 1 or 17 | **3.3 V** (not 5 V) |
| GND | 6 | GND |
| CS | 24 | GPIO8 / CE0 |
| SO | 21 | GPIO9 / MISO |
| SI | 19 | GPIO10 / MOSI |
| SCK | 23 | GPIO11 / SCLK |
| INT | 22 | GPIO25 |

`INT` must match the `interrupt=` value in the overlay below.

### Check the crystal before configuring

A **crystal** is the small silver component that gives the chip its clock. The
MCP2515 derives all CAN bit timing from it, so Linux must be told its exact
frequency or every calculated bit time will be wrong.

Read the marking on the metal can: `8.000` means 8 MHz, `16.000` means 16 MHz.
This value goes into the overlay below.

A wrong value does not produce an error. It produces a wrong actual bitrate,
and the symptom is silence or corrupt frames. This is the single most common
reason an MCP2515 setup appears dead.

### Telling Linux the chip exists

USB devices announce themselves when plugged in. **SPI devices cannot** — there
is no mechanism for it. So we have to describe the hardware to Linux by hand.

That description lives in the **device tree**: a map of attached hardware that
the Pi's firmware hands to Linux at boot. A **device tree overlay** is a small
patch to that map, saying "there is also an MCP2515 on SPI0, configured like
this".

**`config.txt`** is a plain text file the Pi's firmware reads *before Linux even
starts*, which makes it the right place for this. On Raspberry Pi OS Bookworm it
lives at `/boot/firmware/config.txt` (older releases used `/boot/config.txt`).

Open it in a terminal text editor:

```bash
sudo nano /boot/firmware/config.txt
```

Add these two lines at the end:

```bash
dtparam=spi=on
dtoverlay=mcp2515-can0,oscillator=8000000,interrupt=25
```

- **`dtparam=spi=on`** turns on the Pi's SPI hardware, which is off by default.
- **`dtoverlay=mcp2515-can0`** loads the overlay for an MCP2515, presented to
  Linux as an interface named `can0`.
- **`oscillator=`** is the crystal frequency from the previous section. Change
  `8000000` to `16000000` if yours is a 16 MHz crystal.
- **`interrupt=`** is the GPIO number the module's `INT` pin is wired to. It must
  match your wiring — 25 matches the table above.

In `nano`: `Ctrl+O` then `Enter` to save, `Ctrl+X` to exit. Then reboot:

```bash
sudo reboot
```

### Check that Linux found it

```bash
dmesg | grep -i mcp
```

`dmesg` prints the kernel's log of what happened during boot, and `grep` filters
it to lines mentioning our chip.

**Success looks like:** `mcp251x spi0.0 can0: MCP2515 successfully initialized.`

`Cannot initialize MCP2515. Wrong wiring?` means SPI isn't communicating. Check
the wiring and that `dtparam=spi=on` was saved correctly.

No output at all usually means the overlay line has a typo.

### Switch the interface on

```bash
sudo ip link set can0 type can bitrate 500000
sudo ip link set can0 up
```

**Bitrate** is how fast bits move on the bus, in bits per second. `500000` is
500 kbit/s, our car's bus speed. **Every device on a CAN bus must use the same
bitrate** — mismatched nodes simply cannot talk, and the errors look like faulty
wiring.

### Termination

At CAN speeds, a signal reaching the end of an unterminated wire **reflects back**
along it and corrupts following data. A 120 Ω resistor across the two wires at
each end absorbs the signal instead, preventing the reflection.

Exactly **two** 120 Ω resistors, one at each physical end of the bus. Not one,
not three.

Both the MCP2515 module and most SN65HVD230 boards ship with one fitted, so a
two-node bench setup can easily end up with the wrong number. Measure across
CANH and CANL with the bus unpowered: **≈60 Ω is correct**. 120 Ω means only
one terminator is present; 40 Ω means three.

### Test the chip without using the wires (loopback)

**Loopback** mode makes the MCP2515 hand its own transmissions straight back to
itself, so frames never reach the physical bus. This tests the Pi, SPI and the
controller while ignoring the transceiver, wiring and termination completely —
so a pass here narrows any remaining fault to the physical layer.

```bash
sudo ip link set can0 down
sudo ip link set can0 type can bitrate 500000 loopback on
sudo ip link set can0 up
```

In one terminal, watch the bus:

```bash
candump can0
```

In a second terminal, send a frame:

```bash
cansend can0 402#0000F04200002041
```

**Success looks like:** `candump` prints the frame you just sent. The module and
driver are working.

Then turn loopback off for normal use:

```bash
sudo ip link set can0 down
sudo ip link set can0 type can bitrate 500000
sudo ip link set can0 up
```

---

## Stage 4 — The real bus

The only stage that tests the physical layer: transceiver, wiring, termination
and true bitrate. It needs a second CAN device actually transmitting.

Your ESP32 `CAN_MotorController_Simulator` is ideal here. It broadcasts
WaveSculptor22 frames at base `0x400`, standing in for the real motor controller
until the car is available. To be clear about its role: it is a **bench signal
generator**, not part of the dashboard product.

Connect CAN High to CAN High and CAN Low to CAN Low between the two nodes, set
both to the same bitrate, and confirm termination is correct.

```bash
candump can0              # first: are frames arriving at all?
./build/SolarDashboard    # then: does the dashboard show them?
```

**Success looks like:** live values updating and a green CAN dot.

Always check `candump` before the dashboard. If frames aren't showing there, the
fault is in hardware and no software change will fix it.

---

## Troubleshooting

**Build fails at the linking step with `cannot open output file SolarDashboard:
Is a directory`.**

This is fixed in the CMake configuration, but you will hit it if you are on an
older checkout, and it is worth understanding because it only happens on Linux.

Our QML module URI is `SolarDashboard` and so is the executable target. Qt
generates the module's `qmldir` and `.qmltypes` into a directory named after the
URI, which by default lands at `build/SolarDashboard` — the exact path the linker
wants to write the binary to. On Windows the binary is `SolarDashboard.exe`, so
the names never collide and the build succeeds; on Linux there is no suffix, the
linker finds a directory sitting where its output file should go, and stops.

`CMakeLists.txt` now sets `OUTPUT_DIRECTORY` so the module is generated under
`build/qml_modules/SolarDashboard` instead.

If you already have a failed build tree, **the fix alone is not enough** — the
stale `build/SolarDashboard` directory is still on disk and will still block the
linker. Delete the build directory and start over:

```bash
rm -rf build
cmake -B build
cmake --build build
```

**The dashboard runs, but the turn signal arrows never appear, and the
terminal prints `QML Image: Error decoding: .../blinker-left.svg: Unsupported
image format`.**

Qt is missing the SVG image plugin. The blinker icons are `.svg` files loaded
through a QML `Image`, which decodes them via `QImageReader` — that requires
the `imageformats/libqsvg.so` plugin to be installed and discoverable at
run time, completely separately from whether the app itself links against
`Qt6::Svg` at build time. It's possible to build and launch the app
successfully with this plugin missing; only the SVG images fail, silently
falling back to nothing, with just the console warning to go on.

Install the runtime plugin package and relaunch (no rebuild needed):

```bash
sudo apt install -y qt6-svg-plugins
./build/SolarDashboard --simulate
```

Note this is a different package from `libqt6svg6`/`qt6-svg-dev` — installing
those alone is not enough, since neither depends on `qt6-svg-plugins`.

If you rebuilt from a checkout older than this fix, also reconfigure so the
app links `Qt6::Svg` and `qt6-svg-dev` is present to compile against it (see
Stage 1's install command above).

**`candump` shows frames but the dashboard ignores them.**
The message ID is probably outside the ranges we listen to. For efficiency, the
app asks the kernel to discard everything except standard `0x400`–`0x41F` (motor
controller), standard `0x500`–`0x51F` (driver controls) and **extended**
`0x100`–`0x107` (BMS). Frame format is part of the filter, so a standard frame at
`0x100` is rejected just as an extended one at `0x400` is. `candump` opens its own
unfiltered connection, so it sees *everything* regardless — which is exactly why
this symptom is so confusing. The frame really is arriving; we're deliberately
dropping it.

**Nothing arrives at all.**
Suspect the crystal/`oscillator` mismatch first: a wrong clock frequency means
the wrong bitrate, with no error message anywhere. Second suspect is the
`interrupt=` GPIO not matching where `INT` is physically wired.

**Error counters climbing.**

```bash
ip -details -statistics link show can0
```

Rising error counts usually mean a bitrate mismatch between nodes, or wrong
termination.

**The CAN dot in the footer is red.**
No frame has arrived for 500 ms. This is the watchdog working correctly — the
dashboard is telling you the bus went quiet, so investigate the bus, not the app.

**The dashboard runs but every value is fake or inert.**
It failed to open the CAN interface and fell back to the simulator. Look at the
startup messages in the terminal: it logs either `SocketCAN unavailable on this
platform` or the specific error from trying to open the interface.

**Missing QML module errors at startup.**
A `qml6-module-*` package is missing. `QtQuick.Shapes` is the easiest one to
overlook, because nothing it draws is visible any more — but `SpeedGauge.qml`
still imports it, and an unresolved import aborts startup.

## Command-line flags

- `--can-interface <name>` — interface to open, default `can0`
- `--simulate` — force the simulator and skip CAN entirely
