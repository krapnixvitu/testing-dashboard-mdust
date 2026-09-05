// Regression tests for VehicleData source-ownership rules.
//
// These cover behaviour that is safety-relevant but invisible on screen until
// it is already wrong: which source is allowed to write which value, and what
// the dashboard reports when nothing is reporting at all.

#include "../src/BmsDecoder.h"
#include "../src/BmsLimits.h"
#include "../src/VehicleData.h"
#include "../src/WaveSculptorDecoder.h"

#include <QCoreApplication>

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

void putFloatLe(uint8_t *dst, float value)
{
    uint32_t bits;
    std::memcpy(&bits, &value, sizeof(bits));
    dst[0] = static_cast<uint8_t>(bits & 0xFF);
    dst[1] = static_cast<uint8_t>((bits >> 8) & 0xFF);
    dst[2] = static_cast<uint8_t>((bits >> 16) & 0xFF);
    dst[3] = static_cast<uint8_t>((bits >> 24) & 0xFF);
}

void testGearUnknownByDefault()
{
    std::printf("Gear is unknown until something reports it\n");

    VehicleData data;
    // Empty rather than "D": every QML comparison against D/N/R fails, so no
    // letter is highlighted instead of asserting a gear nobody selected.
    check(data.driveMode().isEmpty(), "driveMode starts empty");
}

void testGearWritesRejectedOnLiveBus()
{
    std::printf("Gear writes are rejected on a live bus\n");

    VehicleData data;
    // Not simulated: this instance represents a real CAN session, where gear
    // is announced by the driver-controls computer. A keypress must not be
    // able to desync the readout from what the car is actually doing.
    data.setDriveMode(QStringLiteral("R"));
    check(data.driveMode().isEmpty(), "keyboard cannot set gear on real CAN");
}

void testGearWritesAcceptedInSimulator()
{
    std::printf("Gear writes are accepted in simulator mode\n");

    VehicleData data;
    data.setSimulated(true);

    data.setDriveMode(QStringLiteral("D"));
    check(data.driveMode() == QLatin1String("D"), "simulator can set gear to D");

    data.setDriveMode(QStringLiteral("N"));
    check(data.driveMode() == QLatin1String("N"), "arrow keys still cycle gear");
}

void testHazardWritesRejectedOnLiveBus()
{
    std::printf("Hazard writes are rejected on a live bus\n");

    VehicleData data;
    // Not simulated. The hazard tell-tale is a regulatory verification that
    // the indicators really are flashing; a keypress must not be able to
    // claim that on a car nobody is measuring.
    data.setHazardActive(true);
    check(!data.hazardActive(), "keyboard cannot set hazard on real CAN");
}

void testHazardWritesAcceptedInSimulator()
{
    std::printf("Hazard writes are accepted in simulator mode\n");

    VehicleData data;
    data.setSimulated(true);

    check(!data.hazardActive(), "hazard starts off");

    data.setHazardActive(true);
    check(data.hazardActive(), "simulator can engage hazard");

    data.setHazardActive(false);
    check(!data.hazardActive(), "simulator can clear hazard");
}

void testBmsValidityFollowsSource()
{
    std::printf("BMS validity follows the source\n");

    VehicleData onCan;
    check(!onCan.bmsValid(), "BMS invalid on real CAN");
    check(!onCan.netCurrentValid(), "net current invalid on real CAN");

    VehicleData sim;
    sim.setSimulated(true);
    check(sim.bmsValid(), "BMS values animate in simulator mode");
}

void testBmsValidityFollowsBmsFrames()
{
    std::printf("BMS validity follows BMS frames, not motor controller frames\n");

    VehicleData data;
    check(!data.bmsValid(), "invalid before any BMS frame");

    // A motor controller frame proves the bus is alive but says nothing about
    // the BMS, so it must not validate the pack readouts.
    ws22::DecodedFrame bus;
    bus.kind = ws22::FrameKind::BusMeasurement;
    bus.busVoltage = 120.0f;
    bus.busCurrent = 10.0f;
    data.applyDecodedFrame(bus);
    check(!data.bmsValid(), "a WaveSculptor frame does not validate the BMS");

    bms::DecodedFrame temps;
    temps.kind = bms::FrameKind::CellTemps;
    temps.cellTempMax = 42.0f;
    temps.cellTempMin = 18.0f;
    data.applyDecodedBmsFrame(temps);

    check(data.bmsValid(), "valid once a BMS frame arrives");
    check(std::fabs(data.packTemp() - 42.0) < 1e-6, "packTemp is the hottest cell");
    check(std::fabs(data.packTempMin() - 18.0) < 1e-6, "packTempMin is the coldest cell");
}

void testPackDeltaVIsDerived()
{
    std::printf("Pack delta V is derived from the decoded cell extremes\n");

    VehicleData data;

    bms::DecodedFrame cells;
    cells.kind = bms::FrameKind::CellVoltages;
    cells.cellVoltageMax = 3.700f;
    cells.cellVoltageMin = 3.650f;
    data.applyDecodedBmsFrame(cells);

    check(std::fabs(data.cellVoltageMax() - 3.700) < 1e-6, "highest cell stored");
    check(std::fabs(data.cellVoltageMin() - 3.650) < 1e-6, "lowest cell stored");
    check(std::fabs(data.packDeltaV() - 0.050) < 1e-6, "delta V = max - min");
}

void testEssFlagsStayClearWhileLimitsUnset()
{
    std::printf("No ESS alert can fire while the limits are unset\n");

    // The limits are NaN until someone enters the cell datasheet figures, and
    // every comparison against NaN is false. Absurd readings must therefore
    // still raise nothing: the dashboard cannot judge limits it was never told.
    check(!bms::limitsConfigured(), "limits start unconfigured");

    VehicleData data;

    bms::DecodedFrame cells;
    cells.kind = bms::FrameKind::CellVoltages;
    cells.cellVoltageMax = 9.9f;    // far above any real cell
    cells.cellVoltageMin = 0.1f;    // far below any real cell
    data.applyDecodedBmsFrame(cells);

    bms::DecodedFrame temps;
    temps.kind = bms::FrameKind::CellTemps;
    temps.cellTempMax = 200.0f;
    temps.cellTempMin = -80.0f;
    data.applyDecodedBmsFrame(temps);

    bms::DecodedFrame amps;
    amps.kind = bms::FrameKind::PackCurrent;
    amps.packCurrent = 5000.0f;
    data.applyDecodedBmsFrame(amps);

    check(data.bmsValid(), "the readings are live");
    check(data.essFlags() == 0, "essFlags stays clear with unset limits");
    check(!data.essLimitsConfigured(), "and the UI can see why");
}

void testCanHealthStartsUnhealthy()
{
    std::printf("CAN health reflects real traffic\n");

    VehicleData data;
    // Nothing has arrived yet, so the footer dot must not claim a healthy bus.
    check(!data.canHealthy(), "unhealthy before the first frame");

    ws22::DecodedFrame frame;
    frame.kind = ws22::FrameKind::BusMeasurement;
    frame.busVoltage = 120.0f;
    frame.busCurrent = 10.0f;
    data.applyDecodedFrame(frame);

    check(data.canHealthy(), "healthy once a frame arrives");

    VehicleData sim;
    sim.setSimulated(true);
    check(sim.canHealthy(), "simulator reports a healthy bus");
}

void testDerivedPowerFromBusFrame()
{
    std::printf("Derived values track decoded frames\n");

    VehicleData data;

    uint8_t bytes[8];
    putFloatLe(bytes + 0, 120.0f);
    putFloatLe(bytes + 4, 10.0f);
    data.applyDecodedFrame(ws22::decode(ws22::kIdBusMeasurement, bytes));

    check(std::fabs(data.busVoltage() - 120.0) < 1e-6, "busVoltage applied");
    check(std::fabs(data.netPower() - 1200.0) < 1e-6, "netPower = V * I");
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    std::printf("VehicleData tests\n\n");

    testGearUnknownByDefault();
    testGearWritesRejectedOnLiveBus();
    testGearWritesAcceptedInSimulator();
    testHazardWritesRejectedOnLiveBus();
    testHazardWritesAcceptedInSimulator();
    testBmsValidityFollowsSource();
    testBmsValidityFollowsBmsFrames();
    testPackDeltaVIsDerived();
    testEssFlagsStayClearWhileLimitsUnset();
    testCanHealthStartsUnhealthy();
    testDerivedPowerFromBusFrame();

    std::printf("\n%d checks, %d failures\n", g_checks, g_failures);
    return g_failures == 0 ? 0 : 1;
}
