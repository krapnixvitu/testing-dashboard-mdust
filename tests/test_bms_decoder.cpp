// Frame decoding tests for the Lithium Balance BMS.
//
// The point of these is the byte placement. The BMS is big endian while the
// motor controller is little endian, and the configuration export describes its
// signals by bit range rather than byte offset -- so a mapping that is off by
// two bytes still decodes to plausible-looking numbers. Every case below states
// the expected bytes explicitly rather than round-tripping through a helper,
// so a wrong mapping fails here instead of on the car.

#include "../src/BmsDecoder.h"

#include <cmath>
#include <cstdint>
#include <cstdio>

namespace {

int g_failures = 0;
int g_checks = 0;

void check(bool condition, const char *what)
{
    ++g_checks;
    if (!condition) {
        ++g_failures;
        std::printf("  FAIL: %s\n", what);
    }
}

bool near(float a, double b, double tol = 1e-4)
{
    return std::fabs(static_cast<double>(a) - b) < tol;
}

void testCellVoltages()
{
    std::printf("Cell voltages decode big endian from bytes 0-3\n");

    // CELL_V_MAX_VAL bits 63..48 -> bytes 0-1, 0.1 mV per count.
    //   37000 counts = 3700.0 mV = 3.700 V, 37000 = 0x9088
    // CELL_V_MIN_VAL bits 47..32 -> bytes 2-3.
    //   36500 counts = 3650.0 mV = 3.650 V, 36500 = 0x8E94
    // Bytes 4-7 are CELL_V_AVG and PACK_V_SUM_OF_CELLS, which must be ignored.
    const uint8_t bytes[8] = { 0x90, 0x88, 0x8E, 0x94, 0xFF, 0xFF, 0xFF, 0xFF };
    const bms::DecodedFrame f = bms::decode(bms::kIdCellVoltages, bytes);

    check(f.kind == bms::FrameKind::CellVoltages, "kind is CellVoltages");
    check(near(f.cellVoltageMax, 3.700), "highest cell = 3.700 V");
    check(near(f.cellVoltageMin, 3.650), "lowest cell = 3.650 V");
}

void testPackCurrentDischarging()
{
    std::printf("Pack current decodes from bytes 4-7, not 0-3\n");

    // PACK_I_MASTER bits 31..0 -> bytes 4-7, 0.01 mA per count.
    //   1500000 counts = 15000.00 mA = 15.0 A, 1500000 = 0x0016E360
    // Bytes 0-3 hold PACK_I_SHUNT and must not be read: a decoder that took
    // the wrong half would report 0xFFFFFFFF here, i.e. about -0.00001 A.
    const uint8_t bytes[8] = { 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x16, 0xE3, 0x60 };
    const bms::DecodedFrame f = bms::decode(bms::kIdPackCurrent, bytes);

    check(f.kind == bms::FrameKind::PackCurrent, "kind is PackCurrent");
    check(near(f.packCurrent, 15.0, 1e-3), "pack current = 15.0 A");
}

void testPackCurrentCharging()
{
    std::printf("Pack current is signed, so charging reads negative\n");

    // -1500000 counts = -15.0 A. Two's complement of 0x0016E360 is 0xFFE91CA0.
    const uint8_t bytes[8] = { 0x00, 0x00, 0x00, 0x00, 0xFF, 0xE9, 0x1C, 0xA0 };
    const bms::DecodedFrame f = bms::decode(bms::kIdPackCurrent, bytes);

    check(near(f.packCurrent, -15.0, 1e-3), "charging current = -15.0 A");
}

void testCellTemperatures()
{
    std::printf("Cell temperatures decode from bytes 7 and 5\n");

    // CELL_T_MAX_VAL bits  7..0  -> byte 7
    // CELL_T_MIN_VAL bits 23..16 -> byte 5
    // Byte 6 is CELL_T_AVG and must be ignored; putting a distinct value there
    // catches an off-by-one in the byte mapping.
    const uint8_t bytes[8] = { 0x00, 0x00, 0x00, 0x00, 0x00, 18, 99, 42 };
    const bms::DecodedFrame f = bms::decode(bms::kIdCellTemps, bytes);

    check(f.kind == bms::FrameKind::CellTemps, "kind is CellTemps");
    check(near(f.cellTempMax, 42.0), "hottest cell = 42 degC");
    check(near(f.cellTempMin, 18.0), "coldest cell = 18 degC");
}

void testSubZeroTemperatures()
{
    std::printf("Cell temperatures are signed, so sub-zero works\n");

    // The under-temperature rule needs negative readings to survive decoding.
    // -5 as int8 is 0xFB, -12 is 0xF4.
    const uint8_t bytes[8] = { 0, 0, 0, 0, 0, 0xF4, 0, 0xFB };
    const bms::DecodedFrame f = bms::decode(bms::kIdCellTemps, bytes);

    check(near(f.cellTempMax, -5.0), "hottest cell = -5 degC");
    check(near(f.cellTempMin, -12.0), "coldest cell = -12 degC");
}

void testUnknownIdsAreIgnored()
{
    std::printf("Identifiers we do not consume decode to Unknown\n");

    const uint8_t bytes[8] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

    // 0x103 and 0x104 are real BMS frames carrying uptime counters, but the
    // dashboard has no use for them.
    check(bms::decode(0x103, bytes).kind == bms::FrameKind::Unknown, "0x103 ignored");
    check(bms::decode(0x104, bytes).kind == bms::FrameKind::Unknown, "0x104 ignored");

    // A WaveSculptor identifier must never decode as a BMS frame. These arrive
    // as standard frames and the reader routes on format, but a decoder that
    // accepted them would make that routing bug invisible.
    check(bms::decode(0x402, bytes).kind == bms::FrameKind::Unknown, "0x402 is not a BMS frame");

    check(bms::isBmsFrame(bms::kIdCellVoltages), "0x100 is a BMS frame");
    check(bms::isBmsFrame(bms::kIdCellTemps), "0x102 is a BMS frame");
    check(!bms::isBmsFrame(0x103), "0x103 is not consumed");
}

void testNullPayload()
{
    std::printf("A null payload does not dereference\n");

    check(bms::decode(bms::kIdCellVoltages, nullptr).kind == bms::FrameKind::Unknown,
          "null data returns Unknown");
}

} // namespace

int main()
{
    std::printf("BMS decoder tests\n\n");

    testCellVoltages();
    testPackCurrentDischarging();
    testPackCurrentCharging();
    testCellTemperatures();
    testSubZeroTemperatures();
    testUnknownIdsAreIgnored();
    testNullPayload();

    std::printf("\n%d checks, %d failures\n", g_checks, g_failures);
    return g_failures == 0 ? 0 : 1;
}
