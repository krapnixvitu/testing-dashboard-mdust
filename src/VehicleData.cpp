#include "VehicleData.h"

#include <cmath>

namespace {

// No frame for this long and the bus is considered dead.
constexpr int kWatchdogTimeoutMs = 500;

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
}

// ── Derived values ───────────────────────────────────────────────────────

void VehicleData::recomputeDerived()
{
    const qreal power = m_busVoltage * m_busCurrent;
    if (differs(power, m_netPower)) {
        m_netPower = power;
        emit netPowerChanged();
    }

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
