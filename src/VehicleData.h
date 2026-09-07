#pragma once

#include <QObject>
#include <QString>
#include <QTimer>

#include "BmsDecoder.h"
#include "WaveSculptorDecoder.h"

// Single backend exposed to QML as `backend`.
//
// Property names match the retired MockBackend.qml exactly so QML bindings
// did not need to change. Data arrives either from SocketCanReader (real CAN)
// or VehicleSimulator (mock); neither this class nor QML knows which.
class VehicleData : public QObject
{
    Q_OBJECT

public:
    // Liveness of a device on the bus, as shown by the footer dots.
    //
    // An enum rather than a bool because the colour semantics are still being
    // decided: some devices will likely want an amber state of their own, and
    // that should not require reshaping the data model to add.
    enum class DeviceStatus {
        Unknown = 0,   // no source, or nothing heard from it -- renders grey
        Healthy,
        Warning,
        Fault,
    };
    Q_ENUM(DeviceStatus)

private:

    // ── From CAN: velocity (0x403) ──
    Q_PROPERTY(qreal vehicleSpeed READ vehicleSpeed NOTIFY vehicleSpeedChanged)
    Q_PROPERTY(qreal motorRpm READ motorRpm NOTIFY motorRpmChanged)

    // ── From CAN: bus (0x402) ──
    Q_PROPERTY(qreal busVoltage READ busVoltage NOTIFY busVoltageChanged)
    Q_PROPERTY(qreal busCurrent READ busCurrent NOTIFY busCurrentChanged)

    // ── Derived from bus data ──
    Q_PROPERTY(qreal netPower READ netPower NOTIFY netPowerChanged)
    // Rolling mean of netPower over the last 10 s, republished every 10 s. What
    // the driver reads: instantaneous power is too twitchy to act on, and a
    // snapshot could freeze a transient spike on screen for ten seconds.
    Q_PROPERTY(qreal netPowerAveraged READ netPowerAveraged NOTIFY netPowerAveragedChanged)
    Q_PROPERTY(qreal efficiency READ efficiency NOTIFY efficiencyChanged)

    // ── From CAN: temperatures (0x40B, 0x40C) ──
    Q_PROPERTY(qreal motorTemp READ motorTemp NOTIFY motorTempChanged)
    Q_PROPERTY(qreal heatsinkTemp READ heatsinkTemp NOTIFY heatsinkTempChanged)
    Q_PROPERTY(qreal dspBoardTemp READ dspBoardTemp NOTIFY dspBoardTempChanged)

    // ── From CAN: odometer & energy (0x40E) ──
    Q_PROPERTY(qreal odometer READ odometer NOTIFY odometerChanged)
    Q_PROPERTY(qreal dcBusAmpHours READ dcBusAmpHours NOTIFY dcBusAmpHoursChanged)

    // ── From CAN: status (0x401) ──
    Q_PROPERTY(int errorFlags READ errorFlags NOTIFY errorFlagsChanged)
    Q_PROPERTY(int limitFlags READ limitFlags NOTIFY limitFlagsChanged)

    // ── Bus health watchdog ──
    Q_PROPERTY(bool canHealthy READ canHealthy NOTIFY canHealthyChanged)

    // ── BMS-sourced (Lithium Balance, extended IDs 0x100-0x102) ──
    // `*Valid` gates the UI so a silent BMS reads as "unknown" rather than as a
    // healthy zero. bmsValid follows a 3 s staleness timer of its own: the BMS
    // broadcasts every 900-1100 ms, far slower than the motor controller, so it
    // cannot share the 500 ms canHealthy watchdog.
    Q_PROPERTY(qreal netCurrent READ netCurrent NOTIFY netCurrentChanged)
    Q_PROPERTY(bool netCurrentValid READ netCurrentValid NOTIFY bmsValidChanged)
    Q_PROPERTY(qreal packTemp READ packTemp NOTIFY packTempChanged)
    Q_PROPERTY(qreal packTempMin READ packTempMin NOTIFY packTempMinChanged)
    Q_PROPERTY(qreal cellVoltageMax READ cellVoltageMax NOTIFY cellVoltageMaxChanged)
    Q_PROPERTY(qreal cellVoltageMin READ cellVoltageMin NOTIFY cellVoltageMinChanged)
    Q_PROPERTY(qreal packDeltaV READ packDeltaV NOTIFY packDeltaVChanged)
    Q_PROPERTY(bool bmsFault READ bmsFault NOTIFY bmsFaultChanged)
    Q_PROPERTY(bool bmsValid READ bmsValid NOTIFY bmsValidChanged)
    // Decoded but not displayed: the BMS's SoC output is faulty and under
    // investigation, so the battery readout still derives a percentage from
    // voltage. When the BMS is fixed, rebind InfoBar to this.
    Q_PROPERTY(qreal stateOfCharge READ stateOfCharge NOTIFY stateOfChargeChanged)

    // ── Other devices on the bus: no source for any of these yet ──
    Q_PROPERTY(DeviceStatus vcuStatus READ vcuStatus NOTIFY vcuStatusChanged)
    Q_PROPERTY(DeviceStatus gpsStatus READ gpsStatus NOTIFY gpsStatusChanged)
    Q_PROPERTY(DeviceStatus telemetryStatus READ telemetryStatus NOTIFY telemetryStatusChanged)

    // ── ESS warnings (iESC Reg. 2.5 & 3.5) ──
    // Bitfield of bms::EssFlag, masked in QML the way errorFlags already is.
    // Stays zero while the limits in BmsLimits.h are unset, which is what
    // essLimitsConfigured reports.
    Q_PROPERTY(int essFlags READ essFlags NOTIFY essFlagsChanged)
    Q_PROPERTY(bool essLimitsConfigured READ essLimitsConfigured CONSTANT)

    // ── Driver inputs: keyboard for now, GPIO or CAN device later ──
    Q_PROPERTY(bool leftBlinker READ leftBlinker WRITE setLeftBlinker NOTIFY leftBlinkerChanged)
    Q_PROPERTY(bool rightBlinker READ rightBlinker WRITE setRightBlinker NOTIFY rightBlinkerChanged)
    // Hazard: all indicators flashing together. Mandatory on-screen verification
    // under iESC Reg. 2.26.1, so it is guarded like gear rather than freely
    // writable -- see setHazardActive().
    Q_PROPERTY(bool hazardActive READ hazardActive WRITE setHazardActive NOTIFY hazardActiveChanged)
    Q_PROPERTY(QString driveMode READ driveMode WRITE setDriveMode NOTIFY driveModeChanged)
    // Accelerator travel, 0-100 %. Read-only by design: there is deliberately no
    // WRITE accessor, so QML cannot fabricate a pedal position the way keyboard
    // input fabricates gear. The only writers are the simulator and, once the
    // driver-controls message exists, the CAN ingest path.
    Q_PROPERTY(qreal pedalPercent READ pedalPercent NOTIFY pedalPercentChanged)

    // ── UI-only state ──
    Q_PROPERTY(bool lapModeActive READ lapModeActive WRITE setLapModeActive NOTIFY lapModeActiveChanged)
    Q_PROPERTY(qreal targetDeltaTime READ targetDeltaTime WRITE setTargetDeltaTime NOTIFY targetDeltaTimeChanged)
    Q_PROPERTY(bool debugWarningActive READ debugWarningActive WRITE setDebugWarningActive NOTIFY debugWarningActiveChanged)
    Q_PROPERTY(bool debugCriticalActive READ debugCriticalActive WRITE setDebugCriticalActive NOTIFY debugCriticalActiveChanged)

    // ── Which source is feeding this object ──
    Q_PROPERTY(bool simulated READ simulated NOTIFY simulatedChanged)

public:
    explicit VehicleData(QObject *parent = nullptr);

    qreal vehicleSpeed() const { return m_vehicleSpeed; }
    qreal motorRpm() const { return m_motorRpm; }
    qreal busVoltage() const { return m_busVoltage; }
    qreal busCurrent() const { return m_busCurrent; }
    qreal netPower() const { return m_netPower; }
    qreal netPowerAveraged() const { return m_netPowerAveraged; }
    qreal efficiency() const { return m_efficiency; }
    qreal motorTemp() const { return m_motorTemp; }
    qreal heatsinkTemp() const { return m_heatsinkTemp; }
    qreal dspBoardTemp() const { return m_dspBoardTemp; }
    qreal odometer() const { return m_odometer; }
    qreal dcBusAmpHours() const { return m_dcBusAmpHours; }
    int errorFlags() const { return m_errorFlags; }
    int limitFlags() const { return m_limitFlags; }
    bool canHealthy() const { return m_canHealthy; }

    qreal netCurrent() const { return m_netCurrent; }
    bool netCurrentValid() const { return m_bmsValid; }
    qreal packTemp() const { return m_packTemp; }
    qreal packTempMin() const { return m_packTempMin; }
    qreal cellVoltageMax() const { return m_cellVoltageMax; }
    qreal cellVoltageMin() const { return m_cellVoltageMin; }
    qreal packDeltaV() const { return m_packDeltaV; }
    int essFlags() const { return m_essFlags; }
    bool essLimitsConfigured() const;
    bool bmsFault() const { return m_bmsFault; }
    bool bmsValid() const { return m_bmsValid; }
    qreal stateOfCharge() const { return m_stateOfCharge; }
    DeviceStatus vcuStatus() const { return m_vcuStatus; }
    DeviceStatus gpsStatus() const { return m_gpsStatus; }
    DeviceStatus telemetryStatus() const { return m_telemetryStatus; }

    bool leftBlinker() const { return m_leftBlinker; }
    bool rightBlinker() const { return m_rightBlinker; }
    bool hazardActive() const { return m_hazardActive; }
    QString driveMode() const { return m_driveMode; }
    qreal pedalPercent() const { return m_pedalPercent; }
    bool lapModeActive() const { return m_lapModeActive; }
    qreal targetDeltaTime() const { return m_targetDeltaTime; }
    bool debugWarningActive() const { return m_debugWarningActive; }
    bool debugCriticalActive() const { return m_debugCriticalActive; }
    bool simulated() const { return m_simulated; }

    void setLeftBlinker(bool v);
    void setRightBlinker(bool v);
    void setHazardActive(bool v);
    void setDriveMode(const QString &v);
    void setLapModeActive(bool v);
    void setTargetDeltaTime(qreal v);
    void setDebugWarningActive(bool v);
    void setDebugCriticalActive(bool v);

    // ── Ingest ──

    // Applies one decoded motor controller frame and pets the bus watchdog.
    void applyDecodedFrame(const ws22::DecodedFrame &frame);

    // Applies one decoded BMS frame, pets the bus watchdog and refreshes the
    // separate BMS staleness timer.
    void applyDecodedBmsFrame(const bms::DecodedFrame &frame);

    // Marks this instance as simulator-fed. Enables the BMS placeholder values
    // so UI work is not blocked, and disables the CAN watchdog.
    void setSimulated(bool v);

    // Used only by VehicleSimulator.
    void setSimulatedMotorState(qreal speedKmh, qreal rpm, qreal voltage, qreal current);
    void setSimulatedTemps(qreal motor, qreal heatsink, qreal dsp, qreal pack);
    void setSimulatedEnergy(qreal odometerKm, qreal ampHours);
    void setSimulatedFlags(int errorFlags, int limitFlags);
    void setSimulatedBms(qreal netCurrent, qreal packDeltaV, bool fault);
    void setSimulatedCells(qreal cellVoltageMin, qreal cellVoltageMax,
                           qreal cellTempMin, qreal cellTempMax);
    void setSimulatedPedal(qreal percent);

signals:
    void vehicleSpeedChanged();
    void motorRpmChanged();
    void busVoltageChanged();
    void busCurrentChanged();
    void netPowerChanged();
    void netPowerAveragedChanged();
    void efficiencyChanged();
    void motorTempChanged();
    void heatsinkTempChanged();
    void dspBoardTempChanged();
    void odometerChanged();
    void dcBusAmpHoursChanged();
    void errorFlagsChanged();
    void limitFlagsChanged();
    void canHealthyChanged();
    void netCurrentChanged();
    void packTempChanged();
    void packTempMinChanged();
    void cellVoltageMaxChanged();
    void cellVoltageMinChanged();
    void packDeltaVChanged();
    void essFlagsChanged();
    void bmsFaultChanged();
    void bmsValidChanged();
    void stateOfChargeChanged();
    void vcuStatusChanged();
    void gpsStatusChanged();
    void telemetryStatusChanged();
    void leftBlinkerChanged();
    void rightBlinkerChanged();
    void hazardActiveChanged();
    void driveModeChanged();
    void pedalPercentChanged();
    void lapModeActiveChanged();
    void targetDeltaTimeChanged();
    void debugWarningActiveChanged();
    void debugCriticalActiveChanged();
    void simulatedChanged();

private:
    void recomputeDerived();
    void recomputeEssFlags();
    void publishAveragedPower();
    void petBmsWatchdog();
    void onBmsWatchdogTimeout();
    void setBmsValid(bool v);
    void petWatchdog();
    void onWatchdogTimeout();
    void setCanHealthy(bool v);

    qreal m_vehicleSpeed = 0.0;
    qreal m_motorRpm = 0.0;
    qreal m_busVoltage = 0.0;
    qreal m_busCurrent = 0.0;
    qreal m_netPower = 0.0;
    qreal m_netPowerAveraged = 0.0;
    qreal m_powerSum = 0.0;      // accumulator for the 10 s mean
    int   m_powerSamples = 0;
    qreal m_efficiency = 0.0;
    qreal m_motorTemp = 0.0;
    qreal m_heatsinkTemp = 0.0;
    qreal m_dspBoardTemp = 0.0;
    qreal m_odometer = 0.0;
    qreal m_dcBusAmpHours = 0.0;
    int m_errorFlags = 0;
    int m_limitFlags = 0;
    bool m_canHealthy = false;

    qreal m_netCurrent = 0.0;
    qreal m_packTemp = 0.0;
    qreal m_packTempMin = 0.0;
    qreal m_cellVoltageMax = 0.0;
    qreal m_cellVoltageMin = 0.0;
    qreal m_packDeltaV = 0.0;
    int m_essFlags = 0;
    qreal m_stateOfCharge = 0.0;
    bool m_bmsFault = false;
    bool m_bmsValid = false;

    // No source exists for any of these, so they stay Unknown and render grey --
    // the same honest gap as gear and the blinkers.
    DeviceStatus m_vcuStatus = DeviceStatus::Unknown;
    DeviceStatus m_gpsStatus = DeviceStatus::Unknown;
    DeviceStatus m_telemetryStatus = DeviceStatus::Unknown;

    bool m_leftBlinker = false;
    bool m_rightBlinker = false;
    bool m_hazardActive = false;
    // Empty means "no gear reported". Every QML comparison against D/N/R then
    // fails, so no letter is highlighted.
    QString m_driveMode;
    qreal m_pedalPercent = 0.0;
    bool m_lapModeActive = false;
    qreal m_targetDeltaTime = 0.0;
    bool m_debugWarningActive = false;
    bool m_debugCriticalActive = false;
    bool m_simulated = false;

    QTimer m_watchdog;
    // Separate from m_watchdog: BMS frames are an order of magnitude slower
    // than the motor controller's, so they need their own staleness window.
    QTimer m_bmsWatchdog;
    QTimer m_powerAverageTimer;
};
