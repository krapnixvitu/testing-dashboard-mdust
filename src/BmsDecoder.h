#pragma once

#include <cstdint>

// Lithium Balance n-BMS CAN decoding.
//
// Spec-of-record: docs/LithiumBalance_BMS_CAN_Reference.md, written from the
// configuration export in docs/CAN-Database-(DBC)-BMS.xlsx.
//
// Two things differ from the WaveSculptor, and both fail silently if forgotten:
//
//   * These are 29-bit EXTENDED identifiers, not standard 11-bit ones. The
//     kernel filter needs its own entry for them (see SocketCanReader).
//   * The payload is BIG endian (Motorola). The WaveSculptor is little endian,
//     so the two decoders read bytes in opposite directions.
namespace bms {

// Extended (29-bit) identifiers. Only the three frames the dashboard needs are
// decoded; 0x103 and 0x104 carry uptime and epoch counters and are ignored.
constexpr uint32_t kIdCellVoltages = 0x100;  // every 1000 ms
constexpr uint32_t kIdPackCurrent  = 0x101;  // every  900 ms
constexpr uint32_t kIdCellTemps    = 0x102;  // every 1100 ms

// The window the kernel filter must accept. Wider than the three IDs above so
// the filter mask stays a clean power of two; the decoder ignores the rest.
constexpr uint32_t kIdRangeFirst = 0x100;
constexpr uint32_t kIdRangeLast  = 0x107;

enum class FrameKind {
    Unknown,
    CellVoltages,
    PackCurrent,
    CellTemps,
};

struct DecodedFrame {
    FrameKind kind = FrameKind::Unknown;

    // CellVoltages (0x100)
    float cellVoltageMax = 0.0f;  // V, highest cell
    float cellVoltageMin = 0.0f;  // V, lowest cell

    // PackCurrent (0x101)
    float packCurrent = 0.0f;     // A, negative while charging

    // CellTemps (0x102)
    float cellTempMax = 0.0f;     // degC, hottest cell
    float cellTempMin = 0.0f;     // degC, coldest cell
};

// Decodes one Lithium Balance broadcast frame.
//
// Pure: depends only on its arguments, touches no I/O, holds no state. `data`
// must point to at least 8 bytes. `canId` is the 29-bit identifier with
// CAN_EFF_FLAG already stripped. Identifiers the dashboard does not consume
// return FrameKind::Unknown.
DecodedFrame decode(uint32_t canId, const uint8_t *data);

// True when `canId` is one of the broadcast identifiers this decoder consumes.
bool isBmsFrame(uint32_t canId);

} // namespace bms
