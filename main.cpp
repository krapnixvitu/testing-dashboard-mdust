#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCursor>
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

    QCommandLineOption panelOption(
        QStringLiteral("panel"),
        QStringLiteral("Size the window to one of the candidate displays and lock "
                       "it there, so a desktop run matches the Pi exactly: "
                       "'5in' (800x480) or '7in' (1024x600)."),
        QStringLiteral("name"));
    parser.addOption(panelOption);

    parser.process(app);

    // There is no mouse in the car, so a cursor parked on the display is pure
    // noise -- and on the Pi it sits wherever the pointer was last left. Only
    // in kiosk mode: a development run on a desktop still needs its cursor.
    if (parser.isSet(kioskOption))
        app.setOverrideCursor(QCursor(Qt::BlankCursor));

    // Panel preview. The two candidate displays are nearly the same shape
    // (1.667 vs 1.707), so the layout scales between them -- but only if what
    // you look at on a desktop is actually the panel's geometry. A freely
    // resized window is a different aspect ratio and misleads.
    int panelWidth = 800;
    int panelHeight = 480;
    bool panelLocked = false;

    if (parser.isSet(panelOption)) {
        const QString panel = parser.value(panelOption);
        if (panel == QLatin1String("5in")) {
            panelWidth = 800;
            panelHeight = 480;
            panelLocked = true;
        } else if (panel == QLatin1String("7in")) {
            panelWidth = 1024;
            panelHeight = 600;
            panelLocked = true;
        } else {
            qWarning("Unknown --panel '%s'; expected '5in' or '7in'. Using a "
                     "resizable %dx%d window.",
                     qUtf8Printable(panel), panelWidth, panelHeight);
        }
    }

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
    engine.rootContext()->setContextProperty(QStringLiteral("panelWidth"), panelWidth);
    engine.rootContext()->setContextProperty(QStringLiteral("panelHeight"), panelHeight);
    engine.rootContext()->setContextProperty(QStringLiteral("panelLocked"), panelLocked);

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
