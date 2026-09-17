#pragma once

#include <QObject>
#include <QString>
#include <QTimer>
#include <QVector>

class VehicleData;
class VehicleSimulator;

// Scrutineering demonstration.
//
// The car is not drivable and has no wiring, so nothing on a real bus can be
// shown. What scrutineering actually asks is whether the driver's screen
// *displays* what iESC Reg. 2.26.1 and Reg. 2.5/3.5 require, and this walks
// through each of those elements in turn so it can be seen rather than
// asserted.
//
// One scenario table, consulted both by the number keys and by the scripted
// run, so a live demonstration and a hands-off one can never disagree about
// what key 6 does. Nothing here fabricates a measurement: each scenario sets
// presentation state through VehicleData's demo overrides, which are
// themselves rejected on a live bus.
class DemoDirector : public QObject
{
    Q_OBJECT

    // The regulation reference and scenario name, for the on-screen caption.
    // Empty when no scenario is selected.
    Q_PROPERTY(QString caption READ caption NOTIFY stateChanged)
    // Split out as well, because the caption renders them at different sizes.
    Q_PROPERTY(QString regulation READ regulation NOTIFY stateChanged)
    Q_PROPERTY(QString scenarioName READ scenarioName NOTIFY stateChanged)
    // True while a scenario is up. QML binds visibility to this; it is not a
    // real-vs-simulated branch, which QML must never make.
    Q_PROPERTY(bool active READ active NOTIFY stateChanged)
    Q_PROPERTY(int index READ index NOTIFY stateChanged)
    Q_PROPERTY(int count READ count CONSTANT)

public:
    // What a scenario does to the dashboard. Deliberately data, not a lambda:
    // the table is then something a test can walk and a document can be
    // generated from.
    struct Scenario {
        int key;                 // the digit that selects it
        const char *regulation;  // e.g. "Reg. 2.26.1 #3"
        const char *name;        // e.g. "Hazard lights verification"
        const char *expected;    // what should appear on screen
        int essFlags;            // bms::EssFlag bits to raise
        int indicator;           // VehicleData::DemoIndicator
        bool holdStopped;        // bring the car to a halt first
    };

    explicit DemoDirector(VehicleData *data, VehicleSimulator *simulator,
                          QObject *parent = nullptr);

    static const QVector<Scenario> &scenarios();

    QString caption() const;
    QString regulation() const;
    QString scenarioName() const;
    bool active() const { return m_index >= 0; }
    int index() const { return m_index; }
    int count() const { return scenarios().size(); }

    // Selects by position in the table, not by key. Out of range clears.
    Q_INVOKABLE void select(int index);
    // Selects by the digit pressed, so QML does not need to know the ordering.
    Q_INVOKABLE void selectKey(int key);
    Q_INVOKABLE void next();
    Q_INVOKABLE void clear();

    // Starts the scripted run: advances every kAutoAdvanceMs and wraps.
    void startAutoAdvance();
    void stopAutoAdvance();

signals:
    void stateChanged();

private:
    void apply(int index);

    VehicleData *m_data = nullptr;
    VehicleSimulator *m_simulator = nullptr;
    QTimer m_autoAdvance;
    int m_index = -1;
};
