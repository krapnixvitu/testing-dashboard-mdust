cmake_minimum_required(VERSION 3.16)

project(SolarDashboard VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_standard_project_setup()

qt_add_executable(SolarDashboard
    main.cpp
)

qt_add_qml_module(SolarDashboard
    URI SolarDashboard
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/MockBackend.qml
        qml/RaceDashboard.qml
        qml/DebugDashboard.qml
        qml/SpeedGauge.qml
        qml/InfoBar.qml
        qml/TempBar.qml
        qml/TempReadout.qml
        qml/CriticalOverlay.qml
        qml/WarningBanner.qml
)

target_link_libraries(SolarDashboard PRIVATE
    Qt6::Quick
)
