#include "WaveSculptorDecoder.h"

#include <cmath>
#include <cstring>

namespace ws22 {
namespace {

// WaveSculptor22 transmits LSB first. Reassemble explicitly rather than
// memcpy'ing the whole payload so the decoder behaves identically on a
// big-endian host.
uint32_t readU32Le(const uint8_t *p)
{
    return static_cast<uint32_t>(p[0])
         | (static_cast<uint32_t>(p[1]) << 8)
         | (static_cast<uint32_t>(p[2]) << 16)
         | (static_cast<uint32_t>(p[3]) << 24);
}

uint16_t readU16Le(const uint8_t *p)
{
    return static_cast<uint16_t>(static_cast<uint16_t>(p[0])
         | (static_cast<uint16_t>(p[1]) << 8));
}

float readF32Le(const uint8_t *p)
{
    const uint32_t bits = readU32Le(p);
    float value;
    std::memcpy(&value, &bits, sizeof(value));
    return value;
}

// The controller can emit NaN/Inf on a sensor fault. Let those through as 0
// rather than poisoning every downstream average.
float sanitise(float v)
{
    return std::isfinite(v) ? v : 0.0f;
}

} // namespace

bool isMotorControllerFrame(uint32_t canId)
{
    return canId >= kMotorControllerBase && canId <= (kMotorControllerBase + 0x1F);
}

DecodedFrame decode(uint32_t canId, const uint8_t *data)
{
    DecodedFrame out;
    if (data == nullptr)
        return out;

    switch (canId) {
    case kIdStatus:
        out.kind = FrameKind::Status;
        out.limitFlags = readU16Le(data + 0);
        out.errorFlags = readU16Le(data + 2);
        break;

    case kIdBusMeasurement:
        out.kind = FrameKind::BusMeasurement;
        out.busVoltage = sanitise(readF32Le(data + 0));
        out.busCurrent = sanitise(readF32Le(data + 4));
        break;

    case kIdVelocity: {
        out.kind = FrameKind::Velocity;
        out.motorRpm = sanitise(readF32Le(data + 0));
        const float mps = sanitise(readF32Le(data + 4));
        // Absolute value: reverse must not display as negative speed.
        out.vehicleSpeed = std::fabs(mps) * 3.6f;
        break;
    }

    case kIdTemperature:
        out.kind = FrameKind::Temperature;
        out.motorTemp = sanitise(readF32Le(data + 0));
        out.heatsinkTemp = sanitise(readF32Le(data + 4));
        break;

    case kIdDspTemperature:
        out.kind = FrameKind::DspTemperature;
        out.dspBoardTemp = sanitise(readF32Le(data + 0));
        break;

    case kIdOdometer:
        out.kind = FrameKind::Odometer;
        // Controller reports metres since reset; dashboard shows km.
        out.odometerKm = sanitise(readF32Le(data + 0)) / 1000.0f;
        out.dcBusAmpHours = sanitise(readF32Le(data + 4));
        break;

    default:
        // Identification, phase current, voltage/current vectors, back-EMF,
        // rail voltages and slip speed are valid frames the dashboard simply
        // does not consume yet. Adding one is a single case.
        break;
    }

    return out;
}

} // namespace ws22
