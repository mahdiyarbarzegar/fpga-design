namespace eval ::ip {
    variable project_root_path $::common::ROOT_DIR
    variable DOCS_PATH $::common::DOCS_PATH
    variable PROPS_PATH $::common::PROPS_PATH
    variable IP_PATH $::common::IP_PATH
    variable PACKAGE_PATH $::common::PACKAGE_PATH
    variable xml_path ""
    variable xml_loaded 0
}

proc ::ip::list_props {part_number module_path} {
    variable project_root_path
    variable DOCS_PATH
    variable PROPS_PATH
    variable PACKAGE_PATH

    set module_path [file normalize $module_path]

    module::load $module_path

    set init_path [::common::set_working_dir $PROPS_PATH]

    if {![module::is_loaded]} {
        error "No module loaded."
    }

    set ip_vlnv [module::get ip.vlnv]
    set ip_name [module::get ip.name]
    set ip_version [module::get ip.version]

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
            set report [report_property $ip_obj -regexp {CONFIG.*} -return_string]
        } err]
    } {
        puts $fp "# No CONFIG properties"
    } else {
        puts $fp $report
    }

    close $fp

    ::close_project -quiet

    ::common::set_working_dir $init_path

    puts "--INFO: Exported CONFIG properties of $ip_vlnv to $output_file"
}

proc ::ip::package_ip {part_number module_path {log_mode "quiet"}} {
    variable PACKAGE_PATH
    variable project_root_path

    set log_opts [::common::log_option $log_mode]

    set module_path [file normalize $module_path]

    module::scan
    module::load $module_path
    if {![module::is_loaded]} {
        error "No module loaded."
    }

    set init_path [::common::set_working_dir $PACKAGE_PATH]

    set ip_display_name [module::display_name]
    set ip_description [module::description]
    set ip_vendor [module::vendor]
    set ip_library [module::library]
    set ip_name [module::name]
    set ip_version [module::version]
    set ip_vlnv [module::vlnv]
    set ip_taxonomy [module::taxonomy]
    set ip_type [module::type]

    puts "Packaging: ${ip_vlnv}"

    if {$ip_type != "hdl"} {
        error "The IP Type to package should be hdl not $ip_type"
    }

    set abs_ip_package_path [format "%s/%s" $PACKAGE_PATH $ip_name]

    catch {file delete -force "$abs_ip_package_path"}

    ::set_part {*}$log_opts $part_number

    set deps [dependency::resolve $module_path]

    foreach node $deps {
        set node_module_path [dict get $node path]
        set node_dep_consume [dict get $node consume]
        set node_dep_variant [dict get $node variant]

        if {$node_dep_consume eq "ip"} {
            continue
        }

        module::load $node_module_path

        if {![module::is_loaded]} {
            error "No module loaded."
        }

        foreach f [module::get rtl] {
            set abs_file [file join $project_root_path $node_module_path $f]

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

        foreach f [module::get constraints] {
            if {$f eq "null"} {
                break
            }

            set abs_file [file join $project_root_path $node_module_path $f]

            puts [format "  %-18s %s" "XDC:" [file tail $f]]
            ::read_xdc {*}$log_opts $abs_file
            set_property PROCESSING_ORDER LATE [get_files -all $abs_file]
        }
    }

    ipx::package_project \
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

    set core [ipx::current_core]

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

    ::ip::_run_package_append $ctx

    ipx::infer_user_parameters {*}$log_opts $core
    ipx::create_xgui_files {*}$log_opts $core
    ipx::update_checksums {*}$log_opts $core
    ipx::check_integrity {*}$log_opts $core
    ipx::merge_project_changes {*}$log_opts all $core
    ipx::save_core {*}$log_opts $core

    set_property ip_repo_paths [list $PACKAGE_PATH] [current_project]

    ::update_ip_catalog {*}$log_opts

    ::close_project {*}$log_opts

    ::common::set_working_dir $init_path

    puts ""
    puts "---------------------------------------"
    puts "IP successfully packaged."
    puts "VLNV:"
    puts "    $ip_vendor:$ip_library:$ip_name:$ip_version"
    puts "---------------------------------------"
}

proc ::ip::generate_ip {part_number module_path variant {log_mode "quiet"}} {
    variable IP_PATH

    set module_path [file normalize $module_path]

    module::scan
    module::load $module_path
    module::validate_variant $variant

    set log_opts [::common::log_option $log_mode]

    set init_path [::common::set_working_dir $IP_PATH]

    set deps [dependency::resolve $module_path "ip" $variant]

    ::set_part {*}$log_opts $part_number

    foreach node $deps {
        ::ip::_generate_one $part_number $node $log_mode
    }

    ::close_project {*}$log_opts

    ::common::set_working_dir $init_path
}

proc ::ip::_run_package_append {ctx} {
    set append_file [module::get package.append]

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

    if {![llength [info procs package_append::do_package_append]]} {
        error "Procedure package_append::do_package_append not found in:\n$append_file"
    }

    package_append::do_package_append $ctx

    namespace delete package_append
}

proc ::ip::_generate_one {part_number node {log_mode "quiet"}} {
    variable IP_PATH
    variable PACKAGE_PATH

    set log_opts [::common::log_option $log_mode]

    set module_path [dict get $node path]
    set dep_consume [dict get $node consume]
    set dep_variant [dict get $node variant]

    if {$dep_consume eq "rtl"} {
        return
    }

    module::load $module_path

    if {![module::is_loaded]} {
        error "Cannot load module $module_path"
    }

    set ip_name [module::name]
    set ip_version [module::version]
    set ip_vlnv [module::vlnv]
    set variant_name [module::variant_get $dep_variant name]

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
    set params [module::variant_get $dep_variant parameters]

    if {$params ne "null"} {
        set_property -dict $params $ip_obj
    }

    ::generate_target {*}$log_opts -force all $ip_obj

    ::get_files {*}$log_opts -compile_order sources -used_in simulation
}

proc ::ip::load_xml_fileset {xml_file} {
    variable xml_path
    variable xml_loaded

    xml::load $xml_file

    set xml_path $xml_file
    set xml_loaded 1
}

proc ::ip::get_xml_field {field} {
    switch -- $field {
        simulation.behavioral {
            return [ip::_get_xml_fileset \
                xilinx_anylanguagebehavioralsimulation_view_fileset]
        }

        simulation.wrapper {
            return [ip::_get_xml_fileset \
                xilinx_verilogsimulationwrapper_view_fileset]
        }

        default {
            error "Unknown generated IP field: $field"
        }
    }
}

proc ::ip::_get_xml_fileset {fileset_name} {
    set root [xml::root]

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
