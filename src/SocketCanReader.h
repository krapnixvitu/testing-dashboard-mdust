#pragma once

#include <QObject>
#include <QString>

class QSocketNotifier;
class VehicleData;

// Reads WaveSculptor22 frames from a SocketCAN interface.
//
// Linux only. open() returns false everywhere else, which is what lets
// main.cpp fall back to the simulator without a compile-time split.
//
// Uses QSocketNotifier rather than a reader thread: the controller broadcasts
// roughly 35 frames/sec, so servicing it from the existing Qt event loop costs
// nothing and avoids cross-thread state entirely.
class SocketCanReader : public QObject
{
    Q_OBJECT

public:
    explicit SocketCanReader(VehicleData *data, QObject *parent = nullptr);
    ~SocketCanReader() override;

    // Binds to `interfaceName` (typically "can0"). Returns false and sets
    // lastError() if the interface is missing or not up.
    bool open(const QString &interfaceName);
    void close();

    bool isOpen() const { return m_fd >= 0; }
    QString lastError() const { return m_lastError; }

    static bool isSupportedOnThisPlatform();

private:
    void onReadyRead();

    VehicleData *m_data = nullptr;
    QSocketNotifier *m_notifier = nullptr;
    int m_fd = -1;
    QString m_lastError;
};
