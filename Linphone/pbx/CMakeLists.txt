cmake_minimum_required(VERSION 3.16)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    project(material_phone_pbx LANGUAGES CXX)
endif()

add_library(material_phone_pbx STATIC
    src/pbx_provider.cpp
    src/simulator_pbx_provider.cpp
)

target_include_directories(material_phone_pbx
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

target_compile_features(material_phone_pbx PUBLIC cxx_std_17)
set_target_properties(material_phone_pbx PROPERTIES
    CXX_EXTENSIONS OFF
    POSITION_INDEPENDENT_CODE ON
)

if(MSVC)
    target_compile_options(material_phone_pbx PRIVATE /W4 /permissive-)
else()
    target_compile_options(material_phone_pbx PRIVATE -Wall -Wextra -Wpedantic)
endif()

option(MATERIAL_PHONE_PBX_BUILD_TESTS "Build the standalone PBX provider tests" OFF)
if(MATERIAL_PHONE_PBX_BUILD_TESTS)
    enable_testing()
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../../tester/material-phone-pbx"
                     "${CMAKE_CURRENT_BINARY_DIR}/tests")
endif()
