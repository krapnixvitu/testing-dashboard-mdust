#include "VehicleSimulator.h"

#include "VehicleData.h"
#include "WaveSculptorDecoder.h"

#include <cmath>

namespace {

// Matches the CAN high-frequency broadcast rate the real controller uses.
constexpr int kSimIntervalMs = 200;
constexpr qreal kSimDt = 0.2;
// iESC Reg. 2.26.1 verifies an indicator flash rate of 90 +/- 30 per minute.
// Aim for the middle, 90/min. One flash is an on-off pair, so the lamp state
// toggles at twice that rate: 60000 / (2 * 90) = 333 ms per toggle.
constexpr int kBlinkerFlashesPerMinute = 90;
constexpr int kBlinkerIntervalMs = 60000 / (2 * kBlinkerFlashesPerMinute);

constexpr qreal kDriveCycleSeconds = 60.0;
constexpr qreal kRpmPerKmh = 17.0;

} // namespace

VehicleSimulator::VehicleSimulator(VehicleData *data, QObject *parent)
    : QObject(parent)
    , m_data(data)
{
    m_simTimer.setInterval(kSimIntervalMs);
    connect(&m_simTimer, &QTimer::timeout, this, &VehicleSimulator::tick);

    m_blinkerTimer.setInterval(kBlinkerIntervalMs);
    connect(&m_blinkerTimer, &QTimer::timeout, this, &VehicleSimulator::tickBlinkers);
}

void VehicleSimulator::start()
{
    if (m_data) {
        m_data->setSimulated(true);
        // Stands in for the gear the driver-controls computer would report.
        // Must follow setSimulated(): gear writes are rejected on a live bus.
        m_data->setDriveMode(QStringLiteral("D"));
    }
    m_simTimer.start();
    m_blinkerTimer.start();
}

void VehicleSimulator::stop()
{
    m_simTimer.stop();
    m_blinkerTimer.stop();
}

qreal VehicleSimulator::noise(qreal amplitude)
{
    return (QRandomGenerator::global()->generateDouble() - 0.5) * amplitude;
}

void VehicleSimulator::tick()
{
    if (!m_data)
        return;

    m_elapsed += kSimDt;
    const qreal t = m_elapsed;

    // Drive cycle: accelerate, cruise, decelerate, idle, repeat.
    const qreal cyclePos = std::fmod(t, kDriveCycleSeconds);
    if (cyclePos < 15.0) {
        m_targetSpeed = (cyclePos / 15.0) * 80.0;
    } else if (cyclePos < 40.0) {
        m_targetSpeed = 72.0 + 8.0 * std::sin(t * 0.3);
    } else if (cyclePos < 50.0) {
        m_targetSpeed = 80.0 * (1.0 - (cyclePos - 40.0) / 10.0);
    } else {
        m_targetSpeed = 2.0 + QRandomGenerator::global()->generateDouble() * 3.0;
    }

    m_vehicleSpeed += (m_targetSpeed - m_vehicleSpeed) * 0.15;
    if (m_vehicleSpeed < 0.0)
        m_vehicleSpeed = 0.0;

    qreal rpm = m_vehicleSpeed * kRpmPerKmh + noise(20.0);
    if (rpm < 0.0)
        rpm = 0.0;

    m_busVoltage = 120.0 + 10.0 * std::sin(t * 0.02) + noise(2.0);

    m_busCurrent = m_vehicleSpeed * 0.18 + noise(1.5);
    if (m_busCurrent < -3.0)
        m_busCurrent = -3.0;

    m_data->setSimulatedMotorState(m_vehicleSpeed, rpm, m_busVoltage, m_busCurrent);

    const qreal motorTemp = 45.0 + m_vehicleSpeed * 0.3 + 8.0 * std::sin(t * 0.05) + noise(2.0);
    const qreal heatsinkTemp = 35.0 + m_vehicleSpeed * 0.15 + 5.0 * std::sin(t * 0.04);
    const qreal dspTemp = 30.0 + 5.0 * std::sin(t * 0.03) + noise(1.0);
    // Stands in for a BMS pack temperature until one is wired up.
    const qreal packTemp = 28.0 + m_vehicleSpeed * 0.08 + 4.0 * std::sin(t * 0.02) + noise(1.0);
    m_data->setSimulatedTemps(motorTemp, heatsinkTemp, dspTemp, packTemp);

    m_odometer += m_vehicleSpeed * (kSimDt / 3600.0);
    if (m_busCurrent > 0.0)
        m_ampHours += m_busCurrent * (kSimDt / 3600.0);
    m_data->setSimulatedEnergy(m_odometer, m_ampHours);

    // Fabricated cell figures, roughly a healthy pack mid-discharge. The cell
    // spread drives packDeltaV; on a real bus that is derived from the decoded
    // max and min instead. No ESS alert can fire from these -- the limits in
    // BmsLimits.h are unset until the datasheet exists.
    const qreal packDeltaV = 0.020 + QRandomGenerator::global()->generateDouble() * 0.030;
    const qreal cellVoltageMin = 3.60 + QRandomGenerator::global()->generateDouble() * 0.05;
    const qreal cellVoltageMax = cellVoltageMin + packDeltaV;
    m_data->setSimulatedBms(m_busCurrent, packDeltaV, false);
    m_data->setSimulatedCells(cellVoltageMin, cellVoltageMax,
                              packTemp - 4.0, packTemp);

    if (m_data->lapModeActive()) {
        const qreal speedFactor = (m_vehicleSpeed - 40.0) / 40.0;
        m_data->setTargetDeltaTime(-speedFactor * 0.3 + std::sin(t * 0.5) * 0.2);
    } else {
        m_data->setTargetDeltaTime(0.0);
    }

    int limitFlags = 0;
    if (m_vehicleSpeed > 70.0)
        limitFlags = static_cast<int>(ws22::LimitFlag::Velocity);
    else if (m_busCurrent > 14.0)
        limitFlags = static_cast<int>(ws22::LimitFlag::BusCurrent);

    m_data->setSimulatedFlags(0, limitFlags);
}

void VehicleSimulator::tickBlinkers()
{
    if (!m_data)
        return;

    ++m_blinkerCount;
    const qreal phase = std::fmod(m_blinkerCount * 0.5, 30.0);
    const bool flash = (m_blinkerCount % 2) == 0;

    // Hazard drives every indicator at once, so it overrides the turn cycle
    // rather than running alongside it. This is what the hazard tell-tale is
    // verifying: not "hazard was requested" but "both sides are flashing".
    if (m_data->hazardActive()) {
        m_data->setLeftBlinker(flash);
        m_data->setRightBlinker(flash);
        return;
    }

    if (phase >= 10.0 && phase < 20.0) {
        m_data->setLeftBlinker(flash);
        m_data->setRightBlinker(false);
    } else if (phase >= 20.0 && phase < 30.0) {
        m_data->setLeftBlinker(false);
        m_data->setRightBlinker(flash);
    } else {
        m_data->setLeftBlinker(false);
        m_data->setRightBlinker(false);
    }
}
