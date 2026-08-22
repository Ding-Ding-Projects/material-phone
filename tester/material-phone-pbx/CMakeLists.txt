cmake_minimum_required(VERSION 3.16)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    project(material_phone_pbx_tests LANGUAGES CXX)
    enable_testing()
endif()

if(NOT TARGET material_phone_pbx)
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../../Linphone/pbx"
                     "${CMAKE_CURRENT_BINARY_DIR}/pbx")
endif()

add_executable(material_phone_pbx_tests pbx_provider_tests.cpp)
target_link_libraries(material_phone_pbx_tests PRIVATE material_phone_pbx)
target_compile_features(material_phone_pbx_tests PRIVATE cxx_std_17)
set_target_properties(material_phone_pbx_tests PROPERTIES CXX_EXTENSIONS OFF)

if(MSVC)
    target_compile_options(material_phone_pbx_tests PRIVATE /W4 /permissive-)
else()
    target_compile_options(material_phone_pbx_tests PRIVATE -Wall -Wextra -Wpedantic)
endif()

add_test(NAME pbx.registry_list COMMAND material_phone_pbx_tests --list)
add_test(NAME pbx.all COMMAND material_phone_pbx_tests --all)
