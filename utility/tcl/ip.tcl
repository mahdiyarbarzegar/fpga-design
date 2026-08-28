namespace eval ::ip {}

namespace eval ::ip::internal {
    variable project_root_path $::common::ROOT_DIR
    variable DOCS_PATH $::common::DOCS_PATH
    variable PROPS_PATH $::common::PROPS_PATH
    variable IP_PATH $::common::IP_PATH
    variable PACKAGE_PATH $::common::PACKAGE_PATH
    variable xml_path ""
    variable xml_loaded 0
}

proc ::ip::package_ip {part_number module_path {log_mode "quiet"}} {
    variable internal::PACKAGE_PATH

    set module_path [file normalize $module_path]

    try {
        set init_path [::common::set_working_dir $PACKAGE_PATH]
        ::ip::internal::package_ip $part_number $module_path $log_mode
    } on error {result options} {
        ::ip::internal::close_prj
        puts stderr "Operation failed:"
        puts stderr $result
        puts "Error occured during packaging."
    } finally {
        ::common::set_working_dir $init_path
    }
}

proc ::ip::generate_ip {part_number module_path variant {log_mode "quiet"}} {
    variable internal::IP_PATH

    set module_path [file normalize $module_path]

    try {
        set init_path [::common::set_working_dir $IP_PATH]
        ::ip::internal::generate_ip $part_number $module_path $variant $log_mode
    } on error {result options} {
        ::ip::internal::close_prj
        puts stderr "Operation failed:"
        puts stderr $result
        puts "Error occured during generating."
    } finally {
        ::common::set_working_dir $init_path
    }
}

proc ::ip::list_props {part_number module_path} {
    variable internal::PROPS_PATH

    set module_path [file normalize $module_path]

    try {
        set init_path [::common::set_working_dir $PROPS_PATH]
        ::ip::internal::list_props $part_number $module_path
    } on error {result options} {
        ::ip::internal::close_prj
        puts stderr "Operation failed:"
        puts stderr $result
        puts "Error occured during properties listing."
    } finally {
        ::common::set_working_dir $init_path
    }
}

proc ::ip::internal::package_ip {part_number module_path {log_mode "quiet"}} {
    variable PACKAGE_PATH
    variable project_root_path

    set log_opts [::common::log_option $log_mode]

    set module_path [file normalize $module_path]

    ::module::scan
    ::module::load $module_path
    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    set ip_display_name [::module::display_name]
    set ip_description [::module::description]
    set ip_vendor [::module::vendor]
    set ip_library [::module::library]
    set ip_name [::module::name]
    set ip_version [::module::version]
    set ip_vlnv [::module::vlnv]
    set ip_taxonomy [::module::taxonomy]
    set ip_type [::module::type]

    puts "Packaging: ${ip_vlnv}"

    if {$ip_type != "hdl"} {
        error "The IP Type to package should be hdl not $ip_type"
    }

    set abs_ip_package_path [format "%s/%s" $PACKAGE_PATH $ip_name]

    catch {file delete -force "$abs_ip_package_path"}

    ::set_part {*}$log_opts $part_number

    set deps [::dependency::resolve $module_path]

    foreach node $deps {
        set node_module_path [dict get $node path]
        set node_dep_consume [dict get $node consume]
        set node_dep_variant [dict get $node variant]

        if {$node_dep_consume eq "ip"} {
            continue
        }

        ::module::load $node_module_path

        if {![::module::is_loaded]} {
            error "No module loaded."
        }

        set module_type [::module::get type]

        if {$module_type eq "hdl"} {
            set module_files [::module::get rtl]
        } elseif {$module_type eq "lib"} {
            set module_files [::module::get src]
        } else {
            error "The module type is not supported: $module_type"
        }

        foreach f $module_files {
            set abs_file [file join $node_module_path $f]

            switch -- [file extension $abs_file] {
                ".v" {
                    puts [format "  %-18s %s" "Verilog:" [file tail $f]]
                    ::read_verilog {*}$log_opts $abs_file
                }
                ".sv" {
                    puts [format "  %-18s %s" "System Verilog:" [file tail $f]]
                    ::read_verilog {*}$log_opts -sv $abs_file
                }
                ".vhd" {
                    puts [format "  %-18s %s" "VHDL:" [file tail $f]]
                    ::read_vhdl {*}$log_opts $abs_file
                }
                default {
                    error "Unsupported HDL file"
                }
            }
        }

        foreach f [::module::get_default constraints ""] {
            if {$f eq "null"} {break}

            set abs_file [file join $project_root_path $node_module_path $f]

            puts [format "  %-18s %s" "XDC:" [file tail $f]]
            ::read_xdc {*}$log_opts $abs_file
            set_property PROCESSING_ORDER LATE [get_files -all $abs_file]
        }
    }

    ::ipx::package_project \
        -root_dir $abs_ip_package_path \
        -vendor $ip_vendor \
        -library $ip_library \
        -name $ip_name \
        -version $ip_version \
        -taxonomy $ip_taxonomy \
        -import_files \
        -force_update_compile_order \
        -force \
        {*}$log_opts

    ::update_compile_order {*}$log_opts

    set core [::ipx::current_core]

    set_property vendor $ip_vendor $core
    set_property library $ip_library $core
    set_property name $ip_name $core
    set_property version $ip_version $core
    set_property display_name $ip_display_name $core
    set_property description $ip_description $core

    set ctx [dict create \
        core $core \
        module_path $module_path \
        project_root $project_root_path \
        quiet $log_opts]

    ::ipx::infer_user_parameters {*}$log_opts $core
    ::ipx::infer_bus_interfaces {*}$log_opts $core

    ::ip::internal::apply_params $core
    ::ip::internal::apply_gui $core
    ::ip::internal::apply_interfaces $core

    ::ipx::create_xgui_files {*}$log_opts $core
    ::ipx::update_checksums {*}$log_opts $core
    ::ipx::check_integrity {*}$log_opts $core
    ::ipx::merge_project_changes {*}$log_opts all $core
    ::ipx::save_core {*}$log_opts $core

    set_property ip_repo_paths [list $PACKAGE_PATH] [current_project]

    ::update_ip_catalog {*}$log_opts

    ::close_project {*}$log_opts

    puts ""
    puts "---------------------------------------"
    puts "IP successfully packaged."
    puts "VLNV:"
    puts "    $ip_vendor:$ip_library:$ip_name:$ip_version"
    puts "---------------------------------------"
}

proc ::ip::internal::apply_interfaces {core} {
    set interfaces [::module::get_default interfaces ""]

    if {$interfaces eq ""} {
        return
    }

    foreach intf_all [get_property name [ipx::get_bus_interfaces -of_objects $core]] {
        ipx::remove_bus_interface $intf_all $core
    }

    dict for {name config} $interfaces {
        if {![dict exists $config type]} {
            error "Interface '$name' is missing 'type'"
        }

        set type [string tolower [dict get $config type]]

        switch -- $type {
            clock {
                ::ip::internal::apply_clock_interface $core $name $config
            }

            reset {
                ::ip::internal::apply_reset_interface $core $name $config
            }

            axi4lite {
                ::ip::internal::apply_axi4lite_interface $core $name $config
            }

            input -
            output -
            inout {
                ::ip::internal::apply_io_port $core $name $config
            }

            default {
                error "Unsupported interface type '$type' " "for interface '$name'"
            }
        }
    }
}

proc ::ip::internal::apply_io_port {core name config} {
    if {![dict exists $config port]} {
        error "IO '$name' is missing 'port' definition"
    }

    set port_map [dict get $config port]

    if {[dict size $port_map] != 1} {
        error "IO '$name' must have exactly one port mapping"
    }

    dict for {logical_name physical_name} $port_map {
        set port_name $physical_name
    }

    set port [ipx::get_ports $port_name -of_objects $core]

    if {$port eq ""} {
        error "Cannot find RTL port '$port_name' " "for IO '$name'"
    }

    ::ip::internal::apply_port_enablement $port $config
}

proc ::ip::internal::apply_reset_interface {core name config} {
    if {![dict exists $config port]} {
        error "Reset '$name' is missing 'port'"
    }

    set port_map [dict get $config port]

    if {[dict size $port_map] != 1} {
        error "Reset '$name' must have exactly one port mapping"
    }

    dict for {logical_name physical_name} $port_map {
        set port_name $physical_name
    }

    set rst_if [ipx::add_bus_interface $name $core]

    set_property interface_mode slave $rst_if

    set_property bus_type_vlnv \
        xilinx.com:signal:reset:1.0 \
        $rst_if

    set_property abstraction_type_vlnv \
        xilinx.com:signal:reset_rtl:1.0 \
        $rst_if

    set_property display_name $name $rst_if

    if {[dict exists $config polarity]} {
        set polarity [dict get $config polarity]

        set rst_param [ipx::add_bus_parameter POLARITY $rst_if]

        switch -- $polarity {
            active_low {
                set_property value ACTIVE_LOW $rst_param
            }

            active_high {
                set_property value ACTIVE_HIGH $rst_param
            }

            default {
                error "Invalid reset polarity '$polarity' " \
                    "for '$name'"
            }
        }
    }

    ipx::add_port_map RST $rst_if

    set_property physical_name \
        $port_name \
        [ipx::get_port_maps RST -of_objects $rst_if]

    set port [ipx::get_ports $port_name -of_objects $core]
    if {$port eq ""} {
        error "Cannot find reset port '$port_name'"
    }

    ::ip::internal::apply_port_enablement $port $config
}

proc ::ip::internal::apply_clock_interface {core name config} {
    if {![dict exists $config port]} {
        error "Clock '$name' is missing 'port'"
    }

    set port_map [dict get $config port]

    if {[dict size $port_map] != 1} {
        error "Clock '$name' must have exactly one port mapping"
    }

    dict for {logical_name physical_name} $port_map {
        set port_name $physical_name
    }

    set port [ipx::get_ports $port_name -of_objects $core]

    if {$port eq ""} {
        error "Cannot find clock port '$port_name'"
    }

    set clk_if [ipx::add_bus_interface $name $core]

    set_property interface_mode slave $clk_if

    set_property bus_type_vlnv \
        xilinx.com:signal:clock:1.0 \
        $clk_if

    set_property abstraction_type_vlnv \
        xilinx.com:signal:clock_rtl:1.0 \
        $clk_if

    set_property display_name $name $clk_if

    ipx::add_port_map CLK $clk_if

    set_property physical_name \
        $port_name \
        [ipx::get_port_maps CLK -of_objects $clk_if]

    if {[dict exists $config frequency]} {
        set frequency [dict get $config frequency]
        set freq_param [ipx::add_bus_parameter FREQ_HZ $clk_if]

        set_property value $frequency $freq_param
    }

    set port [ipx::get_ports $port_name -of_objects $core]
    if {$port eq ""} {
        error "Cannot find clock port '$port_name'"
    }

    ::ip::internal::apply_port_enablement $port $config
}

proc ::ip::internal::apply_axi4lite_interface {core name config} {
    if {![dict exists $config port]} {
        error "AXI4-Lite interface '$name' is missing 'port'"
    }

    if {![dict exists $config mode]} {
        error "AXI4-Lite interface '$name' is missing 'mode'"
    }

    set mode [dict get $config mode]

    ipx::add_bus_interface $name $core
    set axi_if [::ipx::get_bus_interfaces $name -of_objects $core]

    set_property interface_mode $mode $axi_if

    set_property bus_type_vlnv \
        xilinx.com:interface:aximm:1.0 \
        $axi_if

    set_property abstraction_type_vlnv \
        xilinx.com:interface:aximm_rtl:1.0 \
        $axi_if

    if {[dict exists $config bus_parameters]} {
        dict for {param_name param_value} \
            [dict get $config bus_parameters] {
                set bus_param [ipx::add_bus_parameter $param_name $axi_if]
                set_property value $param_value $bus_param
            }
    }

    set port_map [dict get $config port]

    foreach {logical_name physical_name} $port_map {
        set port [ipx::get_ports $physical_name -of_objects $core]

        if {$port eq ""} {
            error "Cannot find RTL port '$physical_name' " "for interface '$name'"
        }

        ::ip::internal::apply_port_enablement $port $config

        set port_map_obj [ipx::add_port_map $logical_name $axi_if]

        set_property physical_name $physical_name $port_map_obj
    }

    ::ip::internal::apply_ifc_enablement $axi_if $config
}

proc ::ip::internal::apply_ifc_enablement {object config} {
    if {![dict exists $config enablement]} {
        return
    }

    set expression [dict get $config enablement]

    set_property enablement_dependency $expression $object
}

proc ::ip::internal::apply_port_enablement {port config} {
    if {![dict exists $config enablement]} {
        return
    }

    set expression [dict get $config enablement]

    set_property enablement_dependency $expression $port

    set_property driver_value 0 $port
}

proc ::ip::internal::apply_params {core} {
    set parameters [::module::get_default parameters ""]

    if {$parameters eq ""} {return}

    dict for {name config} $parameters {
        ::ip::internal::add_parameter $core $name $config
    }
}

proc ::ip::internal::add_parameter {core name config} {
    set param [ipx::add_user_parameter $name $core]

    set_property value_resolve_type user $param

    set type [dict get $config type]

    switch -- $type {
        string {
            set_property value_format string $param
        }

        integer {
            set_property value_format long $param
        }

        boolean {
            set_property value_format bool $param
        }

        default {
            error "Unsupported parameter type '$type' for parameter '$name'"
        }
    }

    if {[dict exists $config default]} {
        set_property value [dict get $config default] $param
    }

    if {[dict exists $config validation]} {
        set validation [dict get $config validation]
        set validation_type [dict get $validation type]

        switch -- $validation_type {
            list {
                if {![dict exists $validation values]} {
                    error "Parameter '$name': list validation requires 'values'"
                }

                set values [dict get $validation values]

                set_property value_validation_type list $param
                set_property value_validation_list $values $param
            }

            range_long {
                if {
                    ![dict exists $validation min] ||
                    ![dict exists $validation max]
                } {
                    error "Parameter '$name': " \
                        "range_long validation requires 'min' and 'max'"
                }

                set minimum [dict get $validation min]
                set maximum [dict get $validation max]

                set_property value_validation_type range_long $param

                set_property value_validation_range_minimum $minimum $param

                set_property value_validation_range_maximum $maximum $param
            }

            range_float {
                if {
                    ![dict exists $validation min] ||
                    ![dict exists $validation max]
                } {
                    error "Parameter '$name': " \
                        "range_float validation requires 'min' and 'max'"
                }

                set minimum [dict get $validation min]
                set maximum [dict get $validation max]

                set_property value_validation_type range_float $param

                set_property value_validation_range_minimum $minimum $param

                set_property value_validation_range_maximum $maximum $param
            }

            default {
                error "Unsupported validation type '$validation_type' " \
                    "for parameter '$name'"
            }
        }
    }

    if {[dict exists $config enablement]} {
        set expression [dict get $config enablement]

        set_property enablement_value true $param
        set_property enablement_tcl_expr $expression $param
    }

    if {[dict exists $config expression]} {
        set expression [dict get $config expression]

        set_property enablement_value false $param
        set_property value_tcl_expr $expression $param
    }

    return $param
}

proc ::ip::internal::apply_gui {core} {
    set page0_required 0

    set parameters [::module::get_default parameters ""]

    if {$parameters eq ""} {
        return
    }

    set pages {}
    set groups {}

    dict for {name config} $parameters {
        if {![dict exists $config gui]} {
            set page0_required 1
            continue
        }

        set gui [dict get $config gui]

        if {[dict exists $gui page]} {
            set page_name [dict get $gui page]
        } else {
            set page_name "Page 0"
        }

        set page_key $page_name

        if {[lsearch -exact $pages $page_key] == -1} {
            # Check whether the page already exists
            set page [ipgui::get_pagespec \
                -name $page_name \
                -component $core \
                -quiet]

            if {$page eq ""} {
                set page [ipgui::add_page \
                    -name $page_name \
                    -component $core \
                    -display_name $page_name]
            }

            lappend pages $page_key
        } else {
            set page [ipgui::get_pagespec \
                -name $page_name \
                -component $core]
        }

        set parent $page

        if {[dict exists $gui group]} {
            set group_name [dict get $gui group]

            set group_key "${page_name}::${group_name}"

            if {[lsearch -exact $groups $group_key] == -1} {
                set group [ipgui::get_groupspec \
                    -name $group_name \
                    -component $core \
                    -quiet]

                if {$group eq ""} {
                    set group [ipgui::add_group \
                        -name $group_name \
                        -component $core \
                        -parent $page \
                        -display_name $group_name]
                }

                lappend groups $group_key
            } else {
                set group [ipgui::get_groupspec \
                    -name $group_name \
                    -component $core]
            }

            set parent $group
        }

        set gui_param [ipgui::get_guiparamspec \
            -name $name \
            -component $core \
            -quiet]

        if {$gui_param eq ""} {
            error \
                "GUI parameter '$name' does not exist in IP '$core'"
        }

        set parent_key $page_name

        if {[dict exists $gui group]} {
            set parent_key "${page_name}::[dict get $gui group]"
        }

        if {![info exists order($parent_key)]} {
            set order($parent_key) 0
        }

        set param_order $order($parent_key)

        ipgui::move_param \
            -order $param_order \
            -parent $parent \
            -component $core \
            $gui_param

        incr order($parent_key)

        if {[dict exists $gui display_name]} {
            set display_name [dict get $gui display_name]

            set_property display_name \
                $display_name \
                $gui_param
        }

        if {[dict exists $gui widget]} {
            set widget [dict get $gui widget]

            switch -- $widget {
                text {
                    set_property widget textEdit $gui_param
                }

                dropdown {
                    set_property widget comboBox $gui_param
                }

                checkbox {
                    set_property widget checkBox $gui_param
                }

                default {
                    error "Unsupported GUI widget '$widget' " \
                        "for parameter '$name'"
                }
            }
        }
    }

    if {!$page0_required} {
        set page0 [ipgui::get_pagespec \
            -name "Page 0" \
            -component $core \
            -quiet]

        if {$page0 ne ""} {
            ipgui::remove_page -component $core $page0
        }
    }
}

proc ::ip::internal::generate_ip {part_number module_path variant {log_mode "quiet"}} {
    set module_path [file normalize $module_path]

    ::module::scan
    ::module::load $module_path
    ::module::validate_variant $variant

    set log_opts [::common::log_option $log_mode]

    set deps [::dependency::resolve $module_path "ip" $variant]

    ::set_part {*}$log_opts $part_number

    foreach node $deps {
        ::ip::internal::generate_one $part_number $node $log_mode
    }

    ::close_project {*}$log_opts
}

proc ::ip::load_xml_fileset {xml_file} {
    variable internal::xml_path
    variable internal::xml_loaded

    ::xml::load $xml_file

    set xml_path $xml_file
    set xml_loaded 1
}

proc ::ip::get_xml_field {field} {
    switch -- $field {
        simulation.behavioral {
            return [::ip::internal::get_xml_fileset \
                xilinx_anylanguagebehavioralsimulation_view_fileset]
        }

        simulation.wrapper {
            return [::ip::internal::get_xml_fileset \
                xilinx_verilogsimulationwrapper_view_fileset]
        }

        default {
            error "Unknown generated IP field: $field"
        }
    }
}

proc ::ip::internal::list_props {part_number module_path} {
    variable project_root_path
    variable DOCS_PATH
    variable PROPS_PATH
    variable PACKAGE_PATH

    set module_path [file normalize $module_path]

    ::module::load $module_path

    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    set ip_vlnv [::module::get ip.vlnv]
    set ip_name [::module::get ip.name]
    set ip_version [::module::get ip.version]

    ::set_part -quiet $part_number

    set_property ip_repo_paths [list $PACKAGE_PATH] [current_project]

    ::update_ip_catalog -quiet

    ::create_ip -vlnv $ip_vlnv -module_name $ip_name -quiet

    set output_file [file join $PROPS_PATH [format "%s_properties.txt" $ip_vlnv]]

    set out_dir [file dirname $output_file]
    file mkdir $out_dir
    set fp [open $output_file "w"]

    puts $fp [format "IP definition : %s" $ip_vlnv]
    puts $fp [format "Part          : %s" $part_number]
    puts $fp [format "Module name   : %s" $ip_name]
    puts $fp [string repeat "-" 80]

    set ip_obj [get_ips $ip_name]

    if {
        [catch {
            set report [::report_property $ip_obj -regexp {CONFIG.*} -return_string]
        } err]
    } {
        puts $fp "# No CONFIG properties"
    } else {
        puts $fp $report
    }

    close $fp

    ::close_project -quiet

    puts "--INFO: Exported CONFIG properties of $ip_vlnv to $output_file"
}

proc ::ip::internal::run_package_append {ctx} {
    set append_file [::module::get package.append]

    if {$append_file eq ""} {
        return
    }

    set module_path [dict get $ctx module_path]
    set project_root [dict get $ctx project_root]
    set quiet [dict get $ctx quiet]

    set append_file [file join $project_root $module_path $append_file]

    if {![file exists $append_file]} {
        error "Package append file not found:\n$append_file"
    }

    source -quiet $append_file

    if {![llength [info procs ::package_append::do_package_append]]} {
        error "Procedure package_append::do_package_append not found in:\n$append_file"
    }

    ::package_append::do_package_append $ctx

    namespace delete ::package_append
}

proc ::ip::internal::generate_one {part_number node {log_mode "quiet"}} {
    variable IP_PATH
    variable PACKAGE_PATH

    set log_opts [::common::log_option $log_mode]

    set module_path [dict get $node path]
    set dep_consume [dict get $node consume]
    set dep_variant [dict get $node variant]

    if {$dep_consume eq "rtl"} {
        return
    }

    ::module::load $module_path

    if {![::module::is_loaded]} {
        error "Cannot load module $module_path"
    }

    set ip_name [::module::name]
    set ip_version [::module::version]
    set ip_vlnv [::module::vlnv]
    set variant_name [::module::variant_get $dep_variant name]

    set ip_dir "${ip_name}_v${ip_version}"

    set ip_dir_path [file join $IP_PATH $ip_dir]

    set xci [file join $ip_dir_path $variant_name "${variant_name}.xci"]

    if {[file exists $xci]} {
        puts "Skipping $variant_name"
        return
    }

    puts "Generating $variant_name"

    file mkdir $ip_dir_path

    set_property ip_repo_paths [list $PACKAGE_PATH] [current_project]

    ::update_ip_catalog {*}$log_opts

    ::create_ip {*}$log_opts -vlnv $ip_vlnv -module_name $variant_name -dir $ip_dir_path -force

    set ip_obj [get_ips $variant_name]
    set params [::module::variant_get $dep_variant parameters]

    if {$params ne "null"} {
        set_property -dict $params $ip_obj
    }

    ::generate_target {*}$log_opts -force all $ip_obj

    ::get_files {*}$log_opts -compile_order sources -used_in simulation
}

proc ::ip::internal::get_xml_fileset {fileset_name} {
    set root [::xml::root]

    set filesets [$root selectNodes {
        /*[local-name()='component']
        /*[local-name()='fileSets']
        /*[local-name()='fileSet']
    }]

    foreach fileset $filesets {
        set name_node [$fileset selectNodes {
            ./*[local-name()='name']
        }]

        if {[llength $name_node] == 0} {
            continue
        }

        set name [string trim [[lindex $name_node 0] text]]

        if {$name ne $fileset_name} {
            continue
        }

        set result {}

        foreach file [$fileset selectNodes {
            ./*[local-name()='file']
        }] {
            set name_node [$file selectNodes {
                ./*[local-name()='name']
            }]

            if {[llength $name_node] == 0} {
                continue
            }

            lappend result [string trim [[lindex $name_node 0] text]]
        }

        return $result
    }

    return {}
}

proc ::ip::internal::close_prj {} {
    if {[info commands current_project] ne ""} {
        if {[llength [current_project -quiet]] > 0} {
            close_project -quiet
        }
    }
}
