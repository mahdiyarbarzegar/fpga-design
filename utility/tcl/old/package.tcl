namespace eval ::package {
    variable project_root_path $::common::ROOT_DIR
    variable PACKAGE_PATH $::common::PACKAGE_PATH
}

proc package::do_package { part_number module_path {be_quiet ""}} {
    variable PACKAGE_PATH
    variable project_root_path

    set quiet {}
    if {$be_quiet eq "-quiet"} {
        lappend quiet -quiet
    }

    module::scan
    module::load $module_path
    if {![module::is_loaded]} {
        error "No module loaded."
    }

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

    if { $ip_type != "hdl" } {
        error "The IP Type to package should be hdl not $ip_type"
    }

    set abs_ip_package_path [format "%s/%s" $PACKAGE_PATH $ip_name]

    catch {file delete -force "$abs_ip_package_path"}

    set_part {*}$quiet $part_number

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
                    read_verilog {*}$quiet $abs_file
                }
                ".sv" {
                    puts [format "  %-18s %s" "System Verilog:" [file tail $f]]
                    read_verilog {*}$quiet -sv $abs_file
                }
                ".vhd" {
                    puts [format "  %-18s %s" "VHDL:" [file tail $f]]
                    read_vhdl {*}$quiet $abs_file
                }
                default {
                    error "Unsupported HDL file"
                }
            }
        }

        foreach f [module::get constraints] {
            if {$f eq "null"} {
                break;
            }

            set abs_file [file join $project_root_path $node_module_path $f]

            puts [format "  %-18s %s" "XDC:" [file tail $f]]
            read_xdc {*}$quiet $abs_file
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
        {*}$quiet

    update_compile_order

    set core [ipx::current_core]

    set_property vendor $ip_vendor $core
    set_property library $ip_library $core
    set_property name $ip_name $core
    set_property version $ip_version $core
    set_property display_name $ip_display_name $core
    set_property description $ip_description $core

    set ctx [dict create \
        core         $core \
        module_path  $module_path \
        project_root $project_root_path \
        quiet        $quiet \
    ]

    package::_run_package_append $ctx

    ipx::infer_user_parameters {*}$quiet $core
    ipx::create_xgui_files {*}$quiet $core
    ipx::update_checksums {*}$quiet $core
    ipx::check_integrity {*}$quiet $core
    ipx::merge_project_changes {*}$quiet all $core
    ipx::save_core {*}$quiet $core

    set_property ip_repo_paths [list $PACKAGE_PATH] [current_project]

    update_ip_catalog {*}$quiet

    close_project

    puts ""
    puts "---------------------------------------"
    puts "IP successfully packaged."
    puts "VLNV:"
    puts "    $ip_vendor:$ip_library:$ip_name:$ip_version"
    puts "---------------------------------------"
}

proc package::_run_package_append {ctx} {
    set append_file [module::get package.append]

    if {$append_file eq ""} {
        return
    }

    set module_path  [dict get $ctx module_path]
    set project_root [dict get $ctx project_root]
    set quiet        [dict get $ctx quiet]

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