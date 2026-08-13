#pragma once

#include <cstdint>

namespace ws22 {

constexpr uint32_t kMotorControllerBase = 0x400;

// Driver controls device. Gear selection is broadcast from here by a separate
// computer; the dashboard only reads and displays it, never commands it.
// The exact message ID is not defined yet.
constexpr uint32_t kDriverControlsBase = 0x500;

constexpr uint32_t kIdIdentification   = kMotorControllerBase + 0x00;
constexpr uint32_t kIdStatus           = kMotorControllerBase + 0x01;
constexpr uint32_t kIdBusMeasurement   = kMotorControllerBase + 0x02;
constexpr uint32_t kIdVelocity         = kMotorControllerBase + 0x03;
constexpr uint32_t kIdPhaseCurrent     = kMotorControllerBase + 0x04;
constexpr uint32_t kIdMotorVoltage     = kMotorControllerBase + 0x05;
constexpr uint32_t kIdMotorCurrent     = kMotorControllerBase + 0x06;
constexpr uint32_t kIdBackEmf          = kMotorControllerBase + 0x07;
constexpr uint32_t kIdRail15V          = kMotorControllerBase + 0x08;
constexpr uint32_t kIdRail33V19V       = kMotorControllerBase + 0x09;
constexpr uint32_t kIdTemperature      = kMotorControllerBase + 0x0B;
constexpr uint32_t kIdDspTemperature   = kMotorControllerBase + 0x0C;
constexpr uint32_t kIdOdometer         = kMotorControllerBase + 0x0E;
constexpr uint32_t kIdSlipSpeed        = kMotorControllerBase + 0x17;

enum class LimitFlag : uint16_t {
    OutputVoltagePwm = 1u << 0,
    MotorCurrent     = 1u << 1,
    Velocity         = 1u << 2,
    BusCurrent       = 1u << 3,
    BusVoltageUpper  = 1u << 4,
    BusVoltageLower  = 1u << 5,
    IpmOrMotorTemp   = 1u << 6,
};

enum class ErrorFlag : uint16_t {
    HardwareOverCurrent = 1u << 0,
    SoftwareOverCurrent = 1u << 1,
    DcBusOverVoltage    = 1u << 2,
    BadMotorPositionHall = 1u << 3,
    WatchdogReset       = 1u << 4,
    ConfigReadError     = 1u << 5,
    Rail15VUnderVoltage = 1u << 6,
    DesaturationFault   = 1u << 7,
    MotorOverSpeed      = 1u << 8,
};

enum class FrameKind {
    Unknown,
    Status,
    BusMeasurement,
    Velocity,
    Temperature,
    DspTemperature,
    Odometer,
};

struct DecodedFrame {
    FrameKind kind = FrameKind::Unknown;

    // Status
    uint16_t limitFlags = 0;
    uint16_t errorFlags = 0;

    // BusMeasurement
    float busVoltage = 0.0f;   // V
    float busCurrent = 0.0f;   // A

    // Velocity
    float motorRpm = 0.0f;     // RPM
    float vehicleSpeed = 0.0f; // km/h, absolute value

    // Temperature
    float motorTemp = 0.0f;    // degC
    float heatsinkTemp = 0.0f; // degC
    float dspBoardTemp = 0.0f; // degC

    // Odometer
    float odometerKm = 0.0f;   // km
    float dcBusAmpHours = 0.0f;// Ah
};

// Decodes a single WaveSculptor22 broadcast frame.
//
// Pure: depends only on its arguments, touches no I/O, holds no state.
// `data` must point to at least 8 bytes. Frames outside the motor controller
// range, or ones the dashboard does not consume, return FrameKind::Unknown.
DecodedFrame decode(uint32_t canId, const uint8_t *data);

// True when `canId` is one of the motor controller broadcast IDs.
bool isMotorControllerFrame(uint32_t canId);

} // namespace ws22
