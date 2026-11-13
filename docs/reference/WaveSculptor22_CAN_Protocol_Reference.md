# WaveSculptor22 CAN Communications Protocol Reference

## 1. Hardware & Physical Layer
* **Standard:** CAN 2.0B compatible (uses standard 11-bit identifier length).
* **Supported Bit Rates:** 1 Mbps, 500 kbps (default), 250 kbps, 125 kbps, 100 kbps, and 50 kbps.

## 2. Addressing & Identifier Format
The 11-bit Identifier field is split into two sections:
* **Bits 10–5:** Device Identifier (Max 63 devices. The 64th is reserved for the bootloader).
* **Bits 4–0:** Message Identifier (Up to 31 different message types per device).

**Base Address Calculation:**
`Base Address = Device Identifier * 32`
*(e.g., A Device ID of 0x14 results in a Base Address of 0x400)*

**Reserved IDs:** 
`0x7F0` to `0x7FF` are reserved for the bootloader (System reset broadcasts on `0x7F1` at 500 kbps).

## 3. Data Field & Endianness
* **Payload Size:** Fixed at 8 bytes (64 bits).
* **Byte Order:** Least Significant Byte (LSB) first / Little Endian. 
* **Programming Note:** Because it is LSB first, a 64-bit payload can be directly overlaid onto a `float[2]` array or cast directly to variables using `memcpy` on a Little-Endian CPU (like Intel x86 or ARM Cortex).
    * **Bits 31..0 (Low Word):** Maps perfectly to **Bytes 0–3**.
    * **Bits 63..32 (High Word):** Maps perfectly to **Bytes 4–7**.

---

## 4. Drive Commands (Controller Inputs)
Sent from driver controls to the motor controller. 
* **Note on Percentages (%):** Send as a floating-point value between `0.0` and `1.0` (Do NOT send `100.0`).
* **Timeout:** A Motor Drive Command must be received at least every 250ms, otherwise the controller defaults to neutral/coast.

### Motor Drive Command (ID: Base + 0x01)
*Interval: 100ms*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Motor Current** | 63..32 | 4–7 | 32-bit Float | Desired current set point as % of max current (0.0 to 1.0). |
| **Motor Velocity**| 31..0  | 0–3 | 32-bit Float | Desired motor velocity set point in rpm. |

### Motor Power Command (ID: Base + 0x02)
*Interval: 100ms*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Bus Current** | 63..32 | 4–7 | 32-bit Float | Desired set point of current drawn from bus as % of absolute bus current limit. |
| **Reserved**    | 31..0  | 0–3 | - | - |

### Reset Command (ID: Base + 0x03)
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Unused** | 63..32 | 4–7 | - | - |
| **Unused** | 31..0  | 0–3 | - | Send a command from this address to reset the controller software. |

---

## 5. Telemetry & Broadcast Messages (Controller Outputs)
Can be configured for periodic broadcast or requested at any time by sending an RTR (Remote Transmission Request) packet with no payload to the specific ID. All IEEE floats are transmitted Little Endian.

### Identification Information (ID: Base + 0x00)
*Interval: 1s (Cannot be disabled)*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Serial Number** | 63..32 | 4–7 | Uint32 | Device serial number allocated at manufacture. |
| **Prohelion ID**  | 31..0  | 0–3 | Uint32 | Device identifier (0x00004003). |

### Status Information (ID: Base + 0x01)
*Interval: 200ms*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Rx Error Count** | 63..56 | 7 | Uint8 | DSP CAN receive error counter. |
| **Tx Error Count** | 55..48 | 6 | Uint8 | DSP CAN transmission error counter. |
| **Active Motor**   | 47..32 | 4–5 | Uint16 | Index of the active motor currently used. |
| **Error Flags**    | 31..16 | 2–3 | Uint16 | Bitfield of error states (See bit map below). |
| **Limit Flags**    | 15..0  | 0–1 | Uint16 | Bitfield of control loop limits (See bit map below). |

**Error Flags Bit Map:**
* `Bit 8`: Motor Over Speed (15% overshoot)
* `Bit 7`: Desaturation Fault
* `Bit 6`: 15V Rail under voltage (UVLO)
* `Bit 5`: Config read error
* `Bit 4`: Watchdog caused last reset
* `Bit 3`: Bad motor position hall sequence
* `Bit 2`: DC Bus over voltage
* `Bit 1`: Software over current
* `Bit 0`: Hardware over current

**Limit Flags Bit Map:**
* `Bit 6`: IPM Temp or Motor Temp Limit
* `Bit 5`: Bus Voltage Lower Limit
* `Bit 4`: Bus Voltage Upper Limit
* `Bit 3`: Bus Current Limit
* `Bit 2`: Velocity Limit
* `Bit 1`: Motor Current Limit
* `Bit 0`: Output Voltage PWM Limit

### Bus Measurement (ID: Base + 0x02)
*Interval: 200ms*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Bus Current** | 63..32 | 4–7 | 32-bit Float | Current drawn from the DC bus by the controller (A). |
| **Bus Voltage** | 31..0  | 0–3 | 32-bit Float | DC bus voltage at the controller (V). |

### Velocity Measurement (ID: Base + 0x03)
*Interval: 200ms*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Vehicle Velocity** | 63..32 | 4–7 | 32-bit Float | Vehicle velocity (m/s). |
| **Motor Velocity**   | 31..0  | 0–3 | 32-bit Float | Motor angular frequency (rpm). |

### Phase Current Measurement (ID: Base + 0x04)
*Interval: 200ms*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Phase C Current** | 63..32 | 4–7 | 32-bit Float | RMS current in motor Phase C (Arms). |
| **Phase B Current** | 31..0  | 0–3 | 32-bit Float | RMS current in motor Phase B (Arms). |

### Motor Voltage Vector Measurement (ID: Base + 0x05)
*Interval: 200ms*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Vd** | 63..32 | 4–7 | 32-bit Float | Real component of applied voltage vector (V). |
| **Vq** | 31..0  | 0–3 | 32-bit Float | Imaginary component of applied voltage vector (V). |

### Motor Current Vector Measurement (ID: Base + 0x06)
*Interval: 200ms*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Id** | 63..32 | 4–7 | 32-bit Float | Real component (Field current) (A). |
| **Iq** | 31..0  | 0–3 | 32-bit Float | Imaginary component (Torque producing current) (A). |

### Motor BackEMF Measurement/Prediction (ID: Base + 0x07)
*Interval: 200ms*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **BEMFd** | 63..32 | 4–7 | 32-bit Float | By definition this value is always 0V. |
| **BEMFq** | 31..0  | 0–3 | 32-bit Float | Peak of the phase to neutral motor voltage (V). |

### 15V Voltage Rail Measurement (ID: Base + 0x08)
*Interval: 1s*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **15V Supply** | 63..32 | 4–7 | 32-bit Float | Actual voltage level of the 15V power rail. |
| **Reserved**   | 31..0  | 0–3 | - | - |

### 3.3V & 1.9V Voltage Rail Measurement (ID: Base + 0x09)
*Interval: 1s*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **3.3V Supply** | 63..32 | 4–7 | 32-bit Float | Actual voltage level of the 3.3V power rail. |
| **1.9V Supply** | 31..0  | 0–3 | 32-bit Float | Actual voltage level of the 1.9V DSP power rail. |

### Heat-sink & Motor Temperature Measurement (ID: Base + 0x0B)
*Interval: 1s*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Heat-sink Temp** | 63..32 | 4–7 | 32-bit Float | Internal temperature of Heat-sink case (°C). |
| **Motor Temp**     | 31..0  | 0–3 | 32-bit Float | Internal temperature of the motor (°C). |

### DSP Board Temperature Measurement (ID: Base + 0x0C)
*Interval: 1s*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Reserved**       | 63..32 | 4–7 | - | - |
| **DSP Board Temp** | 31..0  | 0–3 | 32-bit Float | Temperature of the DSP board (°C). |

### Odometer & Bus AmpHours Measurement (ID: Base + 0x0E)
*Interval: 1s*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **DC Bus AmpHours** | 63..32 | 4–7 | 32-bit Float | Charge flow into controller DC bus since reset (Ah). |
| **Odometer**        | 31..0  | 0–3 | 32-bit Float | Distance the vehicle has travelled since reset (m). |

### Slip Speed Measurement (ID: Base + 0x17)
*Interval: 200ms*
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Slip Speed** | 63..32 | 4–7 | 32-bit Float | Slip speed when driving an induction motor (Hz). |
| **Reserved**   | 31..0  | 0–3 | - | - |

---

## 6. Configuration Commands

### Active Motor Change (ID: Base + 0x12)
Send this command to change the active motor (saves to EEPROM config memory; avoid sending constantly).
| Variable | Bits | Bytes | Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Active Motor** | 63..48 | 6–7 | Uint16 | Desired active motor (0 to 9). |
| **Access Key**   | 47..0  | 0–5 | ASCII  | Must spell "ACTMOT" in ASCII (`0x54 4F 4D 54 43 41`). |
