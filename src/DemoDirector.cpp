#include "DemoDirector.h"

#include "BmsLimits.h"
#include "VehicleData.h"
#include "VehicleSimulator.h"

namespace {

constexpr int kAutoAdvanceMs = 6000;

using DI = VehicleData::DemoIndicator;

} // namespace

// The table. Keys 1-3 are the indicator elements of Reg. 2.26.1; keys 4-8 are
// the five ESS trigger conditions of Reg. 2.5/3.5, one each; key 9 shows the
// escalation from warning to critical and the full-screen takeover.
//
// The `expected` strings are the exact text RaceDashboard.qml will render, from
// its cause/action tables. They are duplicated here on purpose: this is the
// evidence claim, and a demonstration that quietly stopped matching the screen
// would be worse than no demonstration. If one of these ever disagrees with
// what is on screen, one of the two is wrong and both want looking at.
const QVector<DemoDirector::Scenario> &DemoDirector::scenarios()
{
    static const QVector<Scenario> table = {
        { 1, "Reg. 2.26.1 #2", "Left direction indicator",
          "Left arrow flashing at 90/min",
          0, int(DI::Left), false },

        { 2, "Reg. 2.26.1 #2", "Right direction indicator",
          "Right arrow flashing at 90/min",
          0, int(DI::Right), false },

        { 3, "Reg. 2.26.1 #3", "Hazard lights verification",
          "Both arrows flashing together, hazard triangle steady",
          0, int(DI::Hazard), false },

        { 4, "Reg. 2.5/3.5", "Cell voltage below minimum",
          "LOW CELL VOLTAGE / LIFT THROTTLE",
          bms::EssCellUnderVoltageWarning, int(DI::None), false },

        { 5, "Reg. 2.5/3.5", "Cell voltage above maximum",
          "HIGH CELL VOLTAGE / EASE REGEN",
          bms::EssCellOverVoltageWarning, int(DI::None), false },

        { 6, "Reg. 2.5/3.5", "Pack current above maximum",
          "HIGH PACK CURRENT / REDUCE POWER",
          bms::EssOverCurrentWarning, int(DI::None), false },

        { 7, "Reg. 2.5/3.5", "Cell temperature above maximum",
          "PACK HOT / REDUCE POWER",
          bms::EssCellOverTempWarning, int(DI::None), false },

        { 8, "Reg. 2.5/3.5", "Cell temperature below minimum",
          "PACK COLD / EXPECT LOW POWER",
          bms::EssCellUnderTempWarning, int(DI::None), false },

        { 9, "Reg. 2.5/3.5", "Cell over-temperature, critical",
          "Full screen: ESS CELL OVER-TEMPERATURE / STOP VEHICLE IMMEDIATELY",
          bms::EssCellOverTempCritical, int(DI::None), true },
    };
    return table;
}

DemoDirector::DemoDirector(VehicleData *data, VehicleSimulator *simulator,
                           QObject *parent)
    : QObject(parent)
    , m_data(data)
    , m_simulator(simulator)
{
    m_autoAdvance.setInterval(kAutoAdvanceMs);
    connect(&m_autoAdvance, &QTimer::timeout, this, &DemoDirector::next);
}

QString DemoDirector::caption() const
{
    if (!active())
        return QString();
    const Scenario &s = scenarios().at(m_index);
    return QStringLiteral("%1  \u00B7  %2")
        .arg(QString::fromLatin1(s.regulation), QString::fromLatin1(s.name));
}

QString DemoDirector::regulation() const
{
    if (!active())
        return QString();
    return QString::fromLatin1(scenarios().at(m_index).regulation);
}

QString DemoDirector::scenarioName() const
{
    if (!active())
        return QString();
    return QString::fromLatin1(scenarios().at(m_index).name);
}

void DemoDirector::select(int index)
{
    if (index < 0 || index >= scenarios().size()) {
        clear();
        return;
    }
    apply(index);
}

void DemoDirector::selectKey(int key)
{
    const QVector<Scenario> &table = scenarios();
    for (int i = 0; i < table.size(); ++i) {
        if (table.at(i).key == key) {
            apply(i);
            return;
        }
    }
    clear();
}

void DemoDirector::next()
{
    const int n = scenarios().size();
    if (n == 0)
        return;
    apply((m_index + 1) % n);
}

void DemoDirector::clear()
{
    if (m_data)
        m_data->clearDemoState();
    if (m_simulator)
        m_simulator->setHoldIdle(false);
    if (m_index != -1) {
        m_index = -1;
        emit stateChanged();
    }
}

void DemoDirector::startAutoAdvance()
{
    // Start on the first scenario rather than a blank screen, then let the
    // timer walk the rest.
    apply(0);
    m_autoAdvance.start();
}

void DemoDirector::stopAutoAdvance()
{
    m_autoAdvance.stop();
}

void DemoDirector::apply(int index)
{
    const Scenario &s = scenarios().at(index);

    // Clear first, so scenarios never accumulate: pressing 4 then 7 shows one
    // warning, not two with a "+1" badge.
    if (m_data) {
        m_data->clearDemoState();
        m_data->setDemoIndicator(static_cast<DI>(s.indicator));
        m_data->setDemoEssFlags(s.essFlags);
    }
    if (m_simulator)
        m_simulator->setHoldIdle(s.holdStopped);

    m_index = index;
    emit stateChanged();
}
