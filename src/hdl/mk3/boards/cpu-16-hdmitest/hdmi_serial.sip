set_global_assignment -entity "hdmi_serial" -library "lib_hdmi_serial" -name IP_TOOL_NAME "altera_soft_lvds"
set_global_assignment -entity "hdmi_serial" -library "lib_hdmi_serial" -name IP_TOOL_VERSION "20.1"
set_global_assignment -entity "hdmi_serial" -library "lib_hdmi_serial" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_hdmi_serial" -name SPD_FILE [file join $::quartus(sip_path) "hdmi_serial.spd"]

set_global_assignment -library "lib_hdmi_serial" -name MISC_FILE [file join $::quartus(sip_path) "hdmi_serial_sim/hdmi_serial.vhd"]
set_global_assignment -library "lib_hdmi_serial" -name MISC_FILE [file join $::quartus(sip_path) "hdmi_serial_sim/altera_soft_lvds/altera_soft_lvds_tx_SzWJL.v"]
