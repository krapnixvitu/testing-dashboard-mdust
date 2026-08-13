// Unit tests for the WaveSculptor22 frame decoder.
//
// The decoder is deliberately free of Qt, sockets and state, so these run
// anywhere - including Windows, with no Pi and no CAN hardware attached.
// This is where byte-offset, endianness and unit-conversion bugs get caught,
// because those fail silently with plausible-looking numbers on the car.

#include "../src/WaveSculptorDecoder.h"

#include <cmath>
#include <cstdio>
#include <cstring>

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

void checkNear(float actual, float expected, const char *what)
{
    ++g_checks;
    // Values originate as exact IEEE-754 float32, so the tolerance only needs
    // to absorb the conversion arithmetic.
    if (std::fabs(actual - expected) > 1e-3f) {
        ++g_failures;
        std::printf("  FAIL: %s (expected %f, got %f)\n", what, expected, actual);
    }
}

// Writes an IEEE-754 float as little-endian bytes, mirroring what the
// controller puts on the wire.
void putFloatLe(uint8_t *dst, float value)
{
    uint32_t bits;
    std::memcpy(&bits, &value, sizeof(bits));
    dst[0] = static_cast<uint8_t>(bits & 0xFF);
    dst[1] = static_cast<uint8_t>((bits >> 8) & 0xFF);
    dst[2] = static_cast<uint8_t>((bits >> 16) & 0xFF);
    dst[3] = static_cast<uint8_t>((bits >> 24) & 0xFF);
}

void testBusMeasurement()
{
    std::printf("0x402 Bus Measurement\n");

    // Hand-written bytes rather than putFloatLe, so this test also pins down
    // the on-the-wire layout itself: 120.5f == 0x42F10000, LSB first.
    const uint8_t data[8] = {
        0x00, 0x00, 0xF1, 0x42,  // 120.5 V
        0x00, 0x00, 0x24, 0x41   // 10.25 A
    };

    const ws22::DecodedFrame r = ws22::decode(ws22::kIdBusMeasurement, data);
    check(r.kind == ws22::FrameKind::BusMeasurement, "kind is BusMeasurement");
    checkNear(r.busVoltage, 120.5f, "busVoltage");
    checkNear(r.busCurrent, 10.25f, "busCurrent");
}

void testVelocity()
{
    std::printf("0x403 Velocity Measurement\n");

    uint8_t data[8];
    putFloatLe(data + 0, 1700.0f);  // motor rpm
    putFloatLe(data + 4, 25.0f);    // vehicle velocity, m/s

    const ws22::DecodedFrame r = ws22::decode(ws22::kIdVelocity, data);
    check(r.kind == ws22::FrameKind::Velocity, "kind is Velocity");
    checkNear(r.motorRpm, 1700.0f, "motorRpm");
    // 25 m/s * 3.6 == 90 km/h. Guards the unit conversion.
    checkNear(r.vehicleSpeed, 90.0f, "vehicleSpeed converted to km/h");

    // Reverse must not display as negative speed.
    putFloatLe(data + 4, -10.0f);
    const ws22::DecodedFrame rev = ws22::decode(ws22::kIdVelocity, data);
    checkNear(rev.vehicleSpeed, 36.0f, "reverse reports positive speed");
}

void testVelocityFieldsNotSwapped()
{
    std::printf("0x403 field ordering\n");

    // The failure this guards against: swapping bytes 0-3 with 4-7 would put
    // motor RPM in the speed field, which looks plausible at low speed.
    uint8_t data[8];
    putFloatLe(data + 0, 3000.0f);  // rpm
    putFloatLe(data + 4, 10.0f);    // m/s -> 36 km/h

    const ws22::DecodedFrame r = ws22::decode(ws22::kIdVelocity, data);
    check(r.motorRpm > 1000.0f, "rpm came from bytes 0-3");
    check(r.vehicleSpeed < 100.0f, "speed came from bytes 4-7");
}

void testTemperatures()
{
    std::printf("0x40B / 0x40C Temperatures\n");

    uint8_t temps[8];
    putFloatLe(temps + 0, 78.5f);   // motor
    putFloatLe(temps + 4, 52.25f);  // heatsink

    const ws22::DecodedFrame r = ws22::decode(ws22::kIdTemperature, temps);
    check(r.kind == ws22::FrameKind::Temperature, "kind is Temperature");
    checkNear(r.motorTemp, 78.5f, "motorTemp");
    checkNear(r.heatsinkTemp, 52.25f, "heatsinkTemp");

    uint8_t dsp[8];
    std::memset(dsp, 0, sizeof(dsp));
    putFloatLe(dsp + 0, 41.0f);

    const ws22::DecodedFrame d = ws22::decode(ws22::kIdDspTemperature, dsp);
    check(d.kind == ws22::FrameKind::DspTemperature, "kind is DspTemperature");
    checkNear(d.dspBoardTemp, 41.0f, "dspBoardTemp");
}

void testOdometer()
{
    std::printf("0x40E Odometer & AmpHours\n");

    uint8_t data[8];
    putFloatLe(data + 0, 12500.0f);  // metres
    putFloatLe(data + 4, 3.75f);     // Ah

    const ws22::DecodedFrame r = ws22::decode(ws22::kIdOdometer, data);
    check(r.kind == ws22::FrameKind::Odometer, "kind is Odometer");
    // Controller reports metres; dashboard shows km.
    checkNear(r.odometerKm, 12.5f, "odometer converted to km");
    checkNear(r.dcBusAmpHours, 3.75f, "dcBusAmpHours");
}

void testStatusFlags()
{
    std::printf("0x401 Status Information\n");

    // Limit flags in bytes 0-1, error flags in bytes 2-3, both little-endian.
    const uint8_t data[8] = {
        0x04, 0x00,  // limit: bit 2 = Velocity
        0x01, 0x01,  // error: bit 0 = HW over current, bit 8 = Motor over speed
        0x00, 0x00, 0x00, 0x00
    };

    const ws22::DecodedFrame r = ws22::decode(ws22::kIdStatus, data);
    check(r.kind == ws22::FrameKind::Status, "kind is Status");
    check(r.limitFlags == static_cast<uint16_t>(ws22::LimitFlag::Velocity),
          "limitFlags decodes bit 2 as Velocity");
    check((r.errorFlags & static_cast<uint16_t>(ws22::ErrorFlag::HardwareOverCurrent)) != 0,
          "errorFlags bit 0 set");
    check((r.errorFlags & static_cast<uint16_t>(ws22::ErrorFlag::MotorOverSpeed)) != 0,
          "errorFlags bit 8 set");
    check(r.errorFlags == 0x0101, "errorFlags word is 0x0101");
}

void testUnhandledAndGuards()
{
    std::printf("Unhandled frames and guards\n");

    uint8_t data[8];
    std::memset(data, 0xFF, sizeof(data));

    // Phase current is a valid frame the dashboard does not consume yet.
    const ws22::DecodedFrame phase = ws22::decode(ws22::kIdPhaseCurrent, data);
    check(phase.kind == ws22::FrameKind::Unknown, "unconsumed frame is Unknown");

    // A frame from another device entirely.
    const ws22::DecodedFrame foreign = ws22::decode(0x100, data);
    check(foreign.kind == ws22::FrameKind::Unknown, "foreign id is Unknown");

    const ws22::DecodedFrame nullData = ws22::decode(ws22::kIdBusMeasurement, nullptr);
    check(nullData.kind == ws22::FrameKind::Unknown, "null payload is handled");

    check(ws22::isMotorControllerFrame(0x402), "0x402 is a controller frame");
    check(!ws22::isMotorControllerFrame(0x500), "0x500 is not a controller frame");
}

void testNonFiniteSanitised()
{
    std::printf("Non-finite guard\n");

    // A sensor fault can put NaN on the bus; letting it through would poison
    // the efficiency rolling average permanently.
    uint8_t data[8];
    putFloatLe(data + 0, std::nanf(""));
    putFloatLe(data + 4, 10.0f);

    const ws22::DecodedFrame r = ws22::decode(ws22::kIdBusMeasurement, data);
    check(std::isfinite(r.busVoltage), "NaN voltage replaced with a finite value");
    checkNear(r.busCurrent, 10.0f, "neighbouring field unaffected");
}

} // namespace

int main()
{
    std::printf("WaveSculptor22 decoder tests\n\n");

    testBusMeasurement();
    testVelocity();
    testVelocityFieldsNotSwapped();
    testTemperatures();
    testOdometer();
    testStatusFlags();
    testUnhandledAndGuards();
    testNonFiniteSanitised();

    std::printf("\n%d checks, %d failures\n", g_checks, g_failures);
    return g_failures == 0 ? 0 : 1;
}
