# Display Hardware — the two Riverdi panels

Two HDMI displays have been bought for the car and the team has not yet decided which
one is the primary. They are **different resolutions**, and the dashboard is currently
built around one fixed size, so this decision has real consequences for the UI code.

This document records what each panel is, what differs, and what has to change in the
software depending on which one wins.

---

## A note on the part numbers

The part numbers first circulated internally had the size digits swapped between the two
codes. This was checked and corrected on 2026-09-03; the codes used below are the right
ones.

Riverdi's numbering is size-first (`RVT43` = 4.3″, `RVT50` = 5.0″, `RVT70` = 7.0″,
`RVT101` = 10.1″) and the field after it encodes resolution — `HS` for 800×480, `HQ` for
1024×600. So the size is readable directly off the code, which is what made the swap
easy to spot:

| Circulated as | Actually | |
| :--- | :--- | :--- |
| `RVT50HQHFWN00` | **`RVT70HQHFWN00`** | 7.0″, 1024×600 |
| `RVT70HSHFWN00` | **`RVT50HSHFWN00`** | 5.0″, 800×480 |

Worth knowing when reading older messages or a purchase order, which may still carry the
swapped versions.

---

## The two panels

| | **7″ panel** | **5″ panel** |
| :--- | :--- | :--- |
| Part number | `RVT70HQHFWN00` | `RVT50HSHFWN00` |
| Diagonal | 7.0″ | 5.0″ |
| Resolution | **1024 × 600** | **800 × 480** |
| Brightness | 1000 cd/m² | 1000 cd/m² |
| Panel type | IPS, full viewing angles | IPS, full viewing angles |
| Interface | HDMI, plug and play | HDMI, plug and play |
| Backlight PWM | **Internal *and* external** | External only |
| OSD menu | **Yes** — brightness, contrast, saturation, volume, language | Not listed |
| Power input | DC jack 7.0–30.0 V | DC jack 7.0–36.0 V **or USB-C** |
| Mounting | **Metal mounting frame** | Not listed |

Both are 1000 cd/m² IPS, which is the specification that matters most for this project:
the dashboard has to stay readable in direct sunlight at Zolder. Neither panel is a
compromise on that front, so the choice comes down to size, resolution and the three
differences below.

### Derived physical figures

Computed from the nominal diagonal and aspect ratio — not measured. Useful because the
resolution difference alone is misleading.

| | 7″ / 1024×600 | 5″ / 800×480 |
| :--- | :--- | :--- |
| Active area | ≈ 6.04″ × 3.54″ | ≈ 4.29″ × 2.57″ |
| Area | ≈ 21.4 in² | ≈ 11.0 in² |
| Pixel density | ≈ 170 PPI | ≈ 187 PPI |

The 7″ has **1.94× the physical area** but only **1.6× the pixels**, so its pixel
density is *lower*. This is the counter-intuitive part and it drives everything in the
next section.

---

## What this means for the dashboard

> **Resolved as of 2026-09-04.** The layout is now resolution-independent: every size
> is written against an 800×480 reference and multiplied by `RaceDashboard._uiScale`.
> Both panels render the same design at their own size, and the base proportions were
> enlarged at the same time because the original ones were too small to read in a moving
> car. **The panel choice no longer blocks UI work.** The analysis below is kept because
> it explains *why* the fix is a uniform scale rather than a per-panel layout.

### The 7″ panel will not look "too small" — it will look sparse

Because the 7″ is physically larger while being *less* dense, a fixed-pixel element
renders about 10 % **physically bigger** on it, not smaller:

| Element | On the 5″ | On the 7″ |
| :--- | :--- | :--- |
| Speed number (`font.pixelSize: 110`) | ≈ 15.0 mm tall | ≈ 16.5 mm tall |
| Side card (`width: 140`) | 0.75″ — **17.5 %** of screen width | 0.83″ — **13.7 %** of width |
| Footer (`height: 32`) | **6.7 %** of screen height | **5.3 %** of height |

Legibility is therefore fine, arguably better. The problem is **proportion**: every
fixed-pixel element occupies a smaller fraction of a canvas that has grown by 60 % in
pixels. The side cards get proportionally narrower, the footer gets proportionally
thinner, and the centre card — which is the one element that *does* stretch — absorbs
all 224 extra pixels of width and 120 of height as dead space around an unchanged speed
number.

Nothing breaks. It just stops looking designed.

### How the layout currently responds

`qml/RaceDashboard.qml` is anchor-based, not `Layout`-based, and it is partially
adaptive already:

- `leftCard` — **fixed** `width: 140`, anchored left, stretches top-to-bottom
- `centerCard` — anchored between the two side cards, so it **absorbs all slack**
- `rightCard` — **fixed** `width: 140`, anchored right
- `footer` — **fixed** `height: 32`, full width
- Every `font.pixelSize`, dot size (`8`), radius (`10`) and margin (`12`, `8`) is a
  fixed pixel constant

In kiosk mode `visibility: Window.FullScreen` overrides the declared 800×480, so the
window will correctly fill a 1024×600 panel and the anchors will resolve. The result is
a working screen with the proportions described above — usable for bring-up, not a
finished design.

---

## Three ways to support both

Listed with the recommendation first.

**1. Proportional sizing against the root window (recommended).** Replace the fixed
constants with expressions derived from the window size — side cards as a fraction of
width, footer as a fraction of height, font sizes scaled off a single reference. One
build, one QML tree, correct proportions on both panels, and it also stops the windowed
Windows dev view from being a special case. The work is concentrated in
`RaceDashboard.qml`, `SpeedGauge.qml`, `InfoBar.qml` and `TempBar.qml`, and it is
mechanical rather than architectural.

**2. A single scale factor.** Keep the 800×480 design, wrap it in an `Item` with
`scale: Math.min(width/800, height/480)`, and letterbox the remainder. Much less work
than option 1 and guarantees the design's proportions survive intact — but it wastes the
extra area rather than using it, and the letterbox bars are visible.

**3. Two builds.** Rejected. It doubles the QML that has to be kept in sync, and this
project already has one live example of what that costs — the duplicated alert
thresholds between `RaceDashboard.qml` and `DebugDashboard.qml`, which are a standing
known issue precisely because a change to one silently fails to reach the other.

**Option 1 was implemented on 2026-09-04**, together with a re-proportioning of the base
design — the original sizes were legible on a monitor but far too small to read in a
moving car. See `docs/implementation.md` §4 for how `_uiScale` and `px()` work.

---

## Two hardware differences worth planning around

### Backlight PWM — only the 7″ has internal control

The dashboard already has a day/night theme toggled by `M` (`qml/Main.qml`), but that
only changes the palette; it does not change actual panel brightness. A 1000 cd/m² panel
at full backlight at night is dazzling, so real brightness control is likely to be
wanted eventually.

- **7″** — supports **internal** PWM, and has an OSD menu for brightness. Internal means
  the panel can dim itself without the Pi driving anything, and the OSD gives a manual
  fallback with no software at all.
- **5″** — **external PWM only**. Dimming it under software control means driving a PWM
  line from a Pi GPIO and wiring it to the panel.

So brightness control is close to free on the 7″ and is a wiring-plus-code task on the
5″. Worth weighing if automatic day/night dimming is wanted.

### Power

Neither panel can be fed from the pack directly — bus voltage runs far above both input
ranges (the battery bar in `InfoBar.qml` is scaled 80 V to 150 V). A DC-DC converter is
required either way.

- **7″** — DC jack, 7.0–30.0 V.
- **5″** — DC jack, 7.0–36.0 V, **or USB-C**. The wider range gives more headroom, and
  USB-C is genuinely convenient for bench work: the panel can run off the same kind of
  supply as the Pi during development.

> **The USB-C advantage is bench-only.** iESC Reg. 2.26.2 requires the driver's display
> and instrumentation to be powered **from the main energy storage system**, not from a
> separate isolated battery. So in the car the panel is fed from a DC-DC off the traction
> pack whichever model is chosen; a USB power bank or the auxiliary battery is not a
> legal supply for it. See the regulations summary at the repo root.

The 7″ also ships with a **metal mounting frame**, which is a point in its favour for
the enclosure — the roadmap still lists the enclosure as undecided.

---

## Raspberry Pi bring-up notes

Both are plug-and-play HDMI, which is the easy path — no DSI ribbon, no display-specific
driver. The Pi 4 has two **micro**-HDMI ports, so a micro-HDMI-to-HDMI cable is needed;
this is the single most common thing to be caught out by (see `docs/pi-setup.md`
Stage 0).

**If the 7″ panel comes up at the wrong resolution**, the cause is EDID not offering
1024×600, which is a non-standard mode. These panels advertise plug-and-play and should
present correct EDID, so try it before changing anything. If it is wrong, force the mode
in `/boot/firmware/config.txt`. Raspberry Pi OS Bookworm uses the KMS driver, so the
modern form applies:

```
video=HDMI-A-1:1024x600M@60D
```

On an older, non-KMS setup the legacy equivalent is:

```
hdmi_group=2
hdmi_mode=87
hdmi_cvt=1024 600 60 6 0 0 0
hdmi_drive=2
```

> **Untested.** Neither has been tried on our hardware — the Pi is still at Stage 1 of
> bring-up. Verify and update this section once a panel is actually connected.

The 5″ at 800×480 is a standard mode and should need nothing.

---

## Open questions

- **Which panel is primary?** Undecided; this is the decision the document exists for.
- **Is automatic brightness control wanted?** If yes, it is materially cheaper on the 7″.
- **Does the enclosure design favour the 7″ metal mounting frame?** Enclosure is still
  open per `docs/roadmap.md`.

## Where the truth lives

1. **Riverdi's datasheet for the exact part number** — authoritative for anything
   electrical, and for confirming the input voltage ranges before a DC-DC is specified.
2. **`qml/Main.qml:7-8`** — the one place the dashboard's design resolution is declared.
3. **This document** — the comparison and the consequences, written from the
   specifications supplied by the team. The derived physical figures are computed, not
   measured.
