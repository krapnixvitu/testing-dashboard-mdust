#include "BmsDecoder.h"

namespace bms {
namespace {

// The configuration describes every signal as big endian (Motorola) and numbers
// its bits 63..0 across the payload, with bit 63 the most significant bit of
// byte 0. So the mapping from the export's bit ranges to byte offsets is:
//
//   bits 63..56 -> byte 0      bits 31..24 -> byte 4
//   bits 55..48 -> byte 1      bits 23..16 -> byte 5
//   bits 47..40 -> byte 2      bits 15.. 8 -> byte 6
//   bits 39..32 -> byte 3      bits  7.. 0 -> byte 7
//
// Assembled byte by byte rather than memcpy'd. Both the Pi and the dev machine
// are little endian, so a straight copy would read these backwards -- the exact
// mirror of why memcpy happens to work for the WaveSculptor.
uint16_t readU16Be(const uint8_t *p)
{
    return static_cast<uint16_t>((static_cast<uint16_t>(p[0]) << 8) | p[1]);
}

int32_t readI32Be(const uint8_t *p)
{
    const uint32_t raw = (static_cast<uint32_t>(p[0]) << 24)
                       | (static_cast<uint32_t>(p[1]) << 16)
                       | (static_cast<uint32_t>(p[2]) << 8)
                       |  static_cast<uint32_t>(p[3]);
    return static_cast<int32_t>(raw);
}

int8_t readI8(const uint8_t *p)
{
    return static_cast<int8_t>(*p);
}

// Raw counts to SI, from the scaling column of the configuration export:
//   cell voltage   0.1 mV per count -> 1e-4 V
//   pack current   0.01 mA per count -> 1e-5 A
//   temperature    1 degC per count, already signed
constexpr float kCellVoltsPerCount = 1.0e-4f;
constexpr float kPackAmpsPerCount  = 1.0e-5f;
constexpr float kSocPercentPerCount = 1.0e-2f;

} // namespace

bool isBmsFrame(uint32_t canId)
{
    return canId == kIdCellVoltages
        || canId == kIdPackCurrent
        || canId == kIdCellTemps;
}

DecodedFrame decode(uint32_t canId, const uint8_t *data)
{
    DecodedFrame out;
    if (!data)
        return out;

    switch (canId) {
    case kIdCellVoltages:
        // CELL_V_MAX_VAL bits 63..48 -> bytes 0-1
        // CELL_V_MIN_VAL bits 47..32 -> bytes 2-3
        // Bytes 4-7 carry CELL_V_AVG and PACK_V_SUM_OF_CELLS, unused here.
        out.kind = FrameKind::CellVoltages;
        out.cellVoltageMax = readU16Be(data + 0) * kCellVoltsPerCount;
        out.cellVoltageMin = readU16Be(data + 2) * kCellVoltsPerCount;
        break;

    case kIdPackCurrent:
        // PACK_I_MASTER bits 31..0 -> bytes 4-7. Bytes 0-3 are PACK_I_SHUNT;
        // master is the system reference current, so that is the one to use.
        out.kind = FrameKind::PackCurrent;
        out.packCurrent = readI32Be(data + 4) * kPackAmpsPerCount;
        break;

    case kIdCellTemps:
        // CELL_T_MAX_VAL      bits  7.. 0 -> byte 7
        // CELL_T_MIN_VAL      bits 23..16 -> byte 5
        // PACK_Q_SOC_TRIMMED  bits 63..48 -> bytes 0-1
        // Byte 6 is CELL_T_AVG, byte 4 CELL_V_MIN_ID_CELL, bytes 2-3 the signed
        // internal SoC (which ranges -300..+300 %, so it is not the one to use).
        out.kind = FrameKind::CellTemps;
        out.cellTempMax = readI8(data + 7);
        out.cellTempMin = readI8(data + 5);
        out.stateOfCharge = readU16Be(data + 0) * kSocPercentPerCount;
        break;

    default:
        break;
    }

    return out;
}

} // namespace bms
