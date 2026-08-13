#ifndef CAN_FRAME_HPP
#define CAN_FRAME_HPP

#include <cstdint>

/// @brief Result codes for CAN operations
enum class Result : uint8_t {
	R_SUCCESS = 0,
	R_TIMEOUT,
	R_NO_MESSAGE,
	R_ERROR
};

/// @brief Generic CAN frame structure (transport layer)
/// @note Hardware-agnostic representation of a CAN message
struct CanFrame {
	uint32_t id;        ///< CAN identifier (11-bit or 29-bit)
	uint8_t dlc;        ///< Data length code (0-8 bytes)
	uint8_t data[8];    ///< Payload data
};

#endif // CAN_FRAME_HPP