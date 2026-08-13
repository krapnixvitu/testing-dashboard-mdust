#pragma once

#include <QObject>
#include <QRandomGenerator>
#include <QTimer>

class VehicleData;

// Drive-cycle simulator, ported from the retired MockBackend.qml.
//
// Drives a VehicleData instance from a timer instead of from CAN, so the
// dashboard is fully exercisable on Windows and on a Pi with no CAN hat.
// Timings and constants are kept identical to the original QML so the
// on-screen behaviour is unchanged.
class VehicleSimulator : public QObject
{
    Q_OBJECT

public:
    explicit VehicleSimulator(VehicleData *data, QObject *parent = nullptr);

    void start();
    void stop();

private:
    void tick();
    void tickBlinkers();
    qreal noise(qreal amplitude);

    VehicleData *m_data = nullptr;
    QTimer m_simTimer;
    QTimer m_blinkerTimer;

    qreal m_elapsed = 0.0;
    qreal m_targetSpeed = 60.0;
    qreal m_vehicleSpeed = 0.0;
    qreal m_busVoltage = 120.0;
    qreal m_busCurrent = 10.0;
    qreal m_odometer = 0.0;
    qreal m_ampHours = 0.0;
    int m_blinkerCount = 0;
};
