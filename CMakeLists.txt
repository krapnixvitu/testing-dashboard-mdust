cmake_minimum_required(VERSION 3.16)

project(SolarDashboard VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Svg)

qt_standard_project_setup()

qt_add_executable(SolarDashboard
    main.cpp
    src/WaveSculptorDecoder.h
    src/WaveSculptorDecoder.cpp
    src/VehicleData.h
    src/VehicleData.cpp
    src/VehicleSimulator.h
    src/VehicleSimulator.cpp
    src/SocketCanReader.h
    src/SocketCanReader.cpp
)

qt_add_qml_module(SolarDashboard
    URI SolarDashboard
    VERSION 1.0
    # The URI matches the executable target name, so Qt's default module
    # output directory (build/SolarDashboard) is the same path as the binary
    # itself on any platform without an .exe suffix. On Linux this fails at
    # link time with "cannot open output file SolarDashboard: Is a directory".
    # Nesting the module output one level deeper keeps the final directory
    # named after the URI, which filesystem imports need, without the clash.
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/qml_modules/SolarDashboard
    QML_FILES
        qml/Main.qml
        qml/RaceDashboard.qml
        qml/DebugDashboard.qml
        qml/SpeedGauge.qml
        qml/InfoBar.qml
        qml/TempBar.qml
        qml/TempReadout.qml
        qml/CriticalOverlay.qml
        qml/WarningBanner.qml
        qml/ArrowIndicator.qml
        qml/HazardIndicator.qml
    RESOURCES
        assets/images/mdu-solar-team-logo.png
        assets/images/blinker-left.svg
        assets/images/blinker-right.svg
        assets/images/blinker-left-day.svg
        assets/images/blinker-right-day.svg
        assets/images/hazard.svg
)

target_link_libraries(SolarDashboard PRIVATE
    Qt6::Quick
    Qt6::Svg
)

# ── Decoder tests ────────────────────────────────────────────────────────
# The decoder has no Qt or socket dependencies, so this builds and runs on
# any platform without CAN hardware. Build with -DBUILD_TESTING=ON.
option(BUILD_TESTING "Build the decoder unit tests" OFF)

if(BUILD_TESTING)
    enable_testing()

    # Pure decoder: no Qt, no sockets, no moc.
    add_executable(test_decoder
        tests/test_decoder.cpp
        src/WaveSculptorDecoder.cpp
    )
    set_target_properties(test_decoder PROPERTIES AUTOMOC OFF)

    add_test(NAME decoder COMMAND test_decoder)

    # Source-ownership rules. Needs Qt Core for QObject, but not Quick: these
    # are backend rules, not UI, so they run headless.
    add_executable(test_vehicledata
        tests/test_vehicledata.cpp
        src/VehicleData.cpp
        src/WaveSculptorDecoder.cpp
    )
    target_link_libraries(test_vehicledata PRIVATE Qt6::Core)

    add_test(NAME vehicledata COMMAND test_vehicledata)
endif()
