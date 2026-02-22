#ifndef CAN_DRIVER_HPP
#define CAN_DRIVER_HPP

#include "can_frame.hpp"
#include "driver/twai.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

/// @brief CAN driver abstraction for ESP32 TWAI peripheral
class CanDriver {
public:
	/// @brief Initialize the TWAI peripheral
	/// @return R_SUCCESS on success, R_ERROR on failure
	Result initialize();

	/// @brief Transmit a CAN frame
	/// @param frame The frame to transmit
	/// @return Result code indicating success or failure
	Result transmit(const CanFrame& frame);

	/// @brief Receive a CAN frame
	/// @param out_frame Output parameter for received frame
	/// @param timeout_ms Timeout in milliseconds (0 = no wait)
	/// @return R_SUCCESS with valid frame, R_NO_MESSAGE on timeout, R_ERROR on failure
	Result receive(CanFrame& out_frame, uint32_t timeout_ms = 0);

private:
	/// @brief Convert internal CanFrame to ESP-IDF twai_message_t
	/// @param frame Internal frame representation
	/// @return ESP-IDF TWAI message
	twai_message_t toTwaiMessage(const CanFrame& frame) const;

	/// @brief Convert ESP-IDF twai_message_t to internal CanFrame
	/// @param msg ESP-IDF TWAI message
	/// @return Internal frame representation
	CanFrame fromTwaiMessage(const twai_message_t& msg) const;
};


inline Result CanDriver::initialize() {
	// Configure TWAI timing (500 kbps for typical automotive CAN)
	twai_timing_config_t timing_config = TWAI_TIMING_CONFIG_500KBITS();

	// Configure TWAI filter to accept all messages
	twai_filter_config_t filter_config = TWAI_FILTER_CONFIG_ACCEPT_ALL();

	// Configure TWAI general settings (adjust GPIO pins as needed)
	twai_general_config_t general_config = TWAI_GENERAL_CONFIG_DEFAULT(
		GPIO_NUM_21,  // TX pin
		GPIO_NUM_22,  // RX pin
		TWAI_MODE_NORMAL
	);

	// Install TWAI driver
	esp_err_t err = twai_driver_install(&general_config, &timing_config, &filter_config);
	if (err != ESP_OK) {
		return Result::R_ERROR;
	}

	// Start TWAI driver
	err = twai_start();
	if (err != ESP_OK) {
		twai_driver_uninstall(); // Cleanup on failure
		return Result::R_ERROR;
	}

	return Result::R_SUCCESS;
}

inline Result CanDriver::transmit(const CanFrame& frame) {
	twai_message_t msg = toTwaiMessage(frame);

	// Transmit with 10ms timeout, appropriate since at 500kbps a can frame will take less than 1ms
	esp_err_t err = twai_transmit(&msg, pdMS_TO_TICKS(10));

	switch (err) {
	case ESP_OK:
		return Result::R_SUCCESS;
	case ESP_ERR_TIMEOUT:
		return Result::R_TIMEOUT;
	default:
		return Result::R_ERROR;
	}
}

inline Result CanDriver::receive(CanFrame& out_frame, uint32_t timeout_ms) {
	twai_message_t msg;

	// Convert timeout to FreeRTOS ticks
	TickType_t ticks = (timeout_ms == 0) ? 0 : pdMS_TO_TICKS(timeout_ms);

	esp_err_t err = twai_receive(&msg, ticks);

	switch (err) {
	case ESP_OK:
		out_frame = fromTwaiMessage(msg);
		return Result::R_SUCCESS;
	case ESP_ERR_TIMEOUT:
		return Result::R_NO_MESSAGE;
	default:
		return Result::R_ERROR;
	}
}

inline twai_message_t CanDriver::toTwaiMessage(const CanFrame& frame) const {
	twai_message_t msg{};
	msg.identifier = frame.id;
	msg.data_length_code = frame.dlc;
	msg.extd = 0;  // Standard 11-bit identifier
	msg.rtr = 0;   // Data frame (not remote transmission request)
	msg.ss = 0;    // Not single shot
	msg.self = 0;  // Not self-reception request
	msg.dlc_non_comp = 0;  // DLC is compliant

	// Copy payload data
	for (uint8_t i = 0; i < frame.dlc && i < 8; ++i) {
		msg.data[i] = frame.data[i];
	}

	return msg;
}

inline CanFrame CanDriver::fromTwaiMessage(const twai_message_t& msg) const {
	CanFrame frame{};
	frame.id = msg.identifier;
	frame.dlc = msg.data_length_code;

	// Copy payload data
	for (uint8_t i = 0; i < msg.data_length_code && i < 8; ++i) {
		frame.data[i] = msg.data[i];
	}

	return frame;
}

#endif // CAN_DRIVER_HPP