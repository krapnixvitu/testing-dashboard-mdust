import QtQuick

QtObject {
    id: root

    // ── Velocity (from VelocityMeasurement 0x403) ──
    property real vehicleSpeed: 0.0   // km/h (converted from m/s)
    property real motorRpm: 0.0       // RPM

    // ── Bus (from BusMeasurement 0x402) ──
    property real busVoltage: 120.0   // V
    property real busCurrent: 10.0    // A

    // ── Computed ──
    readonly property real netPower: busVoltage * busCurrent  // W
    property real efficiency: 0.0     // Wh/km (rolling average)

    // ── Temperatures (from 0x40B, 0x40C) ──
    property real motorTemp: 45.0     // °C
    property real heatsinkTemp: 38.0  // °C
    property real dspBoardTemp: 32.0  // °C

    // ── Odometer & Energy (from 0x40E) ──
    property real odometer: 0.0       // km
    property real dcBusAmpHours: 0.0  // Ah

    // ── Status (from StatusInformation 0x401) ──
    property int errorFlags: 0x0000   // 16-bit error flags
    property int limitFlags: 0x0000   // 16-bit limit flags

    // ── UI-only (not from CAN) ──
    property bool leftBlinker: false
    property bool rightBlinker: false
    property bool bmsFault: false
    property bool canHealthy: true

    // ── Internal simulation state ──
    property real _elapsed: 0.0       // seconds elapsed
    property real _targetSpeed: 60.0  // cruise target for simulation

    // ── Simulation timer (200ms, matching CAN high-frequency rate) ──
    property Timer _simTimer: Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            root._elapsed += 0.2;
            var t = root._elapsed;

            // --- Drive cycle: accelerate, cruise, decelerate, repeat ---
            var cyclePos = (t % 60.0);  // 60-second cycle
            if (cyclePos < 15) {
                // Accelerating 0 → 80 km/h
                root._targetSpeed = (cyclePos / 15.0) * 80.0;
            } else if (cyclePos < 40) {
                // Cruising around 65-80 km/h with gentle variation
                root._targetSpeed = 72.0 + 8.0 * Math.sin(t * 0.3);
            } else if (cyclePos < 50) {
                // Decelerating
                root._targetSpeed = 80.0 * (1.0 - (cyclePos - 40.0) / 10.0);
            } else {
                // Stopped / idling
                root._targetSpeed = 2.0 + Math.random() * 3.0;
            }

            // Smooth approach to target
            root.vehicleSpeed += (root._targetSpeed - root.vehicleSpeed) * 0.15;
            if (root.vehicleSpeed < 0) root.vehicleSpeed = 0;

            // Motor RPM proportional to speed (gear ratio ~17 RPM per km/h)
            root.motorRpm = root.vehicleSpeed * 17.0 + (Math.random() - 0.5) * 20.0;
            if (root.motorRpm < 0) root.motorRpm = 0;

            // Bus voltage drifts slowly (simulating battery discharge)
            root.busVoltage = 120.0 + 10.0 * Math.sin(t * 0.02) + (Math.random() - 0.5) * 2.0;

            // Bus current proportional to speed + noise
            root.busCurrent = root.vehicleSpeed * 0.18 + (Math.random() - 0.5) * 1.5;
            if (root.busCurrent < -3.0) root.busCurrent = -3.0;  // allow small regen

            // Efficiency (Wh/km) - only valid when moving
            if (root.vehicleSpeed > 5.0) {
                var instantEff = root.netPower / root.vehicleSpeed;
                root.efficiency += (instantEff - root.efficiency) * 0.05;
            }

            // Temperatures: slow drift with ambient + load component
            root.motorTemp = 45.0 + root.vehicleSpeed * 0.3 + 8.0 * Math.sin(t * 0.05) + (Math.random() - 0.5) * 2.0;
            root.heatsinkTemp = 35.0 + root.vehicleSpeed * 0.15 + 5.0 * Math.sin(t * 0.04);
            root.dspBoardTemp = 30.0 + 5.0 * Math.sin(t * 0.03) + (Math.random() - 0.5);

            // Odometer accumulates (speed in km/h * dt in hours)
            root.odometer += root.vehicleSpeed * (0.2 / 3600.0);

            // Amp-hours accumulate
            if (root.busCurrent > 0)
                root.dcBusAmpHours += root.busCurrent * (0.2 / 3600.0);

            // Limit flags: simulate velocity limiting when near cruise
            if (root.vehicleSpeed > 70.0)
                root.limitFlags = 0x0004; // Bit 2: Velocity limiting
            else if (root.busCurrent > 14.0)
                root.limitFlags = 0x0008; // Bit 3: Bus Current limiting
            else
                root.limitFlags = 0x0000;

            // Error flags: normally clear
            root.errorFlags = 0x0000;
        }
    }

    // ── Blinker timer (500ms toggle) ──
    property Timer _blinkerTimer: Timer {
        interval: 500
        running: true
        repeat: true
        property int _count: 0
        onTriggered: {
            _count++;
            // Simulate left blinker on for 10s every 30s
            var phase = (_count * 0.5) % 30.0;
            if (phase >= 10.0 && phase < 20.0) {
                root.leftBlinker = (_count % 2 === 0);
                root.rightBlinker = false;
            } else if (phase >= 20.0 && phase < 30.0) {
                root.leftBlinker = false;
                root.rightBlinker = (_count % 2 === 0);
            } else {
                root.leftBlinker = false;
                root.rightBlinker = false;
            }
        }
    }
}
