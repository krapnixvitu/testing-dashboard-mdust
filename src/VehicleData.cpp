#include "VehicleData.h"

#include "BmsLimits.h"

#include <cmath>

namespace {

// No frame for this long and the bus is considered dead.
constexpr int kWatchdogTimeoutMs = 500;

// The BMS broadcasts far more slowly than the motor controller -- 900 to
// 1100 ms for the frames we decode -- so it gets its own, much longer window.
// 3 s tolerates two consecutive missed frames before the readouts blank.
constexpr int kBmsWatchdogTimeoutMs = 3000;

// The driver reads a 10 s mean rather than instantaneous power. Long enough to
// stop the number twitching, short enough that easing off still shows up.
constexpr int kPowerAverageWindowMs = 10000;

// Below this speed the efficiency figure is meaningless (divide by ~zero).
constexpr qreal kEfficiencyMinSpeedKmh = 5.0;

// Matches the smoothing MockBackend.qml used, so the readout behaves the same.
constexpr qreal kEfficiencySmoothing = 0.05;

bool differs(qreal a, qreal b)
{
    return std::fabs(a - b) > 1e-9;
}

} // namespace

VehicleData::VehicleData(QObject *parent)
    : QObject(parent)
{
    m_watchdog.setSingleShot(true);
    m_watchdog.setInterval(kWatchdogTimeoutMs);
    connect(&m_watchdog, &QTimer::timeout, this, &VehicleData::onWatchdogTimeout);

    m_bmsWatchdog.setSingleShot(true);
    m_bmsWatchdog.setInterval(kBmsWatchdogTimeoutMs);
    connect(&m_bmsWatchdog, &QTimer::timeout, this, &VehicleData::onBmsWatchdogTimeout);

    // Repeating, not single-shot: the averaged figure republishes every window
    // whether or not anything else has happened.
    m_powerAverageTimer.setInterval(kPowerAverageWindowMs);
    connect(&m_powerAverageTimer, &QTimer::timeout, this, &VehicleData::publishAveragedPower);
    m_powerAverageTimer.start();
}

// ── Averaged power ───────────────────────────────────────────────────────

void VehicleData::publishAveragedPower()
{
    // A mean of the window, not a sample of its final instant. A snapshot could
    // catch a transient spike and hold it on screen for ten seconds, showing a
    // figure that never represented the drive.
    if (m_powerSamples <= 0)
        return;

    const qreal mean = m_powerSum / m_powerSamples;
    m_powerSum = 0.0;
    m_powerSamples = 0;

    if (differs(m_netPowerAveraged, mean)) {
        m_netPowerAveraged = mean;
        emit netPowerAveragedChanged();
    }
}

bool VehicleData::essLimitsConfigured() const
{
    return bms::limitsConfigured();
}

// ── Derived values ───────────────────────────────────────────────────────

void VehicleData::recomputeDerived()
{
    const qreal power = m_busVoltage * m_busCurrent;
    if (differs(power, m_netPower)) {
        m_netPower = power;
        emit netPowerChanged();
    }

    // Feed the 10 s mean. Every recompute counts, so the average is over
    // samples rather than over time -- close enough while frames arrive at a
    // steady 200 ms, and it needs no timestamps.
    m_powerSum += power;
    ++m_powerSamples;

    // Rolling average of Wh/km. Bus-side, not pack-side: this is what the
    // controller draws, and excludes aux loads and solar input.
    if (m_vehicleSpeed > kEfficiencyMinSpeedKmh) {
        const qreal instant = m_netPower / m_vehicleSpeed;
        const qreal next = m_efficiency + (instant - m_efficiency) * kEfficiencySmoothing;
        if (differs(next, m_efficiency)) {
            m_efficiency = next;
            emit efficiencyChanged();
        }
    }
}

// ── CAN watchdog ─────────────────────────────────────────────────────────

void VehicleData::petWatchdog()
{
    if (m_simulated)
        return;

    setCanHealthy(true);
    m_watchdog.start();
}

void VehicleData::onWatchdogTimeout()
{
    setCanHealthy(false);
}

void VehicleData::setCanHealthy(bool v)
{
    if (m_canHealthy == v)
        return;
    m_canHealthy = v;
    emit canHealthyChanged();
}

// ── BMS staleness ────────────────────────────────────────────────────────

void VehicleData::petBmsWatchdog()
{
    if (m_simulated)
        return;

    setBmsValid(true);
    m_bmsWatchdog.start();
}

void VehicleData::onBmsWatchdogTimeout()
{
    // The BMS went quiet. Blank the readouts rather than leaving the last
    // reading on screen, where it would look like a live measurement.
    setBmsValid(false);
}

void VehicleData::setBmsValid(bool v)
{
    if (m_bmsValid == v)
        return;
    m_bmsValid = v;
    emit bmsValidChanged();
    recomputeEssFlags();
}

// ── ESS warnings ─────────────────────────────────────────────────────────

void VehicleData::recomputeEssFlags()
{
    int flags = 0;

    // No BMS data means nothing to judge. Every comparison below is also false
    // while the limits are unset, since they are NaN -- so an unconfigured
    // dashboard raises no alert rather than a wrong one.
    if (m_bmsValid) {
        const double vMax = m_cellVoltageMax;
        const double vMin = m_cellVoltageMin;
        const double tMax = m_packTemp;
        const double tMin = m_packTempMin;
        const double amps = std::fabs(static_cast<double>(m_netCurrent));

        if (vMax > bms::kCellVoltageMaxCritical)  flags |= bms::EssCellOverVoltageCritical;
        else if (vMax > bms::kCellVoltageMaxWarning) flags |= bms::EssCellOverVoltageWarning;

        if (vMin < bms::kCellVoltageMinCritical)  flags |= bms::EssCellUnderVoltageCritical;
        else if (vMin < bms::kCellVoltageMinWarning) flags |= bms::EssCellUnderVoltageWarning;

        if (tMax > bms::kCellTempMaxCritical)  flags |= bms::EssCellOverTempCritical;
        else if (tMax > bms::kCellTempMaxWarning) flags |= bms::EssCellOverTempWarning;

        if (tMin < bms::kCellTempMinWarning)
            flags |= bms::EssCellUnderTempWarning;

        if (amps > bms::kPackCurrentCritical)  flags |= bms::EssOverCurrentCritical;
        else if (amps > bms::kPackCurrentWarning) flags |= bms::EssOverCurrentWarning;
    }

    if (m_essFlags != flags) {
        m_essFlags = flags;
        emit essFlagsChanged();
    }
}

// ── BMS ingest ───────────────────────────────────────────────────────────

void VehicleData::applyDecodedBmsFrame(const bms::DecodedFrame &frame)
{
    switch (frame.kind) {
    case bms::FrameKind::CellVoltages: {
        if (differs(m_cellVoltageMax, frame.cellVoltageMax)) {
            m_cellVoltageMax = frame.cellVoltageMax;
            emit cellVoltageMaxChanged();
        }
        if (differs(m_cellVoltageMin, frame.cellVoltageMin)) {
            m_cellVoltageMin = frame.cellVoltageMin;
            emit cellVoltageMinChanged();
        }
        // Cell spread is derived here rather than in QML so there is one
        // definition, as with netPower and efficiency.
        const qreal delta = m_cellVoltageMax - m_cellVoltageMin;
        if (differs(m_packDeltaV, delta)) {
            m_packDeltaV = delta;
            emit packDeltaVChanged();
        }
        break;
    }

    case bms::FrameKind::PackCurrent:
        if (differs(m_netCurrent, frame.packCurrent)) {
            m_netCurrent = frame.packCurrent;
            emit netCurrentChanged();
        }
        break;

    case bms::FrameKind::CellTemps:
        // packTemp is the hottest cell: the safety-relevant one.
        if (differs(m_packTemp, frame.cellTempMax)) {
            m_packTemp = frame.cellTempMax;
            emit packTempChanged();
        }
        if (differs(m_packTempMin, frame.cellTempMin)) {
            m_packTempMin = frame.cellTempMin;
            emit packTempMinChanged();
        }
        // Stored but not shown -- see the property comment.
        if (differs(m_stateOfCharge, frame.stateOfCharge)) {
            m_stateOfCharge = frame.stateOfCharge;
            emit stateOfChargeChanged();
        }
        break;

    case bms::FrameKind::Unknown:
        // Nothing to store, but the frame still proves the bus is alive.
        break;
    }

    petWatchdog();
    petBmsWatchdog();
    recomputeEssFlags();
}

// ── CAN ingest ───────────────────────────────────────────────────────────

void VehicleData::applyDecodedFrame(const ws22::DecodedFrame &frame)
{
    petWatchdog();

    switch (frame.kind) {
    case ws22::FrameKind::Status:
        if (m_limitFlags != frame.limitFlags) {
            m_limitFlags = frame.limitFlags;
            emit limitFlagsChanged();
        }
        if (m_errorFlags != frame.errorFlags) {
            m_errorFlags = frame.errorFlags;
            emit errorFlagsChanged();
        }
        break;

    case ws22::FrameKind::BusMeasurement:
        if (differs(m_busVoltage, frame.busVoltage)) {
            m_busVoltage = frame.busVoltage;
            emit busVoltageChanged();
        }
        if (differs(m_busCurrent, frame.busCurrent)) {
            m_busCurrent = frame.busCurrent;
            emit busCurrentChanged();
        }
        recomputeDerived();
        break;

    case ws22::FrameKind::Velocity:
        if (differs(m_motorRpm, frame.motorRpm)) {
            m_motorRpm = frame.motorRpm;
            emit motorRpmChanged();
        }
        if (differs(m_vehicleSpeed, frame.vehicleSpeed)) {
            m_vehicleSpeed = frame.vehicleSpeed;
            emit vehicleSpeedChanged();
        }
        recomputeDerived();
        break;

    case ws22::FrameKind::Temperature:
        if (differs(m_motorTemp, frame.motorTemp)) {
            m_motorTemp = frame.motorTemp;
            emit motorTempChanged();
        }
        if (differs(m_heatsinkTemp, frame.heatsinkTemp)) {
            m_heatsinkTemp = frame.heatsinkTemp;
            emit heatsinkTempChanged();
        }
        break;

    case ws22::FrameKind::DspTemperature:
        if (differs(m_dspBoardTemp, frame.dspBoardTemp)) {
            m_dspBoardTemp = frame.dspBoardTemp;
            emit dspBoardTempChanged();
        }
        break;

    case ws22::FrameKind::Odometer:
        if (differs(m_odometer, frame.odometerKm)) {
            m_odometer = frame.odometerKm;
            emit odometerChanged();
        }
        if (differs(m_dcBusAmpHours, frame.dcBusAmpHours)) {
            m_dcBusAmpHours = frame.dcBusAmpHours;
            emit dcBusAmpHoursChanged();
        }
        break;

    case ws22::FrameKind::Unknown:
        break;
    }
}

// ── Source mode ──────────────────────────────────────────────────────────

void VehicleData::setSimulated(bool v)
{
    if (m_simulated == v)
        return;

    m_simulated = v;
    emit simulatedChanged();

    // The simulator fabricates BMS values so UI work is not blocked. On real
    // CAN they stay invalid until a BMS decoder exists.
    if (m_bmsValid != v) {
        m_bmsValid = v;
        emit bmsValidChanged();
    }

    if (v) {
        m_watchdog.stop();
        setCanHealthy(true);
    }
}

// ── Simulator ingest ─────────────────────────────────────────────────────

void VehicleData::setSimulatedMotorState(qreal speedKmh, qreal rpm, qreal voltage, qreal current)
{
    if (differs(m_vehicleSpeed, speedKmh)) {
        m_vehicleSpeed = speedKmh;
        emit vehicleSpeedChanged();
    }
    if (differs(m_motorRpm, rpm)) {
        m_motorRpm = rpm;
        emit motorRpmChanged();
    }
    if (differs(m_busVoltage, voltage)) {
        m_busVoltage = voltage;
        emit busVoltageChanged();
    }
    if (differs(m_busCurrent, current)) {
        m_busCurrent = current;
        emit busCurrentChanged();
    }
    recomputeDerived();
}

void VehicleData::setSimulatedTemps(qreal motor, qreal heatsink, qreal dsp, qreal pack)
{
    if (differs(m_motorTemp, motor)) {
        m_motorTemp = motor;
        emit motorTempChanged();
    }
    if (differs(m_heatsinkTemp, heatsink)) {
        m_heatsinkTemp = heatsink;
        emit heatsinkTempChanged();
    }
    if (differs(m_dspBoardTemp, dsp)) {
        m_dspBoardTemp = dsp;
        emit dspBoardTempChanged();
    }
    if (differs(m_packTemp, pack)) {
        m_packTemp = pack;
        emit packTempChanged();
    }
}

void VehicleData::setSimulatedEnergy(qreal odometerKm, qreal ampHours)
{
    if (differs(m_odometer, odometerKm)) {
        m_odometer = odometerKm;
        emit odometerChanged();
    }
    if (differs(m_dcBusAmpHours, ampHours)) {
        m_dcBusAmpHours = ampHours;
        emit dcBusAmpHoursChanged();
    }
}

void VehicleData::setSimulatedFlags(int errorFlags, int limitFlags)
{
    if (m_errorFlags != errorFlags) {
        m_errorFlags = errorFlags;
        emit errorFlagsChanged();
    }
    if (m_limitFlags != limitFlags) {
        m_limitFlags = limitFlags;
        emit limitFlagsChanged();
    }
}

void VehicleData::setSimulatedBms(qreal netCurrent, qreal packDeltaV, bool fault)
{
    if (differs(m_netCurrent, netCurrent)) {
        m_netCurrent = netCurrent;
        emit netCurrentChanged();
    }
    if (differs(m_packDeltaV, packDeltaV)) {
        m_packDeltaV = packDeltaV;
        emit packDeltaVChanged();
    }
    if (m_bmsFault != fault) {
        m_bmsFault = fault;
        emit bmsFaultChanged();
    }
}

void VehicleData::setSimulatedCells(qreal cellVoltageMin, qreal cellVoltageMax,
                                    qreal cellTempMin, qreal cellTempMax)
{
    if (differs(m_cellVoltageMin, cellVoltageMin)) {
        m_cellVoltageMin = cellVoltageMin;
        emit cellVoltageMinChanged();
    }
    if (differs(m_cellVoltageMax, cellVoltageMax)) {
        m_cellVoltageMax = cellVoltageMax;
        emit cellVoltageMaxChanged();
    }
    if (differs(m_packTempMin, cellTempMin)) {
        m_packTempMin = cellTempMin;
        emit packTempMinChanged();
    }
    if (differs(m_packTemp, cellTempMax)) {
        m_packTemp = cellTempMax;
        emit packTempChanged();
    }
    recomputeEssFlags();
}

// ── Writable from QML ────────────────────────────────────────────────────

void VehicleData::setLeftBlinker(bool v)
{
    if (m_leftBlinker == v)
        return;
    m_leftBlinker = v;
    emit leftBlinkerChanged();
}

void VehicleData::setRightBlinker(bool v)
{
    if (m_rightBlinker == v)
        return;
    m_rightBlinker = v;
    emit rightBlinkerChanged();
}

void VehicleData::setHazardActive(bool v)
{
    // Hazard state is a regulatory verification that the car's indicators are
    // actually flashing together (iESC Reg. 2.26.1). Announcing it from a
    // keypress on a live bus would assert something about lamps nobody has
    // measured, so writes are accepted only from the simulator. A real source
    // will write through the CAN ingest path, as gear will.
    if (!m_simulated)
        return;
    if (m_hazardActive == v)
        return;
    m_hazardActive = v;
    emit hazardActiveChanged();
}

void VehicleData::setDriveMode(const QString &v)
{
    // Gear is selected elsewhere and announced over CAN; the dashboard only
    // displays it. Keyboard input is development-only fake data, so it is
    // accepted in simulator mode and ignored on a live bus. Enforced here
    // rather than in QML so there is a single authoritative rule.
    if (!m_simulated)
        return;
    if (m_driveMode == v)
        return;
    m_driveMode = v;
    emit driveModeChanged();
}

void VehicleData::setLapModeActive(bool v)
{
    if (m_lapModeActive == v)
        return;
    m_lapModeActive = v;
    emit lapModeActiveChanged();
}

void VehicleData::setTargetDeltaTime(qreal v)
{
    if (!differs(m_targetDeltaTime, v))
        return;
    m_targetDeltaTime = v;
    emit targetDeltaTimeChanged();
}

void VehicleData::setDebugWarningActive(bool v)
{
    if (m_debugWarningActive == v)
        return;
    m_debugWarningActive = v;
    emit debugWarningActiveChanged();
}

void VehicleData::setDebugCriticalActive(bool v)
{
    if (m_debugCriticalActive == v)
        return;
    m_debugCriticalActive = v;
    emit debugCriticalActiveChanged();
}
