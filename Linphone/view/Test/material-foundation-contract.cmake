cmake_minimum_required(VERSION 3.22)

set(_view_root "${CMAKE_CURRENT_LIST_DIR}/..")
set(_linphone_root "${_view_root}/..")
set(_required_files
    Style/MaterialTheme.qml
    Style/MaterialTokens.qml
    Style/MaterialType.qml
    Control/Material/MaterialSurface.qml
    Control/Material/MaterialButton.qml
    Control/Material/MaterialIconButton.qml
    Control/Material/MaterialTextField.qml
    Control/Material/MaterialNavigationBar.qml
    Page/Layout/Main/AdaptivePhoneShell.qml
    Test/MaterialFoundationTest.qml
)

foreach(_relative IN LISTS _required_files)
    if(NOT EXISTS "${_view_root}/${_relative}")
        message(FATAL_ERROR "Material foundation contract is missing ${_relative}")
    endif()
endforeach()

file(READ "${_view_root}/CMakeLists.txt" _qml_registry)
foreach(_relative IN LISTS _required_files)
    string(FIND "${_qml_registry}" "view/${_relative}" _registration_index)
    if(_registration_index EQUAL -1)
        message(FATAL_ERROR "QML registry is missing exact path view/${_relative}")
    endif()
endforeach()

file(READ "${_view_root}/Style/MaterialTokens.qml" _tokens)
foreach(_token IN ITEMS touchTarget compactBreakpoint mediumBreakpoint elevationLevel5 motionLong1)
    if(NOT _tokens MATCHES "property int ${_token}:")
        message(FATAL_ERROR "Material token contract is missing exact token ${_token}")
    endif()
endforeach()

file(READ "${_view_root}/Page/Layout/Main/AdaptivePhoneShell.qml" _shell)
foreach(_contract IN ITEMS navigationModel currentIndex compact destinationActivated)
    if(NOT _shell MATCHES "property[^\n]* ${_contract}:|signal ${_contract}\\(")
        message(FATAL_ERROR "Adaptive shell contract is missing exact member ${_contract}")
    endif()
endforeach()

file(READ "${_linphone_root}/application_info.cmake" _identity)
foreach(_identity_line IN ITEMS
        "APPLICATION_ID \"com.dingdingprojects.materialphone\""
        "APPLICATION_NAME \"Material Phone\""
        "APPLICATION_VENDOR \"Ding Ding Projects\"")
    if(NOT _identity MATCHES "set\\(${_identity_line}\\)")
        message(FATAL_ERROR "Stable application identity is missing ${_identity_line}")
    endif()
endforeach()

file(READ "${_linphone_root}/data/config/linphonerc-factory" _factory_config)
foreach(_factory_line IN ITEMS
        "product_id=com.dingdingprojects.materialphone"
        "product_name=Material Phone"
        "product_vendor=Ding Ding Projects")
    string(FIND "${_factory_config}" "${_factory_line}" _factory_index)
    if(_factory_index EQUAL -1)
        message(FATAL_ERROR "Factory identity is missing exact line ${_factory_line}")
    endif()
endforeach()

message(STATUS "Material Phone QML foundation contract passed")
