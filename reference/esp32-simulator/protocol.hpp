#ifndef PROTOCOL_HPP
#define PROTOCOL_HPP

#include "can_frame.hpp"
#include <cstdint> // For uint32_t
#include <cstring>  // For std::memcpy

/// @file protocol.hpp
/// @brief CAN protocol definitions for motor controller communication
/// @note Low float first then high float. Protocol is LITTLE ENDIAN (LSB First).

// ===========================================================
// STATIC ASSERTS TO ENSURE PLATFORM COMPATIBILITY
// ===========================================================

#include <limits>
static_assert(sizeof(float) == 4, "Platform must use 32-bit float for CAN protocol compatibility");
static_assert(std::numeric_limits<float>::is_iec559, "Platform must use IEEE 754 float representation");

// ===========================================================

// BASE ADDRESSES (Configured in the software for Wave Sculptor motor controller)
constexpr uint32_t DRIVER_CONTROLS_BASE_ADDRESS  = 0x500; ///< Base address for driver control commands
constexpr uint32_t MOTOR_CONTROLLER_BASE_ADDRESS = 0x400; ///< Base address for motor controller messages

// CAN Message Identifiers for Drive Commands
constexpr uint32_t ID_MOTOR_DRIVE_COMMAND = DRIVER_CONTROLS_BASE_ADDRESS + 0x01;   ///< Motor Controller Command, WaveSculptor22 motor controller must receive a Motor Drive Command frame at least once every 250ms!
constexpr uint32_t ID_MOTOR_POWER_COMMAND = DRIVER_CONTROLS_BASE_ADDRESS + 0x02;   ///< Motor Power Command
constexpr uint32_t ID_RESET_COMMAND 	  = DRIVER_CONTROLS_BASE_ADDRESS + 0x03;         ///< System Reset Command

// CAN Message Identifiers for Motor Controll Broadcast Messages
constexpr uint32_t ID_IDENTIFICATION_INFORMATION 	= MOTOR_CONTROLLER_BASE_ADDRESS + 0x00; ///< Identification Information (Interval 1000ms)
constexpr uint32_t ID_STATUS_INFORMATION 			= MOTOR_CONTROLLER_BASE_ADDRESS + 0x01; ///< Status Information (Interval 200ms)
constexpr uint32_t ID_BUS_MEASUREMENT 				= MOTOR_CONTROLLER_BASE_ADDRESS + 0x02; ///< Bus Measurement (Interval 200ms)
constexpr uint32_t ID_VELOCITY_MEASUREMENT 			= MOTOR_CONTROLLER_BASE_ADDRESS + 0x03; ///< Velocity Measurement (Interval 200ms)
constexpr uint32_t ID_PHASE_CURRENT_MEASUREMENT 	= MOTOR_CONTROLLER_BASE_ADDRESS + 0x04; ///< Phase Current Measurement (Interval 200ms)
constexpr uint32_t ID_MOTOR_VOLTAGE_VECTOR_MEASUREMENT 	   = MOTOR_CONTROLLER_BASE_ADDRESS + 0x05; ///< Motor Voltage Vector Measurement (Interval 200ms)
constexpr uint32_t ID_MOTOR_CURRENT_VECTOR_MEASUREMENT	   = MOTOR_CONTROLLER_BASE_ADDRESS + 0x06; ///< Motor Current Vector Measurement (Interval 200ms)
constexpr uint32_t ID_MOTOR_BACK_EMF_MEASUREMENT 		   = MOTOR_CONTROLLER_BASE_ADDRESS + 0x07; ///< Motor Back-EMF Measurement/Prediction (Interval 200ms)
constexpr uint32_t ID_15V_VOLTAGE_RAIL_MEASUREMENT 		   = MOTOR_CONTROLLER_BASE_ADDRESS + 0x08; ///< 15V Voltage Rail Measurement (Interval 1000ms)
constexpr uint32_t ID_3V3_AND_1V9_VOLTAGE_RAIL_MEASUREMENT = MOTOR_CONTROLLER_BASE_ADDRESS + 0x09; ///< 3.3V and 1.9V Voltage Rail Measurement (Interval 1000ms)
// ID: MOTOR_CONOTROLLER_BASE_ADDRESS + 0x0A is reserved
constexpr uint32_t ID_HEATSINK_AND_MOTOR_TEMPERATURE_MEASUREMENT = MOTOR_CONTROLLER_BASE_ADDRESS + 0x0B; ///< Heatsink and Motor Temperature Measurement (Interval 1000ms)
constexpr uint32_t ID_DSP_BOARD_TEMPERATURE_MEASUREMENT 		 = MOTOR_CONTROLLER_BASE_ADDRESS + 0x0C; ///< DSP Board Temperature Measurement (Interval 1000ms)
// ID: MOTOR_CONTROLLER_BASE_ADDRESS + 0x0D is reserved
constexpr uint32_t ID_ODOMETER_AND_BUS_AMP_HOURS_MEASUREMENT = MOTOR_CONTROLLER_BASE_ADDRESS + 0x0E; ///< Odometer and Bus Amp-Hours Measurement (Interval 1000ms)
constexpr uint32_t ID_SLIP_SPEED_MEASUREMENT 				 = MOTOR_CONTROLLER_BASE_ADDRESS + 0x17; ///< Slip Speed Measurement (Interval 200ms)

// CAN Message Identifiers for Configuration Commands
constexpr uint32_t ID_ACTIVE_MOTOR_CHANGE = MOTOR_CONTROLLER_BASE_ADDRESS + 0x12; ///< Active Motor Change, send this command to change the active motor (if multiple motors are configured)

// Forward Declarations of domain structs for CAN messages
struct MotorDriveCommand;
struct MotorPowerCommand;
struct ResetCommand;

struct IdentificationInformation;
struct StatusInformation;
struct BusMeasurement;
struct VelocityMeasurement;
struct PhaseCurrentMeasurement;
struct MotorVoltageVectorMeasurement;
struct MotorCurrentVectorMeasurement;
struct MotorBackEMFMeasurement;
struct VoltageRailMeasurement15V;
struct VoltageRailMeasurement3V3And1V9;
struct HeatsinkAndMotorTemperatureMeasurement;
struct DSPBoardTemperatureMeasurement;
struct OdometerAndBusAmpHoursMeasurement;
struct SlipSpeedMeasurement;

struct ActiveMotorChangeCommand;

// Forward Declarations of serialization functions
CanFrame pack(const MotorDriveCommand& cmd);
CanFrame pack(const MotorPowerCommand& cmd);
CanFrame pack(const ResetCommand& cmd);

CanFrame pack(const IdentificationInformation& info);
CanFrame pack(const StatusInformation& info);
CanFrame pack(const BusMeasurement& measurement);
CanFrame pack(const VelocityMeasurement& measurement);
CanFrame pack(const PhaseCurrentMeasurement& measurement);
CanFrame pack(const MotorVoltageVectorMeasurement& measurement);
CanFrame pack(const MotorCurrentVectorMeasurement& measurement);
CanFrame pack(const MotorBackEMFMeasurement& measurement);
CanFrame pack(const VoltageRailMeasurement15V& measurement);
CanFrame pack(const VoltageRailMeasurement3V3And1V9& measurement);
CanFrame pack(const HeatsinkAndMotorTemperatureMeasurement& measurement);
CanFrame pack(const DSPBoardTemperatureMeasurement& measurement);
CanFrame pack(const OdometerAndBusAmpHoursMeasurement& measurement);
CanFrame pack(const SlipSpeedMeasurement& measurement);

CanFrame pack(const ActiveMotorChangeCommand& cmd);

// ============================================================================
// STRUCT DEFINITIONS
// ============================================================================

/// @brief Drive command message for motor controller
struct MotorDriveCommand {
    float motor_current_percent;  ///< Motor current percentage (0-100%, always positive)
    float motor_velocity_rpm;   ///< Target velocity in RPM (positive for forward, negative for reverse)
    
    /// @brief Construct from CAN frame (deserialize)
    explicit MotorDriveCommand(const CanFrame& frame);
    
    /// @brief Default constructor  
    MotorDriveCommand() : motor_current_percent{0}, motor_velocity_rpm{0} {}
};

/// @brief Power command message for motor controller
/// @note Low float is reserved in this case, so only high float is used
struct MotorPowerCommand {
	float bus_current;  ///< Bus current in percents (0-100%)
	// The low float is reserved

	/// @brief Construct from CAN frame (deserialize)
	explicit MotorPowerCommand(const CanFrame& frame);
	
	/// @brief Default constructor  
	MotorPowerCommand() : bus_current{0} {}
};

/// @brief Reset command message for motor controller
/// @note Send a command from this address to reset the software in the WaveSculptor, not used during normal operation but can be used to reset the device if necessary
struct ResetCommand {
	// No used variables

	/// @brief Construct from CAN frame (deserialize)
	explicit ResetCommand(const CanFrame& frame);

	/// @brief Default constructor by compiler
	ResetCommand() = default;
};

/// @brief Identification information message from motor controller
/// @note Contains information that should be constant (Device serial e.g), I'll fix later
struct IdentificationInformation {
	uint32_t serial_number;	///< Device serial number of the motor controller (allocated at manufacture)
	uint32_t prohelion_ID;	///< Device identifier

	/// @brief Construct from CAN frame (deserialize)
	explicit IdentificationInformation(const CanFrame& frame);

	/// @brief Default constructor
	IdentificationInformation() : serial_number{0}, prohelion_ID{0} {}
};

/// @brief Status information message from motor controller
struct StatusInformation {
	uint8_t receive_error_count;  ///< The DSP CAN receive error counter (CAN 2.0)
	uint8_t transmit_error_count; ///< The DSP CAN transmission error counter (CAN 2.0)
	uint16_t active_motor; ///< The index of the active motor currently being used
	uint16_t error_flags; ///< Error status flags (16-bit field):
	                      ///< Bits 15-9: Reserved
	                      ///< Bit 8: Motor Over Speed (15% overshoot above max RPM)
	                      ///< Bit 7: Desaturation Fault (IGBT desaturation, IGBT driver OVLO)
	                      ///< Bit 6: 15V Rail under voltage lock out (UVLO)
	                      ///< Bit 5: Config read error (some values may be reset to defaults)
	                      ///< Bit 4: Watchdog caused last reset
	                      ///< Bit 3: Bad motor position hall sequence
	                      ///< Bit 2: DC Bus over voltage
	                      ///< Bit 1: Software over current
	                      ///< Bit 0: Hardware over current

	uint16_t limit_flags; ///< Limit status flags (16-bit field) - indicate which control loop is limiting the output current:
	                      ///< Bits 15-7: Reserved
	                      ///< Bit 6: IPM Temperature or Motor Temperature
	                      ///< Bit 5: Bus Voltage Lower Limit
	                      ///< Bit 4: Bus Voltage Upper Limit
	                      ///< Bit 3: Bus Current
	                      ///< Bit 2: Velocity
	                      ///< Bit 1: Motor Current
	                      ///< Bit 0: Output Voltage PWM

	/// @brief Construct from CAN frame (deserialize)
	explicit StatusInformation(const CanFrame& frame);

	/// @brief Default constructor
	StatusInformation() : receive_error_count{0}, transmit_error_count{0}, active_motor{0}, error_flags{0}, limit_flags{0} {}
};

/// @brief Bus measurement message from motor controller
struct BusMeasurement {
	float bus_current;  ///< (Units A) Current drawn from the DC bus by the controller.
	float bus_voltage;   ///< (Units V) DC bus voltage at the controller.

	/// @brief Construct from CAN frame (deserialize)
	explicit BusMeasurement(const CanFrame& frame);

	/// @brief Default constructor
	BusMeasurement() : bus_current{0}, bus_voltage{0} {}
};

/// @brief Velocity measurement message from motor controller
struct VelocityMeasurement {
	float vehicle_velocity; ///< (Units m/s) Vehicle velocity
	float motor_velocity_rpm;  ///< (Units RPM) Motor angular frequency in revolutions per minute

	/// @brief Construct from CAN frame (deserialize)
	explicit VelocityMeasurement(const CanFrame& frame);

	/// @brief Default constructor
	VelocityMeasurement() : vehicle_velocity{0}, motor_velocity_rpm{0} {}
};

/// @brief Phase current measurement message from motor controller
/// @note While the motor is rotating at speed these two currents should be equal. At extremely low commutation speeds these two currents will only match in one third of the motor position, the other two thirds will involve current also flowing in Phase A.
struct PhaseCurrentMeasurement {
	float phase_c_current; ///< (Units A_rms) RMS current in motor Phase C
	float phase_b_current; ///< (Units A_rms) RMS current in motor Phase B

	/// @brief Construct from CAN frame (deserialize)
	explicit PhaseCurrentMeasurement(const CanFrame& frame);

	/// @brief Default constructor
	PhaseCurrentMeasurement() : phase_c_current{0}, phase_b_current{0} {}
};

/// @brief Motor voltage vector measurement message from motor controller
struct MotorVoltageVectorMeasurement {
	float v_d; ///< (Units V) Real component of the applied non-rotating voltage vector to the motor.
	float v_q; ///< (Units V) Imaginary component of the applied non-rotating voltage vector to the motor.

	/// @brief Construct from CAN frame (deserialize)
	explicit MotorVoltageVectorMeasurement(const CanFrame& frame);

	/// @brief Default constructor
	MotorVoltageVectorMeasurement() : v_d{0}, v_q{0} {}
};

/// @brief Motor current vector measurement message from motor controller
struct MotorCurrentVectorMeasurement {
	float i_d; ///< (Units A) Real component of the applied non-rotating current vector to the motor. This vector represents the field current of the motor.
	float i_q; ///< (Units A) Imaginary component of the applied non-rotating current vector to the motor. This current produces torque in the motor and should be in phase with the back-EMF of the motor.

	/// @brief Construct from CAN frame (deserialize)
	explicit MotorCurrentVectorMeasurement(const CanFrame& frame);

	/// @brief Default constructor
	MotorCurrentVectorMeasurement() : i_d{0}, i_q{0} {}
};

/// @brief Motor back-EMF measurement message from motor controller
struct MotorBackEMFMeasurement {
	float BEMf_d; ///< (Units V) By definition this value is always 0V.
	float BEMf_q; ///< (Units V) The peak of the to neutral motor voltage.

	/// @brief Construct from CAN frame (deserialize)
	explicit MotorBackEMFMeasurement(const CanFrame& frame);

	/// @brief Default constructor
	MotorBackEMFMeasurement() : BEMf_d{0}, BEMf_q{0} {}
};

/// @brief 15V voltage rail measurement message from motor controller
struct VoltageRailMeasurement15V {
	float supply_of_15V; ///< (Units V) Actual voltage level of the 15V power rail.	
	// Low float is reserved

	/// @brief Construct from CAN frame (deserialize)
	explicit VoltageRailMeasurement15V(const CanFrame& frame);

	/// @brief Default constructor
	VoltageRailMeasurement15V() : supply_of_15V{0} {}
};

/// @brief 3.3V and 1.9V voltage rail measurement message from motor controller
struct VoltageRailMeasurement3V3And1V9 {
	float supply_of_3V3;  ///< (Units V) Actual voltage level of the 3.3V power rail.
	float supply_of_1V9;  ///< (Units V) Actual voltage level of the 1.9V DSP power rail.

	/// @brief Construct from CAN frame (deserialize)
	explicit VoltageRailMeasurement3V3And1V9(const CanFrame& frame);

	/// @brief Default constructor
	VoltageRailMeasurement3V3And1V9() : supply_of_3V3{0}, supply_of_1V9{0} {}
};

/// @brief Heatsink and motor temperature measurement message from motor controller
struct HeatsinkAndMotorTemperatureMeasurement {
	float heat_sink_temp; ///< (Units °C) Internal temperature of Heat-sink (case).
	float motor_temp; ///< (Units °C) Internal temperature of the motor.

	/// @brief Construct from CAN frame (deserialize)
	explicit HeatsinkAndMotorTemperatureMeasurement(const CanFrame& frame);

	/// @brief Default constructor
	HeatsinkAndMotorTemperatureMeasurement() : heat_sink_temp{0}, motor_temp{0} {}
};

/// @brief DSP board temperature measurement message from motor controller
struct DSPBoardTemperatureMeasurement {
	// High float reserved
	float DSP_board_temp; ///< (Units °C) Temperature of DSP board.

	/// @brief Construct from CAN frame (deserialize)
	explicit DSPBoardTemperatureMeasurement(const CanFrame& frame);

	/// @brief Default constructor
	DSPBoardTemperatureMeasurement() : DSP_board_temp{0} {}
};

/// @brief Odometer and bus amp-hours measurement message from motor controller
struct OdometerAndBusAmpHoursMeasurement {
	float DC_bus_amp_hours; ///< (Units Ah) Charge flow into the controller DC bus from the time of reset.
	float odometer; ///< (Units m) Distance the vehicle has travelled since reset.

	/// @brief Construct from CAN frame (deserialize)
	explicit OdometerAndBusAmpHoursMeasurement(const CanFrame& frame);

	/// @brief Default constructor
	OdometerAndBusAmpHoursMeasurement() : DC_bus_amp_hours{0}, odometer{0} {}
};

/// @brief Slip speed measurement message from motor controller
struct SlipSpeedMeasurement {
	float slip_speed; ///< (Units Hz) Slip speed when driving an induction motor.
	// Low float reserved

	/// @brief Construct from CAN frame (deserialize)
	explicit SlipSpeedMeasurement(const CanFrame& frame);

	/// @brief Default constructor
	SlipSpeedMeasurement() : slip_speed{0} {}
};

/// @brief Active motor change command message for motor controller
/// @note Send this command to change the active motor (if multiple motors are configured)
/// @warning Controller saves active motor to EEPROM - don't send constantly to avoid wearing out EEPROM
struct ActiveMotorChangeCommand {
	uint16_t active_motor; ///< Desired active motor index (0 to 9)
	uint8_t access_key[6]; ///< Configuration access key - must be ASCII "ACTMOT" (0x41 0x43 0x54 0x4D 0x4F 0x54)

	/// @brief Construct from CAN frame (deserialize)
	explicit ActiveMotorChangeCommand(const CanFrame& frame);

	/// @brief Default constructor - sets access key to "ACTMOT"
	ActiveMotorChangeCommand() : active_motor{0}, access_key{'A', 'C', 'T', 'M', 'O', 'T'} {}

	/// @brief Convenience constructor with motor index
	/// @param motor_index Desired active motor (0 to 9)
	explicit ActiveMotorChangeCommand(uint16_t motor_index) : active_motor{motor_index}, access_key{'A', 'C', 'T', 'M', 'O', 'T'} {}
};

// ============================================================================
// DESERIALIZATION IMPLEMENTATIONS (CAN frames -> Domain Structs)
// ============================================================================

// NOTE: We use memcpy here because the ESP32 is Little Endian and the WaveSculptor
// protocol is Little Endian. This copies the bytes directly into the correct order.

inline MotorDriveCommand::MotorDriveCommand(const CanFrame& frame) {
    // Bytes 0-3: Velocity (Little Endian)
    std::memcpy(&motor_velocity_rpm, &frame.data[0], sizeof(float));
    // Bytes 4-7: Current (Little Endian)
    std::memcpy(&motor_current_percent, &frame.data[4], sizeof(float));
}

inline MotorPowerCommand::MotorPowerCommand(const CanFrame& frame) {
    // Bytes 4-7: Bus Current (Little Endian)
    std::memcpy(&bus_current, &frame.data[4], sizeof(float));
}

inline ResetCommand::ResetCommand(const CanFrame& /*frame*/) {
	// No data to unpack
}

inline IdentificationInformation::IdentificationInformation(const CanFrame& frame) {
    // Bytes 0-3: Prohelion ID (Little Endian)
    std::memcpy(&prohelion_ID, &frame.data[0], sizeof(uint32_t));
    // Bytes 4-7: Serial Number (Little Endian)
    std::memcpy(&serial_number, &frame.data[4], sizeof(uint32_t));
}

inline StatusInformation::StatusInformation(const CanFrame& frame) {
    // Bytes 0-1: Limit Flags (Little Endian)
    std::memcpy(&limit_flags, &frame.data[0], sizeof(uint16_t));
    // Bytes 2-3: Error Flags (Little Endian)
    std::memcpy(&error_flags, &frame.data[2], sizeof(uint16_t));
    // Bytes 4-5: Active Motor (Little Endian)
    std::memcpy(&active_motor, &frame.data[4], sizeof(uint16_t));
    
    transmit_error_count = frame.data[6];
    receive_error_count = frame.data[7];
}

inline BusMeasurement::BusMeasurement(const CanFrame& frame) {
    std::memcpy(&bus_voltage, &frame.data[0], sizeof(float));
    std::memcpy(&bus_current, &frame.data[4], sizeof(float));
}

inline VelocityMeasurement::VelocityMeasurement(const CanFrame& frame) {
    std::memcpy(&motor_velocity_rpm, &frame.data[0], sizeof(float));
    std::memcpy(&vehicle_velocity, &frame.data[4], sizeof(float));
}

inline PhaseCurrentMeasurement::PhaseCurrentMeasurement(const CanFrame& frame) {
    std::memcpy(&phase_b_current, &frame.data[0], sizeof(float));
    std::memcpy(&phase_c_current, &frame.data[4], sizeof(float));
}

inline MotorVoltageVectorMeasurement::MotorVoltageVectorMeasurement(const CanFrame& frame) {
    std::memcpy(&v_q, &frame.data[0], sizeof(float));
    std::memcpy(&v_d, &frame.data[4], sizeof(float));
}

inline MotorCurrentVectorMeasurement::MotorCurrentVectorMeasurement(const CanFrame& frame) {
    std::memcpy(&i_q, &frame.data[0], sizeof(float));
    std::memcpy(&i_d, &frame.data[4], sizeof(float));
}

inline MotorBackEMFMeasurement::MotorBackEMFMeasurement(const CanFrame& frame) {
    std::memcpy(&BEMf_q, &frame.data[0], sizeof(float));
    std::memcpy(&BEMf_d, &frame.data[4], sizeof(float));
}

inline VoltageRailMeasurement15V::VoltageRailMeasurement15V(const CanFrame& frame) {
    std::memcpy(&supply_of_15V, &frame.data[4], sizeof(float));
}

inline VoltageRailMeasurement3V3And1V9::VoltageRailMeasurement3V3And1V9(const CanFrame& frame) {
    std::memcpy(&supply_of_1V9, &frame.data[0], sizeof(float));
    std::memcpy(&supply_of_3V3, &frame.data[4], sizeof(float));
}

inline HeatsinkAndMotorTemperatureMeasurement::HeatsinkAndMotorTemperatureMeasurement(const CanFrame& frame) {
    std::memcpy(&motor_temp, &frame.data[0], sizeof(float));
    std::memcpy(&heat_sink_temp, &frame.data[4], sizeof(float));
}

inline DSPBoardTemperatureMeasurement::DSPBoardTemperatureMeasurement(const CanFrame& frame) {
    std::memcpy(&DSP_board_temp, &frame.data[0], sizeof(float));
}

inline OdometerAndBusAmpHoursMeasurement::OdometerAndBusAmpHoursMeasurement(const CanFrame& frame) {
    std::memcpy(&odometer, &frame.data[0], sizeof(float));
    std::memcpy(&DC_bus_amp_hours, &frame.data[4], sizeof(float));
}

inline SlipSpeedMeasurement::SlipSpeedMeasurement(const CanFrame& frame) {
    std::memcpy(&slip_speed, &frame.data[4], sizeof(float));
}

inline ActiveMotorChangeCommand::ActiveMotorChangeCommand(const CanFrame& frame) {
    // Access key is ASCII, order is just array index
    access_key[0] = frame.data[0];
    access_key[1] = frame.data[1];
    access_key[2] = frame.data[2];
    access_key[3] = frame.data[3];
    access_key[4] = frame.data[4];
    access_key[5] = frame.data[5];
    
    std::memcpy(&active_motor, &frame.data[6], sizeof(uint16_t));
}

// ============================================================================
// SERIALIZATION FUNCTIONS (Domain Structs -> CAN frames)
// ============================================================================

inline CanFrame pack(const MotorDriveCommand& cmd) {
	CanFrame frame{};
	frame.id = ID_MOTOR_DRIVE_COMMAND;
	frame.dlc = 8;
    // Little Endian Copy
	std::memcpy(&frame.data[0], &cmd.motor_velocity_rpm, sizeof(float));
	std::memcpy(&frame.data[4], &cmd.motor_current_percent, sizeof(float));
	return frame;
}

inline CanFrame pack(const MotorPowerCommand& cmd) {
	CanFrame frame{};
	frame.id = ID_MOTOR_POWER_COMMAND;
	frame.dlc = 8;
	std::memset(frame.data, 0, 4); // Reserved
	std::memcpy(&frame.data[4], &cmd.bus_current, sizeof(float));
	return frame;
}

inline CanFrame pack(const ResetCommand& /*cmd*/) {
	CanFrame frame{};
	frame.id = ID_RESET_COMMAND;
	frame.dlc = 0;
	return frame;
}

inline CanFrame pack(const IdentificationInformation& info) {
	CanFrame frame{};
	frame.id = ID_IDENTIFICATION_INFORMATION;
	frame.dlc = 8;
	std::memcpy(&frame.data[0], &info.prohelion_ID, sizeof(uint32_t));
	std::memcpy(&frame.data[4], &info.serial_number, sizeof(uint32_t));
	return frame;
}

inline CanFrame pack(const StatusInformation& info) {
	CanFrame frame{};
	frame.id = ID_STATUS_INFORMATION;
	frame.dlc = 8;
	std::memcpy(&frame.data[0], &info.limit_flags, sizeof(uint16_t));
	std::memcpy(&frame.data[2], &info.error_flags, sizeof(uint16_t));
	std::memcpy(&frame.data[4], &info.active_motor, sizeof(uint16_t));
	frame.data[6] = info.transmit_error_count;
	frame.data[7] = info.receive_error_count;
	return frame;
}

inline CanFrame pack(const BusMeasurement& measurement) {
	CanFrame frame{};
	frame.id = ID_BUS_MEASUREMENT;
	frame.dlc = 8;
	std::memcpy(&frame.data[0], &measurement.bus_voltage, sizeof(float));
	std::memcpy(&frame.data[4], &measurement.bus_current, sizeof(float));
	return frame;
}

inline CanFrame pack(const VelocityMeasurement& measurement) {
	CanFrame frame{};
	frame.id = ID_VELOCITY_MEASUREMENT;
	frame.dlc = 8;
	std::memcpy(&frame.data[0], &measurement.motor_velocity_rpm, sizeof(float));
	std::memcpy(&frame.data[4], &measurement.vehicle_velocity, sizeof(float));
	return frame;
}

inline CanFrame pack(const PhaseCurrentMeasurement& measurement) {
	CanFrame frame{};
	frame.id = ID_PHASE_CURRENT_MEASUREMENT;
	frame.dlc = 8;
	std::memcpy(&frame.data[0], &measurement.phase_b_current, sizeof(float));
	std::memcpy(&frame.data[4], &measurement.phase_c_current, sizeof(float));
	return frame;
}

inline CanFrame pack(const MotorVoltageVectorMeasurement& measurement) {
	CanFrame frame{};
	frame.id = ID_MOTOR_VOLTAGE_VECTOR_MEASUREMENT;
	frame.dlc = 8;
	std::memcpy(&frame.data[0], &measurement.v_q, sizeof(float));
	std::memcpy(&frame.data[4], &measurement.v_d, sizeof(float));
	return frame;
}

inline CanFrame pack(const MotorCurrentVectorMeasurement& measurement) {
	CanFrame frame{};
	frame.id = ID_MOTOR_CURRENT_VECTOR_MEASUREMENT;
	frame.dlc = 8;
	std::memcpy(&frame.data[0], &measurement.i_q, sizeof(float));
	std::memcpy(&frame.data[4], &measurement.i_d, sizeof(float));
	return frame;
}

inline CanFrame pack(const MotorBackEMFMeasurement& measurement) {
	CanFrame frame{};
	frame.id = ID_MOTOR_BACK_EMF_MEASUREMENT;
	frame.dlc = 8;
	std::memcpy(&frame.data[0], &measurement.BEMf_q, sizeof(float));
	std::memcpy(&frame.data[4], &measurement.BEMf_d, sizeof(float));
	return frame;
}

inline CanFrame pack(const VoltageRailMeasurement15V& measurement) {
	CanFrame frame{};
	frame.id = ID_15V_VOLTAGE_RAIL_MEASUREMENT;
	frame.dlc = 8;
	std::memset(frame.data, 0, 4);
	std::memcpy(&frame.data[4], &measurement.supply_of_15V, sizeof(float));
	return frame;
}

inline CanFrame pack(const VoltageRailMeasurement3V3And1V9& measurement) {
	CanFrame frame{};
	frame.id = ID_3V3_AND_1V9_VOLTAGE_RAIL_MEASUREMENT;
	frame.dlc = 8;
	std::memcpy(&frame.data[0], &measurement.supply_of_1V9, sizeof(float));
	std::memcpy(&frame.data[4], &measurement.supply_of_3V3, sizeof(float));
	return frame;
}

inline CanFrame pack(const HeatsinkAndMotorTemperatureMeasurement& measurement) {
	CanFrame frame{};
	frame.id = ID_HEATSINK_AND_MOTOR_TEMPERATURE_MEASUREMENT;
	frame.dlc = 8;
	std::memcpy(&frame.data[0], &measurement.motor_temp, sizeof(float));
	std::memcpy(&frame.data[4], &measurement.heat_sink_temp, sizeof(float));
	return frame;
}

inline CanFrame pack(const DSPBoardTemperatureMeasurement& measurement) {
	CanFrame frame{};
	frame.id = ID_DSP_BOARD_TEMPERATURE_MEASUREMENT;
	frame.dlc = 8;
	std::memcpy(&frame.data[0], &measurement.DSP_board_temp, sizeof(float));
	std::memset(&frame.data[4], 0, 4);
	return frame;
}

inline CanFrame pack(const OdometerAndBusAmpHoursMeasurement& measurement) {
	CanFrame frame{};
	frame.id = ID_ODOMETER_AND_BUS_AMP_HOURS_MEASUREMENT;
	frame.dlc = 8;
	std::memcpy(&frame.data[0], &measurement.odometer, sizeof(float));
	std::memcpy(&frame.data[4], &measurement.DC_bus_amp_hours, sizeof(float));
	return frame;
}

inline CanFrame pack(const SlipSpeedMeasurement& measurement) {
	CanFrame frame{};
	frame.id = ID_SLIP_SPEED_MEASUREMENT;
	frame.dlc = 8;
	std::memset(frame.data, 0, 4);
	std::memcpy(&frame.data[4], &measurement.slip_speed, sizeof(float));
	return frame;
}

inline CanFrame pack(const ActiveMotorChangeCommand& cmd) {
	CanFrame frame{};
	frame.id = ID_ACTIVE_MOTOR_CHANGE;
	frame.dlc = 8;
	frame.data[0] = cmd.access_key[0];
	frame.data[1] = cmd.access_key[1];
	frame.data[2] = cmd.access_key[2];
	frame.data[3] = cmd.access_key[3];
	frame.data[4] = cmd.access_key[4];
	frame.data[5] = cmd.access_key[5];
	std::memcpy(&frame.data[6], &cmd.active_motor, sizeof(uint16_t));
	return frame;
}

#endif // PROTOCOL_HPP