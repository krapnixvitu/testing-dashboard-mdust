// Tests for the scrutineering demonstration table.
//
// The table in src/DemoDirector.cpp is not just convenience wiring: it is the
// evidence claim published in docs/regulatory-compliance.md section 6. These
// check the properties that document depends on -- that every regulated
// element has a key, that no two scenarios share one, and that selecting a
// scenario leaves the dashboard in the state the document says it will.

#include "../src/BmsLimits.h"
#include "../src/DemoDirector.h"
#include "../src/VehicleData.h"
#include "../src/VehicleSimulator.h"

#include <QCoreApplication>
#include <QSet>
#include <QString>

#include <cstdio>

namespace {

int g_failures = 0;
int g_checks = 0;

void check(bool condition, const char *what)
{
    ++g_checks;
    if (!condition) {
        ++g_failures;
        std::printf("  FAIL: %s\n", what);
    }
}

void testEveryScenarioIsDescribed()
{
    std::printf("Every scenario names a regulation, an element and an outcome\n");

    const auto &table = DemoDirector::scenarios();
    check(!table.isEmpty(), "the table is not empty");

    for (const auto &s : table) {
        check(s.regulation && *s.regulation, "regulation reference present");
        check(s.name && *s.name, "scenario name present");
        check(s.expected && *s.expected, "expected on-screen result present");
        check(s.key >= 1 && s.key <= 9, "key is a single digit 1-9");
    }
}

void testKeysAreUnique()
{
    std::printf("No two scenarios share a key\n");

    // A duplicate would make the documented key table silently wrong: one of
    // the two scenarios would be unreachable from the keyboard.
    QSet<int> seen;
    for (const auto &s : DemoDirector::scenarios()) {
        check(!seen.contains(s.key), "key not already used");
        seen.insert(s.key);
    }
    check(seen.size() == DemoDirector::scenarios().size(), "all keys distinct");
}

void testAllFiveEssTriggersAreCovered()
{
    std::printf("All five Reg. 2.5/3.5 trigger conditions have a scenario\n");

    // The regulation names exactly five: cell voltage below minimum and above
    // maximum, current above maximum, cell temperature above maximum and below
    // minimum. If one loses its scenario it becomes undemonstrable, and this
    // is the only place that would notice.
    int seen = 0;
    for (const auto &s : DemoDirector::scenarios())
        seen |= s.essFlags;

    check((seen & bms::EssCellUnderVoltageWarning) != 0, "cell voltage below minimum");
    check((seen & bms::EssCellOverVoltageWarning) != 0, "cell voltage above maximum");
    check((seen & bms::EssOverCurrentWarning) != 0, "current above maximum");
    check((seen & bms::EssCellOverTempWarning) != 0, "cell temperature above maximum");
    check((seen & bms::EssCellUnderTempWarning) != 0, "cell temperature below minimum");
    check((seen & bms::EssCellOverTempCritical) != 0, "and the critical escalation");
}

void testIndicatorScenariosExist()
{
    std::printf("Both indicator elements of Reg. 2.26.1 have a scenario\n");

    bool left = false, right = false, hazard = false;
    for (const auto &s : DemoDirector::scenarios()) {
        if (s.indicator == int(VehicleData::DemoIndicator::Left))   left = true;
        if (s.indicator == int(VehicleData::DemoIndicator::Right))  right = true;
        if (s.indicator == int(VehicleData::DemoIndicator::Hazard)) hazard = true;
    }
    check(left, "left direction indicator");
    check(right, "right direction indicator");
    check(hazard, "hazard verification");
}

void testSelectAppliesAndClearsCleanly()
{
    std::printf("Selecting applies one scenario at a time\n");

    VehicleData data;
    data.setSimulated(true);
    VehicleSimulator sim(&data);
    DemoDirector demo(&data, &sim);

    check(!demo.active(), "inert before anything is selected");
    check(demo.caption().isEmpty(), "and captionless");

    demo.selectKey(4);
    check(demo.active(), "active after a selection");
    check(!demo.caption().isEmpty(), "caption populated");
    check(data.essFlags() == bms::EssCellUnderVoltageWarning, "the right bit is up");

    // Scenarios replace rather than accumulate: two warnings at once would
    // show a "+1" badge the demonstration never intended.
    demo.selectKey(7);
    check(data.essFlags() == bms::EssCellOverTempWarning, "previous scenario cleared");

    demo.clear();
    check(!demo.active(), "inert again");
    check(data.essFlags() == 0, "and the dashboard is clean");
    check(!data.hazardActive(), "hazard released");
}

void testCriticalScenarioHoldsTheCarStopped()
{
    std::printf("The critical scenario brings the car to a standstill\n");

    // CriticalOverlay is gated on backend.vehicleStopped, so without this the
    // full-screen takeover would only appear if the drive cycle happened to be
    // in its idle phase.
    VehicleData data;
    data.setSimulated(true);
    VehicleSimulator sim(&data);
    DemoDirector demo(&data, &sim);

    demo.selectKey(9);
    check(sim.holdIdle(), "hold-idle engaged for the critical scenario");

    demo.selectKey(4);
    check(!sim.holdIdle(), "and released for a warning scenario");

    demo.selectKey(9);
    demo.clear();
    check(!sim.holdIdle(), "and released on clear");
}

void testNextWraps()
{
    std::printf("The scripted run wraps at the end of the table\n");

    VehicleData data;
    data.setSimulated(true);
    VehicleSimulator sim(&data);
    DemoDirector demo(&data, &sim);

    const int n = DemoDirector::scenarios().size();
    demo.select(n - 1);
    check(demo.index() == n - 1, "on the last scenario");

    demo.next();
    check(demo.index() == 0, "wraps back to the first");
}

void testOutOfRangeSelectionClears()
{
    std::printf("An unmapped key clears rather than doing something arbitrary\n");

    VehicleData data;
    data.setSimulated(true);
    VehicleSimulator sim(&data);
    DemoDirector demo(&data, &sim);

    demo.selectKey(4);
    demo.selectKey(99);
    check(!demo.active(), "unmapped key cleared the demo");
    check(data.essFlags() == 0, "and the dashboard with it");
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    std::printf("DemoDirector tests\n\n");

    testEveryScenarioIsDescribed();
    testKeysAreUnique();
    testAllFiveEssTriggersAreCovered();
    testIndicatorScenariosExist();
    testSelectAppliesAndClearsCleanly();
    testCriticalScenarioHoldsTheCarStopped();
    testNextWraps();
    testOutOfRangeSelectionClears();

    std::printf("\n%d checks, %d failures\n", g_checks, g_failures);
    return g_failures == 0 ? 0 : 1;
}
