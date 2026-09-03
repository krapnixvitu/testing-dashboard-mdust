Here is a technical specification of all regulatory requirements for the driver’s screen and dashboard based on the **2024 iLumen European Solar Challenge (iESC)** regulations. You can pass this list directly into Claude Code as your design prompt or functional specification.

### 1\. Mandatory Display Elements (Reg. 2.26.1) 1

The regulations state that the following information **must be provided to the driver at all times while driving**:

* **Vehicle Speed**: Real-time display of current vehicle speed 1\.  
* **Direction Indicator Verification**: Visual indicator showing whether the left or right turn signals are active 1 (flashing rate: \\\\(90 \\pm 30\\\\) flashes/minute 2).  
* **Hazard Lights Verification**: Visual indicator verifying that all direction indicators are flashing simultaneously as a hazard signal 1, 2\.  
* **Energy Storage System (ESS) Warnings**: Visual alert system notifying the driver if any battery parameter exceeds safe operating limits 1\.  
* **Electronic Rear-Vision Feed** *(If used instead of/alongside mirrors)*: Continuous live video feed showing the area directly behind the vehicle 1, 3\.

### 2\. Rear-Vision Screen Specifications (Reg. 2.18) 3, 4

If you are displaying a digital rear-view camera feed on the driver's screen:

* **Continuous Operation**: Must operate at all times whenever the vehicle is in motion under its own power or about to be driven 4\.  
* **Image Mirroring Orientation**: Images **must be oriented so that objects on the right side of the solar car appear on the right side of the display image** (i.e., properly mirrored like a standard rear-view mirror) 4\.  
* **Coverage Field**: Must allow the driver, while belted into the seat, to clearly view the ground coverage area defined by UNECE Regulation 46 3\.

### 3\. Energy Storage System (ESS) Warning Logic (Reg. 2.5 & 3.5) 5-7

While individual cell/module voltages and temperatures **do not** need to be continuously displayed to the driver, the warning system on the screen must trigger when any cell breaches the manufacturer's datasheet limits 5, 6:

* **Trigger Conditions**:  
* Cell voltage falls below minimum allowed voltage 5\.  
* Cell voltage exceeds maximum allowed voltage 5\.  
* Discharge/charge current exceeds maximum rating 5\.  
* Cell temperature exceeds maximum or falls below minimum operating limits 5\.  
* **Fail-Safe Behavior**: In addition to displaying a high-priority visual warning, critical faults must automatically trigger an electrical "safe state" where the main battery is isolated 8, 9\.

### 4\. Power & Electrical Architecture Constraints (Reg. 2.26.2 & 2.30) 1, 10, 11

* **Main Power Source**: The dashboard display and instrumentation **must be powered directly from the main energy storage system (traction battery)**, not from separate isolated batteries 1\.  
* **Auxiliary Power Integration**: Mandatory systems like emergency hazard lights and the external safe-to-touch green indicator are backed by a separate auxiliary battery (minimum 10 Wh, max 48 V) that must run for at least 60 minutes during a main battery cut-off 10-12.

### 5\. Control & State Indicators (Reg. 2.27) 13

If your screen integrates drive modes or cruise control statuses:

* **Cruise Control Status**: If cruise control is enabled, the UI must reflect its status, and it must automatically deactivate whenever the brake pedal is pressed or the vehicle is turned off 13\.  
* **Autonomous/Automatic Functions**: Must clearly show active state and immediately disengage upon manual input 13\.

