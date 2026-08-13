#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "src/SocketCanReader.h"
#include "src/VehicleData.h"
#include "src/VehicleSimulator.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("SolarDashboard"));
    app.setApplicationVersion(QStringLiteral("1.0"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("MDU Solar Team race dashboard"));
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption simulateOption(
        QStringLiteral("simulate"),
        QStringLiteral("Use the built-in drive-cycle simulator instead of real CAN."));
    parser.addOption(simulateOption);

    QCommandLineOption interfaceOption(
        QStringLiteral("can-interface"),
        QStringLiteral("SocketCAN interface to read from (default: can0)."),
        QStringLiteral("name"),
        QStringLiteral("can0"));
    parser.addOption(interfaceOption);

    QCommandLineOption kioskOption(
        QStringLiteral("kiosk"),
        QStringLiteral("Run borderless and fullscreen, covering any desktop "
                        "taskbar/panel. Intended for the dashboard's in-car display."));
    parser.addOption(kioskOption);

    parser.process(app);

    VehicleData vehicleData;

    // Source selection. Real CAN is preferred when available; anything that
    // stops it working falls back to the simulator with a warning rather than
    // leaving the driver looking at a dead screen.
    SocketCanReader canReader(&vehicleData);
    VehicleSimulator simulator(&vehicleData);

    bool useSimulator = parser.isSet(simulateOption);

    if (!useSimulator && !SocketCanReader::isSupportedOnThisPlatform()) {
        qInfo("SocketCAN unavailable on this platform; using simulator.");
        useSimulator = true;
    }

    if (!useSimulator) {
        const QString interfaceName = parser.value(interfaceOption);
        if (canReader.open(interfaceName)) {
            qInfo("Reading CAN frames from %s.", qUtf8Printable(interfaceName));
        } else {
            qWarning("Could not open %s (%s); using simulator.",
                     qUtf8Printable(interfaceName),
                     qUtf8Printable(canReader.lastError()));
            useSimulator = true;
        }
    }

    if (useSimulator)
        simulator.start();

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &vehicleData);
    engine.rootContext()->setContextProperty(QStringLiteral("kioskMode"), parser.isSet(kioskOption));

    const QUrl url(QStringLiteral("qrc:/SolarDashboard/qml/Main.qml"));

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
