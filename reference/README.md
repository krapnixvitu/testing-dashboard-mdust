# Reference Material

Code and documents kept for reference only. **Nothing in this folder is compiled
into the dashboard.** None of it appears in `CMakeLists.txt`, and none of it is
included by any file under `src/`.

## `esp32-simulator/`

Copied from the `CAN_MotorController_Simulator` ESP32 project. Useful for seeing
how the other side of the bus builds and parses frames.

| File | What it is |
| :--- | :--- |
| `protocol.hpp` | WaveSculptor22 message structs plus `pack`/`unpack` helpers. |
| `can_driver.hpp` | ESP32 TWAI peripheral wrapper. Depends on ESP-IDF headers, so it cannot compile on the Pi at all. |
| `can_frame.hpp` | Minimal frame struct used by the two files above. |

### Two warnings

**This is a copy and it will drift.** The original lives in the ESP32 project. If
the two disagree, the ESP32 project wins for what the simulator actually
transmits, and `docs/WaveSculptor22_CAN_Protocol_Reference.md` wins for what the
real motor controller does. When a decode mismatch is suspected, check whether
this copy is simply stale before hunting for a bug in `src/`.

**Struct field order does not match wire byte order** throughout `protocol.hpp`.
The `pack`/`unpack` functions with their explicit byte offsets are authoritative,
not the order fields are declared in. See the byte-order section of
`docs/concepts.md` for why.

### One known discrepancy

`protocol.hpp` documents `motor_current_percent` as `0-100%`, but
`docs/WaveSculptor22_CAN_Protocol_Reference.md` §4 states percentages must be sent
as a float between `0.0` and `1.0`, and explicitly *not* as `100.0`. The reference
is believed correct. Worth confirming with whoever owns the ECU firmware, since
sending `100.0` where `1.0` was expected would be a full-scale command.
