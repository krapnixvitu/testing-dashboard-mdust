#pragma once

#include <cmath>
#include <limits>

// Energy storage system limits and alert flags.
//
// EVERY LIMIT BELOW IS DELIBERATELY UNSET. They must come from the datasheet of
// the cells actually fitted. Plausible defaults do not exist: the safe window
// depends on chemistry, and getting it wrong is worse than not warning at all
// (LiFePO4 tops out near 3.65 V per cell, NMC near 4.2 V).
//
// Every comparison against NaN is false, so while these are unset no ESS alert
// can fire. That is intended, not a stopgap: the dashboard cannot judge safety
// limits it has not been told, and `essLimitsConfigured` makes that state
// visible instead of letting an unconfigured dashboard look safe.
//
// To configure: replace each kUnset with the datasheet figure. Nothing else
// needs to change.
namespace bms {

constexpr double kUnset = std::numeric_limits<double>::quiet_NaN();

// ── Cell voltage, volts per cell ──
// Over-voltage: lithium plating and internal shorting, driven by regen or solar
// charging. Under-voltage: sag under acceleration, recoverable by lifting off.
constexpr double kCellVoltageMaxWarning  = kUnset;
constexpr double kCellVoltageMaxCritical = kUnset;
constexpr double kCellVoltageMinWarning  = kUnset;
constexpr double kCellVoltageMinCritical = kUnset;

// ── Cell temperature, degrees C ──
// Over-temperature has a warning tier because thermal mass is slow: by the time
// the critical limit is reached the heating is already committed, so the earlier
// tier is what actually gives the driver time to reduce current.
// Under-temperature is warning-only: cold cells mean higher internal resistance
// and worse performance, not an immediate hazard.
constexpr double kCellTempMaxWarning  = kUnset;
constexpr double kCellTempMaxCritical = kUnset;
constexpr double kCellTempMinWarning  = kUnset;

// ── Pack current, amps ──
// Compared as a magnitude, so the same pair covers charge and discharge.
constexpr double kPackCurrentWarning  = kUnset;
constexpr double kPackCurrentCritical = kUnset;

// ESS alert bits. Exposed to QML as the `essFlags` int and masked there the same
// way `errorFlags` and `limitFlags` already are.
enum EssFlag : int {
    EssCellOverVoltageWarning   = 1 << 0,
    EssCellOverVoltageCritical  = 1 << 1,
    EssCellUnderVoltageWarning  = 1 << 2,
    EssCellUnderVoltageCritical = 1 << 3,
    EssCellOverTempWarning      = 1 << 4,
    EssCellOverTempCritical     = 1 << 5,
    EssCellUnderTempWarning     = 1 << 6,
    EssOverCurrentWarning       = 1 << 7,
    EssOverCurrentCritical      = 1 << 8,
};

// False while any limit is still unset, which is what the UI reports so an
// unconfigured dashboard cannot be mistaken for one that is watching.
inline bool limitsConfigured()
{
    const double all[] = {
        kCellVoltageMaxWarning, kCellVoltageMaxCritical,
        kCellVoltageMinWarning, kCellVoltageMinCritical,
        kCellTempMaxWarning,    kCellTempMaxCritical,
        kCellTempMinWarning,
        kPackCurrentWarning,    kPackCurrentCritical,
    };
    for (double v : all) {
        if (std::isnan(v))
            return false;
    }
    return true;
}

} // namespace bms
