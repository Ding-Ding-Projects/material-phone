cmake_minimum_required(VERSION 3.22)

set(_view_root "${CMAKE_CURRENT_LIST_DIR}/..")
set(_linphone_root "${_view_root}/..")

function(assert_active_line _content_variable _pattern _description)
    string(REGEX MATCH "(^|\n)[ \t]*${_pattern}[ \t]*(\n|$)" _active_match "${${_content_variable}}")
    if(NOT _active_match)
        message(FATAL_ERROR "Missing exact active line: ${_description}")
    endif()
endfunction()

function(read_normalized _path _output_variable)
    file(READ "${_path}" _content)
    string(REPLACE "\r\n" "\n" _content "${_content}")
    string(REPLACE "\r" "\n" _content "${_content}")
    set(${_output_variable} "${_content}" PARENT_SCOPE)
endfunction()

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

read_normalized("${_view_root}/CMakeLists.txt" _qml_registry)
foreach(_relative IN LISTS _required_files)
    string(REPLACE "." "[.]" _relative_pattern "${_relative}")
    assert_active_line(_qml_registry "view/${_relative_pattern}" "QML registration view/${_relative}")
endforeach()

read_normalized("${_view_root}/Style/MaterialTokens.qml" _tokens)
foreach(_token IN ITEMS touchTarget compactBreakpoint mediumBreakpoint elevationLevel5 motionLong1)
    assert_active_line(_tokens "readonly property int ${_token}: [0-9]+" "token ${_token}")
endforeach()

read_normalized("${_view_root}/Page/Layout/Main/AdaptivePhoneShell.qml" _shell)
assert_active_line(_shell "property var navigationModel: \\[\\]" "AdaptivePhoneShell.navigationModel")
assert_active_line(_shell "property int currentIndex: 0" "AdaptivePhoneShell.currentIndex")
assert_active_line(_shell "property bool compact: width < MaterialTokens[.]compactBreakpoint" "AdaptivePhoneShell.compact")
assert_active_line(_shell "signal destinationActivated\\(int index\\)" "AdaptivePhoneShell.destinationActivated")

read_normalized("${_view_root}/Page/Window/Main/MainWindow.qml" _main_window)
assert_active_line(_main_window "AdaptivePhoneShell \\{" "production AdaptivePhoneShell instance")
assert_active_line(_main_window "navigationModel: mainLayout[.]adaptiveNavigationModel" "production navigation model binding")
assert_active_line(_main_window "currentIndex: mainLayout[.]adaptiveNavigationPosition" "production navigation index binding")
assert_active_line(_main_window "onDestinationActivated: position => mainLayout[.]activateAdaptiveDestination\\(position\\)" "production destination routing")
assert_active_line(_main_window "externalNavigationEnabled: true" "legacy navigation suppression request")

read_normalized("${_view_root}/Page/Layout/Main/MainLayout.qml" _main_layout)
assert_active_line(_main_layout "property bool externalNavigationEnabled: false" "MainLayout external navigation contract")
assert_active_line(_main_layout "readonly property var adaptiveNavigationModel: \\{" "MainLayout filtered navigation model")
assert_active_line(_main_layout "readonly property int adaptiveNavigationPosition: navigationPositionForDestination\\(tabbar[.]currentIndex\\)" "MainLayout adaptive position")
assert_active_line(_main_layout "function activateAdaptiveDestination\\(position\\) \\{" "MainLayout destination activation")
assert_active_line(_main_layout "if \\(!SettingsCpp[.]disableChatFeature\\) \\{" "chat destination visibility filter")
assert_active_line(_main_layout "if \\(!SettingsCpp[.]disableMeetingsFeature\\) \\{" "meeting destination visibility filter")
assert_active_line(_main_layout "if \\(SettingsCpp[.]disableChatFeature\\)" "disabled chat routing guard")
assert_active_line(_main_layout "if \\(SettingsCpp[.]disableMeetingsFeature\\)" "disabled meeting routing guard")
assert_active_line(_main_layout "visible: !mainItem[.]externalNavigationEnabled" "legacy VerticalTabBar visibility binding")
assert_active_line(_main_layout "Layout[.]preferredWidth: visible [?] Utils[.]getSizeWithScreenRatio\\(82\\) : 0" "legacy VerticalTabBar zero-width binding")

read_normalized("${_linphone_root}/application_info.cmake" _identity)
assert_active_line(_identity "set\\(APPLICATION_ID \"com[.]dingdingprojects[.]materialphone\"\\)" "stable application id")
assert_active_line(_identity "set\\(APPLICATION_NAME \"Material Phone\"\\)" "stable application name")
assert_active_line(_identity "set\\(APPLICATION_VENDOR \"Ding Ding Projects\"\\)" "stable application vendor")

read_normalized("${_linphone_root}/data/config/linphonerc-factory" _factory_config)
assert_active_line(_factory_config "product_id=com[.]dingdingprojects[.]materialphone" "factory product id")
assert_active_line(_factory_config "product_name=Material Phone" "factory product name")
assert_active_line(_factory_config "product_vendor=Ding Ding Projects" "factory product vendor")

message(STATUS "Material Phone QML foundation contract passed")
