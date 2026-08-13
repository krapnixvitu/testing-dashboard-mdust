# Concepts & Learning Reference

Explanations of the non-obvious ideas behind this project, written to be re-read
later after the details have faded. This is the "why it works" companion to
`implementation.md` (what the code does) and `pi-setup.md` (how to bring the
hardware up).

Contents:

1. [CAN identifier filters and masks](#1-can-identifier-filters-and-masks)
2. [Byte order on the WaveSculptor bus](#2-byte-order-on-the-wavesculptor-bus)

---

# 1. CAN identifier filters and masks

## What a filter is, and why we want one

CAN is a **broadcast** bus. There is no notion of sending a frame *to* a
particular node. Every node electrically receives every frame, and each node
decides for itself what to ignore.

So the Pi receives everything on the bus: the motor controller's telemetry, the
ECU's drive commands, button messages, BMS traffic, anything else anyone bolts on
later. The dashboard cares about a fraction of it.

A **filter** tells the Linux kernel which frames to hand up to our process.
Frames that fail the filter are dropped inside the kernel and our code never
learns they existed — no process wake-up, no copy into user space, no CPU spent.

We could instead accept everything and discard unwanted frames with an `if` in
our own code. That works, but it pays a wake-up and a context switch for every
frame on the bus, thousands of times a second, just to throw most of them away.
Filtering in the kernel is free by comparison.

The filter is installed in `src/SocketCanReader.cpp`, via `setsockopt` with
`CAN_RAW_FILTER`, immediately after the socket is created and before any frame is
read.

## The rule the kernel applies

Each filter entry is a pair: an identifier and a mask. For every arriving frame:

```
(received_id & mask) == (filter_id & mask)   →  accept
```

That single line is the whole mechanism. Everything below is just understanding
what `&` does to it.

## Bitwise AND is a stencil

`&` compares two numbers one bit at a time. It yields `1` only when *both* input
bits are `1`:

```
1 AND 1 = 1
1 AND 0 = 0
0 AND 1 = 0
0 AND 0 = 0
```

The useful consequence:

- ANDing a bit with `1` **keeps** it.
- ANDing a bit with `0` **erases** it to zero.

So the mask acts as a stencil laid over the identifier. Where the mask has `1`,
the original bit shows through and must match. Where the mask has `0`, the bit is
wiped out — and crucially it is wiped out on *both* sides of the comparison, so it
cannot influence the result. That is precisely what "don't care" means: not
"ignored by convention" but *arithmetically unable to matter*.

## Where our mask value comes from

Hex is used here for one reason: each hex digit is exactly 4 bits, so hex and
binary convert by inspection.

`CAN_SFF_MASK` is `0x7FF` — all 11 bits of a standard CAN identifier.

```
CAN_SFF_MASK = 0x7FF = 0111 1111 1111    (all 11 bits matter)
0x1F                 = 0000 0001 1111    (the bottom 5 bits)
~0x1F                = 1111 1110 0000    (~ inverts every bit)

0x7FF & ~0x1F        = 0111 1110 0000    = 0x7E0
```

So `CAN_SFF_MASK & ~0x1Fu` reads as: **keep the top 6 bits, ignore the bottom 5.**

Ignoring the bottom 5 bits is not arbitrary. The WaveSculptor addressing scheme
(see `WaveSculptor22_CAN_Protocol_Reference.md` §2) splits the 11-bit identifier
into a 6-bit device identifier and a 5-bit message identifier:

```
bits 10..5  →  which device
bits  4..0  →  which message from that device
```

Masking off the low 5 bits therefore means *"any message from this device"*. The
mask is not a numeric trick bolted on afterwards; it matches the structure the
protocol was designed with.

## Worked examples

Filter entry 0 uses `filter_id = 0x400`, `mask = 0x7E0`. First compute the
reference value that everything is compared against:

```
0x400  = 0100 0000 0000
mask   = 0111 1110 0000   AND
       ------------------
         0100 0000 0000  = 0x400     ← the reference
```

Now test arriving identifiers:

```
0x402  = 0100 0000 0010     (bus measurement)
mask     0111 1110 0000  AND
         0100 0000 0000  = 0x400  → matches reference → ACCEPT
```

```
0x41F  = 0100 0001 1111     (highest ID in the device's range)
mask     0111 1110 0000  AND
         0100 0000 0000  = 0x400  → ACCEPT
```

```
0x420  = 0100 0010 0000     (one past the range)
mask     0111 1110 0000  AND
         0100 0010 0000  = 0x420  → ≠ 0x400 → REJECT
```

Look at *why* `0x420` fails. The bit that changed sits inside the "must match"
region, so it survives the AND and breaks the equality. Bits below that region
get erased, which is exactly why all 32 identifiers from `0x400` to `0x41F`
collapse onto the same value and are accepted together.

## Is the mask AND or OR? Both, at different levels

This is the part that is easy to trip over:

- **Within a single filter entry** — bitwise AND with the mask, then compare the
  two results for equality.
- **Across multiple filter entries** — logical OR. A frame is accepted if it
  matches *any* entry.

We install two entries, one for the motor controller at `0x400` and one for the
driver-controls/ECU range at `0x500`. That is why `0x500` gets through:

```
0x500  = 0101 0000 0000
mask     0111 1110 0000  AND
         0101 0000 0000  = 0x500   → ≠ 0x400, entry 0 rejects
                                   → = 0x500, entry 1 accepts   → ACCEPT
```

## Why `candump` sees frames the dashboard ignores

`candump` opens its **own** socket with **no** filter, so it shows every frame on
the bus. The dashboard's socket has the filter above.

This is a genuinely useful debugging property, but it produces one confusing
symptom worth remembering:

> `candump` shows the frame, but the dashboard does not react to it.

That almost always means the identifier falls outside `0x400`–`0x41F` and
`0x500`–`0x51F`, so the kernel dropped it before the dashboard could see it.
There is no error and no log line, because from the process's point of view the
frame never happened.

**So when adding a new message, check its identifier lands inside one of the
accepted ranges.** If it does not, the filter must be widened or the frame will
be silently invisible forever.

---

# 2. Byte order on the WaveSculptor bus

## The `31..0` notation is a logical map, not a wire order

The protocol tables describe each field with a bit range such as `31..0` or
`63..32`. This is **not** the order bits travel down the wire. It is a map of the
64-bit payload:

- `31..0` (**low word**) occupies **bytes 0–3**
- `63..32` (**high word**) occupies **bytes 4–7**

So "Motor Velocity, bits 31..0" simply means motor velocity lives in the first
four bytes of the payload.

What physically happens on the wire is a separate matter, and the two conventions
run in opposite directions, which is the source of most confusion here:

- **Bits within a byte:** CAN transmits **most significant bit first**.
- **Bytes within the payload:** the WaveSculptor protocol sends **least
  significant byte first** (little endian).

So the transmission sequence for a value in bytes 0–3 is:

```
Byte 0 (bits 7..0)    sent first   (bit 7 before bit 6 ... before bit 0)
Byte 1 (bits 15..8)   sent second
Byte 2 (bits 23..16)  sent third
Byte 3 (bits 31..24)  sent fourth
```

The important practical point: **we never deal with individual bits.** The CAN
controller hardware handles bit-level ordering. Our code only ever sees whole
bytes in an array, so only the *byte* order matters to us.

## How little endian stores a float

An IEEE-754 single-precision float is 32 bits (4 bytes). The rule on a
little-endian CPU — Intel x86, and the ARM cores in the Pi and the ESP32 — is:

> The least significant byte is stored at the lowest memory address.

Take a motor velocity of exactly `42.0` rpm. As a 32-bit float that is
`0x42280000`:

- Most significant byte: `0x42`
- Least significant byte: `0x00`

A little-endian CPU writes it to memory lowest-address-first as:

```
address +0:  0x00   ← least significant
address +1:  0x00
address +2:  0x28
address +3:  0x42   ← most significant
```

## Why `memcpy` just works

Because the protocol sends the least significant byte first, the bytes land in the
frame array in this order:

```
frame.data[0] = 0x00   ← least significant
frame.data[1] = 0x00
frame.data[2] = 0x28
frame.data[3] = 0x42   ← most significant
```

Compare that with the memory layout above: **identical**. So copying the four
bytes straight into a float's storage produces the correct value with no
rearranging:

```cpp
std::memcpy(&motor_velocity_rpm, &frame.data[0], sizeof(float));
```

The CPU's natural in-memory layout happens to match the protocol's wire order, so
the copy is a no-op reinterpretation. Had the protocol sent the most significant
byte first, the same `memcpy` would read the bytes backwards and yield garbage
unless we swapped them by hand first.

This is a **coincidence of matching conventions, not a guarantee.** It holds only
because both the Pi and the ESP32 are little-endian. Our decoder therefore does
not rely on it: `readF32Le` in `src/WaveSculptorDecoder.cpp` assembles the four
bytes explicitly, shifting each into place, so it produces correct results on a
big-endian CPU too. Slightly more code, immune to being moved to different
hardware.

## Worked example: 120.0 V and 10.0 A

Encoding a Bus Measurement (`0x402`) reporting 120.0 V and 10.0 A.

**Step 1 — the number as bits.** IEEE-754 stores `120.0` as `0x42F00000`. It is
not readable as decimal digits; it is a sign bit, an exponent and a fraction
packed into 32 bits.

**Step 2 — split into bytes, most significant first:**

```
42  F0  00  00
```

**Step 3 — reverse, because little endian sends least significant first:**

```
00  00  F0  42
```

The same idea as writing a date as `08/08/2026` rather than `2026/08/08` —
identical information, different ordering convention.

**Step 4 — repeat for 10.0 A** (`0x41200000` → `00 00 20 41`) and place it in
bytes 4–7, per the protocol table where bus current is bits `63..32`:

```
byte:   0  1  2  3   4  5  6  7
       00 00 F0 42  00 00 20 41
       └─ 120.0 V ─┘└─ 10.0 A ─┘
```

**Step 5 — that is the injectable test frame:**

```bash
cansend can0 402#0000F04200002041
```

Sending this on a `vcan0` loopback should make the dashboard read 120.0 V, 10.0 A
and therefore 1200 W. It is the quickest end-to-end check that decoding works.

## The trap: struct field order is not byte order

`reference/esp32-simulator/protocol.hpp` declares its message structs with the
fields in the **opposite order to the wire**. For example `BusMeasurement`
declares `bus_current` first, yet the packing code puts `bus_voltage` in bytes
0–3.

This is systematic across that entire file — velocity, temperatures, phase
currents, odometer and voltage rails all do it. The reason is that the protocol
tables list the **high word first** (`63..32` at the top of each table, then
`31..0`), so transcribing a table top-to-bottom into a struct yields
`[high, low]`, while the wire is `[low, high]`.

**Consequence:** the `pack`/`unpack` functions with their explicit byte offsets
are the ground truth, *not* the struct field order. Copying a whole struct onto a
frame in one `memcpy` would silently swap the two fields, with no compiler
warning. Only field-by-field copying at stated offsets is correct.

## Where the truth lives

In descending order of authority:

1. **`docs/WaveSculptor22_CAN_Protocol_Reference.md`** — the spec as we
   understand it. Consult this when in doubt.
2. **`src/WaveSculptorDecoder.cpp`** — what the dashboard actually does. All six
   messages we decode have been checked against the reference and against the
   ESP32 simulator's packing functions.
3. **`reference/esp32-simulator/protocol.hpp`** — a copy of the ESP32 project's
   definitions, kept for reference only. Not compiled here, and liable to drift
   out of sync with the ESP32 project. Treat as a hint, verify against 1.
