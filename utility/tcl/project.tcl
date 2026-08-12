namespace eval ::project {}

namespace eval ::project::internal {
    variable db {}
    variable resolved_db {}
    variable loaded 0
    variable resolved 0
    variable prepared 0
    variable designed 0
    variable synthesized 0
    variable implemented 0
    variable bitstream_generated 0
    variable xsa_generated 0
    variable PRJ_SRC_PATH $::common::PRJ_SRC_PATH
    variable HDL_PATH $::common::HDL_PATH
    variable IP_PATH $::common::IP_PATH
    variable BUILD_PATH $::common::BUILD_PATH
    variable PRJ_BUILD_PATH $::common::PRJ_BUILD_PATH
    variable PACKAGE_PATH $::common::PACKAGE_PATH
}

proc ::project::resolve {path} {
    variable internal::db
    variable internal::resolved_db
    variable internal::resolved
    variable internal::PRJ_SRC_PATH
    variable internal::PRJ_BUILD_PATH
    variable internal::HDL_PATH
    variable internal::IP_PATH

    ::project::internal::load_prj $path

    ::project::internal::check_is_loaded

    set resolved_db [dict create \
        project {} \
        target {} \
        resources [dict create \
            rtl {} \
            ip {} \
            bd {} \
            constraints {} \
            top {}] \
        configuration [dict create \
            synth {} \
            impl {} \
            bitstream {} \
            xsa {}] \
        generation [dict create \
            write_verilog {} \
            write_vhdl {} \
            write_sdf {} \
            write_edif {} \
            write_xdc {} \
            write_waivers {} \
            write_schematic {}] \
        report [dict create \
            methodology {} \
            timing_summary {} \
            drc {} \
            timing {} \
            clock_networks {} \
            clock_interaction {} \
            cdc {} \
            power {} \
            clock_utilization {} \
            qor_suggestions {} \
            high_fanout_nets {} \
            qor_assessment {} \
            design_analysis {} \
            dfx_summary {} \
            bus_skew {} \
            datasheet {} \
            route_status {} \
            io {} \
            utilization {} \
            control_sets {} \
            ssn {} \
            ram_utilization {}]]

    ::module::scan

    puts "\nResolve the project information...\n"

    set db_project [::common::dict_get_required $db project \
        "Error: The project.yaml does not have the project section!"]
    set project_name [::common::dict_get_required $db_project name \
        "Error: The project name in project.yaml is not set!"]
    set project_version [::common::dict_get_default $db_project version "0.0"]
    set project_description [::common::dict_get_default $db_project description ""]
    set project_language [::common::dict_get_required $db_project language \
        "Error: The project top design language in project.yaml is not set!"]
    set project_src_path [file join $PRJ_SRC_PATH $project_name]
    set project_build_path [file join $PRJ_BUILD_PATH [format "%s_v%s" $project_name $project_version]]

    dict set resolved_db project [dict create \
        name $project_name \
        version $project_version \
        description $project_description \
        language $project_language \
        project_src_path $project_src_path \
        project_build_path $project_build_path]

    puts "\nResolve the target information...\n"

    set db_target [::common::dict_get_required $db target \
        "Error: The project.yaml does not have the target section!"]
    set target_type [::common::dict_get_required $db_target type \
        "Error: The target type in the project.yaml is not specified!"]
    set target_part ""
    set target_board ""
    if {$target_type eq "part"} {
        set target_part [::common::dict_get_required $db_target part \
            "Error: The target part number in the project.yaml is not specified!"]
    } elseif {$target_type eq "board"} {
        set target_board [::common::dict_get_required $db_target board \
            "Error: The target board number in the project.yaml is not specified!"]
    } else {
        error "Error: The target type in the project.yaml is not valid: $target_type"
    }

    dict set resolved_db target [dict create \
        type $target_type \
        part $target_part \
        board $target_board]

    puts "\nResolve the resources...\n"

    set db_resources [::common::dict_get_required $db resources \
        "Error: The project.yaml does not have the resources section!"]

    puts "\nResolve the RTL local files...\n"

    set rtl_locals [::common::dict_get_default $db_resources rtl.locals ""]
    foreach local $rtl_locals {
        set abs_local_file [file join $project_src_path $local]

        if {![file exists $abs_local_file]} {
            error "Error: The local RTL file does not exist: $abs_local_file"
        }

        dict with resolved_db resources {lappend rtl $abs_local_file}
    }

    puts "\nResolve the RTL modules...\n"

    set rtl_modules [::common::dict_get_default $db_resources rtl.modules ""]
    foreach module $rtl_modules {
        set module_name [::common::dict_get_default $module name ""]
        set module_version [::common::dict_get_default $module version ""]

        if {$module_name eq "" || $module_version eq ""} {continue}

        set abs_module_path [file join $HDL_PATH $module_name]

        ::module::load $abs_module_path

        if {![::module::is_loaded]} {
            error "The module $module_name does not exist in $HDL_PATH"
        }

        if {$module_version ne [::module::version]} {
            error "Module '$module_name' version '$module_version' is not available. \
                    Found version '[::module::version]'."
        }

        set dependent_modules [::dependency::resolve $abs_module_path "rtl"]

        foreach dep $dependent_modules {
            set dep_path [dict get $dep path]
            set dep_consume [dict get $dep consume]
            set dep_variant [dict get $dep variant]

            switch -- $dep_consume {
                rtl {
                    ::module::load $dep_path

                    if {![::module::is_loaded]} {
                        error "The dependent module does not exists: $dep_path"
                    }

                    set dep_rtl [::module::get rtl]
                    foreach rtl_file $dep_rtl {
                        set abs_rtl_file_path [file join $dep_path $rtl_file]

                        if {![file exists $abs_rtl_file_path]} {
                            error "The module RTL file does not exist: $abs_rtl_file_path"
                        }

                        dict with resolved_db resources {lappend rtl $abs_rtl_file_path}
                    }
                }

                ip {
                    ::module::load $dep_path

                    if {![::module::is_loaded]} {
                        error "The module $module_name does not exist in $HDL_PATH"
                    }

                    set dep_name [::module::name]
                    set dep_version [::module::version]

                    set dep_xci_path [file join \
                        $IP_PATH \
                        [format "%s_v%s" $dep_name $dep_version] \
                        "$dep_variant" \
                        "$dep_variant.xci"]

                    if {![::module::variant_exists $dep_variant]} {
                        error "Variant '$dep_variant' does not exist for module '$dep_name'."
                    }

                    if {![file exists $dep_xci_path]} {
                        error "The dependent IP xci file does not exist: $dep_xci_path"
                    }

                    dict with resolved_db resources {
                        lappend ip [dict create \
                            name $dep_name \
                            version $dep_version \
                            variant $dep_variant \
                            path $dep_xci_path]
                    }
                }

                default {
                    error "Error: The dependent module consume type is not correct: $dep_path:$dep_consume"
                }
            }
        }
    }

    puts "\nResolve the IPs...\n"

    set db_ip [::common::dict_get_default $db_resources ip ""]

    foreach ip $db_ip {
        set ip_name [::common::dict_get_default $ip name ""]
        set ip_version [::common::dict_get_default $ip version ""]
        set ip_variant [::common::dict_get_default $ip variant ""]

        if {$ip_name eq "" || $ip_version eq "" || $ip_variant eq ""} {continue}

        set ip_xci_path [file join \
            $IP_PATH \
            [format "%s_v%s" $ip_name $ip_version] \
            "$ip_variant" \
            "$ip_variant.xci"]

        if {![file exists $ip_xci_path]} {
            error "The resource IP xci file does not exist: $ip_xci_path"
        }

        dict with resolved_db resources {
            lappend ip [dict create \
                name $ip_name \
                version $ip_version \
                variant $ip_variant \
                path $ip_xci_path]
        }
    }


    puts "\nResolve the block-designs...\n"

    set db_bd [::common::dict_get_default $db_resources bd ""]

    if {$db_bd ne ""} {
        set bd_name [::common::dict_get_default $db_bd name ""]
        set bd_path [::common::dict_get_default $db_bd path ""]

        if {$bd_name ne "" && $bd_path ne ""} {
            set abs_bd_path [file join $project_src_path $bd_path]

            if {![file exists $abs_bd_path]} {
                error "The block-design .tcl file does not exist: $abs_bd_path"
            }

            dict with resolved_db resources {
                set bd [dict create \
                    name $bd_name \
                    path $abs_bd_path]
            }
        }
    }


    puts "\nResolve the constraints...\n"

    set db_constr [::common::dict_get_default $db_resources constraints ""]

    foreach constr $db_constr {
        set constr_path [::common::dict_get_default $constr path ""]

        if {$constr_path eq ""} {continue}

        set abs_constr_path [file join \
            $project_src_path \
            $constr_path]

        if {![file exists $abs_constr_path]} {
            error "The constraint .xdc file does not exist: $abs_constr_path"
        }

        dict with resolved_db resources {lappend constraints $abs_constr_path}
    }

    puts "\nResolve the top...\n"

    set db_top [::common::dict_get_default $db_resources top ""]

    if {$db_top ne ""} {
        set top_name [::common::dict_get_default $db_top name ""]
        set top_path [::common::dict_get_default $db_top path ""]

        if {$top_name ne "" && $top_path ne ""} {
            set abs_top_path [file join \
                $project_src_path \
                $top_path]

            if {![file exists $abs_top_path]} {
                error "The top design wrapper file does not exist: $abs_top_path"
            }

            dict with resolved_db resources {
                set top [dict create \
                    name $top_name \
                    path $abs_top_path]
            }
        }
    }

    puts "\nResolve the configuration...\n"

    set db_configuration [::common::dict_get_required $db configuration \
        "Error: The configuration in the project.yaml is missing!"]

    set db_synth [::common::dict_get_required $db_configuration synth \
        "Error: The configuration.synth in the project.yaml is missing!"]

    set synth_strategy [::common::dict_get_default $db_synth strategy ""]
    set synth_directive [::common::dict_get_default $db_synth directive "default"]
    set synth_opts [::common::dict_get_default $db_synth opts ""]

    dict with resolved_db configuration {
        set synth [dict create \
            strategy $synth_strategy \
            directive $synth_directive \
            opts $synth_opts]
    }

    set db_impl [::common::dict_get_required $db_configuration impl \
        "Error: The configuration.impl in the project.yaml is missing!"]

    set impl_strategy [::common::dict_get_default $db_impl strategy ""]

    set impl_optimize_directive [::common::dict_get_default $db_impl optimize.directive "Default"]
    set impl_optimize_opts [::common::dict_get_default $db_impl optimize.opts ""]

    set impl_power_optimize_enabled [::common::dict_get_default $db_impl power_optimize.enabled "false"]
    set impl_power_optimize_opts [::common::dict_get_default $db_impl power_optimize.opts ""]

    set impl_place_directive [::common::dict_get_default $db_impl place.directive "Default"]
    set impl_place_opts [::common::dict_get_default $db_impl place.opts ""]

    set impl_physical_optimize_directive [::common::dict_get_default $db_impl physical_optimize.directive "Default"]
    set impl_physical_optimize_enabled [::common::dict_get_default $db_impl physical_optimize.enabled "false"]
    set impl_physical_optimize_opts [::common::dict_get_default $db_impl physical_optimize.opts ""]

    set impl_route_directive [::common::dict_get_default $db_impl route.directive "Default"]
    set impl_route_opts [::common::dict_get_default $db_impl route.opts ""]

    dict with resolved_db configuration {
        set impl [dict create \
            strategy $impl_strategy \
            optimize [dict create \
                directive $impl_optimize_directive \
                opts $impl_optimize_opts] \
            power_optimize [dict create \
                enabled $impl_power_optimize_enabled \
                opts $impl_power_optimize_opts] \
            place [dict create \
                directive $impl_place_directive \
                opts $impl_place_opts] \
            physical_optimize [dict create \
                enabled $impl_physical_optimize_enabled \
                directive $impl_physical_optimize_directive \
                opts $impl_physical_optimize_opts] \
            route [dict create \
                directive $impl_route_directive \
                opts $impl_route_opts]]
    }

    set bitstream_opts [::common::dict_get_default $db_configuration bitstream.opts ""]

    dict with resolved_db configuration {
        set bitstream [dict create \
            opts $bitstream_opts]
    }

    set xsa_opts [::common::dict_get_default $db_configuration xsa.opts ""]

    dict with resolved_db configuration {
        set xsa [dict create \
            opts $xsa_opts]
    }

    puts "\nResolve the generation...\n"

    set db_generation [::common::dict_get_required $db generation \
        "Error: The generation section in the project.yaml is missing!"]

    set write_verilog_synth_enable [::common::dict_get_default $db_generation write_verilog.synth.enable "false"]
    set write_verilog_synth_opts [::common::dict_get_default $db_generation write_verilog.synth.opts ""]
    set write_verilog_impl_enable [::common::dict_get_default $db_generation write_verilog.impl.enable "false"]
    set write_verilog_impl_opts [::common::dict_get_default $db_generation write_verilog.impl.opts ""]

    dict with resolved_db generation {
        set write_verilog [dict create \
            synth [dict create \
                enable $write_verilog_synth_enable \
                opts $write_verilog_synth_opts] \
            impl [dict create \
                enable $write_verilog_impl_enable \
                opts $write_verilog_impl_opts]]
    }

    set write_vhdl_synth_enable [::common::dict_get_default $db_generation write_vhdl.synth.enable "false"]
    set write_vhdl_synth_opts [::common::dict_get_default $db_generation write_vhdl.synth.opts ""]
    set write_vhdl_impl_enable [::common::dict_get_default $db_generation write_vhdl.impl.enable "false"]
    set write_vhdl_impl_opts [::common::dict_get_default $db_generation write_vhdl.impl.opts ""]

    dict with resolved_db generation {
        set write_vhdl [dict create \
            synth [dict create \
                enable $write_vhdl_synth_enable \
                opts $write_vhdl_synth_opts] \
            impl [dict create \
                enable $write_vhdl_impl_enable \
                opts $write_vhdl_impl_opts]]
    }

    set write_sdf_synth_enable [::common::dict_get_default $db_generation write_sdf.synth.enable "false"]
    set write_sdf_synth_opts [::common::dict_get_default $db_generation write_sdf.synth.opts ""]
    set write_sdf_impl_enable [::common::dict_get_default $db_generation write_sdf.impl.enable "false"]
    set write_sdf_impl_opts [::common::dict_get_default $db_generation write_sdf.impl.opts ""]

    dict with resolved_db generation {
        set write_sdf [dict create \
            synth [dict create \
                enable $write_sdf_synth_enable \
                opts $write_sdf_synth_opts] \
            impl [dict create \
                enable $write_sdf_impl_enable \
                opts $write_sdf_impl_opts]]
    }

    set write_edif_synth_enable [::common::dict_get_default $db_generation write_edif.synth.enable "false"]
    set write_edif_synth_opts [::common::dict_get_default $db_generation write_edif.synth.opts ""]
    set write_edif_impl_enable [::common::dict_get_default $db_generation write_edif.impl.enable "false"]
    set write_edif_impl_opts [::common::dict_get_default $db_generation write_edif.impl.opts ""]

    dict with resolved_db generation {
        set write_edif [dict create \
            synth [dict create \
                enable $write_edif_synth_enable \
                opts $write_edif_synth_opts] \
            impl [dict create \
                enable $write_edif_impl_enable \
                opts $write_edif_impl_opts]]
    }

    set write_xdc_synth_enable [::common::dict_get_default $db_generation write_xdc.synth.enable "false"]
    set write_xdc_synth_opts [::common::dict_get_default $db_generation write_xdc.synth.opts ""]
    set write_xdc_impl_enable [::common::dict_get_default $db_generation write_xdc.impl.enable "false"]
    set write_xdc_impl_opts [::common::dict_get_default $db_generation write_xdc.impl.opts ""]

    dict with resolved_db generation {
        set write_xdc [dict create \
            synth [dict create \
                enable $write_xdc_synth_enable \
                opts $write_xdc_synth_opts] \
            impl [dict create \
                enable $write_xdc_impl_enable \
                opts $write_xdc_impl_opts]]
    }

    set write_waivers_synth_enable [::common::dict_get_default $db_generation write_waivers.synth.enable "false"]
    set write_waivers_synth_opts [::common::dict_get_default $db_generation write_waivers.synth.opts ""]
    set write_waivers_impl_enable [::common::dict_get_default $db_generation write_waivers.impl.enable "false"]
    set write_waivers_impl_opts [::common::dict_get_default $db_generation write_waivers.impl.opts ""]

    dict with resolved_db generation {
        set write_waivers [dict create \
            synth [dict create \
                enable $write_waivers_synth_enable \
                opts $write_waivers_synth_opts] \
            impl [dict create \
                enable $write_waivers_impl_enable \
                opts $write_waivers_impl_opts]]
    }

    set write_schematic_synth_enable [::common::dict_get_default $db_generation write_schematic.synth.enable "false"]
    set write_schematic_synth_opts [::common::dict_get_default $db_generation write_schematic.synth.opts ""]
    set write_schematic_impl_enable [::common::dict_get_default $db_generation write_schematic.impl.enable "false"]
    set write_schematic_impl_opts [::common::dict_get_default $db_generation write_schematic.impl.opts ""]

    dict with resolved_db generation {
        set write_schematic [dict create \
            synth [dict create \
                enable $write_schematic_synth_enable \
                opts $write_schematic_synth_opts] \
            impl [dict create \
                enable $write_schematic_impl_enable \
                opts $write_schematic_impl_opts]]
    }

    puts "\nResolve the report...\n"

    set db_report [::common::dict_get_required $db report \
        "Error: The report section in the project.yaml is missing!"]

    set methodology_synth_enable [::common::dict_get_default $db_report methodology.synth.enable "false"]
    set methodology_synth_opts [::common::dict_get_default $db_report methodology.synth.opts ""]
    set methodology_impl_enable [::common::dict_get_default $db_report methodology.impl.enable "false"]
    set methodology_impl_opts [::common::dict_get_default $db_report methodology.impl.opts ""]

    dict with resolved_db report {
        set methodology [dict create \
            synth [dict create \
                enable $methodology_synth_enable \
                opts $methodology_synth_opts] \
            impl [dict create \
                enable $methodology_impl_enable \
                opts $methodology_impl_opts]]
    }

    set timing_summary_synth_enable [::common::dict_get_default $db_report timing_summary.synth.enable "false"]
    set timing_summary_synth_opts [::common::dict_get_default $db_report timing_summary.synth.opts ""]
    set timing_summary_impl_enable [::common::dict_get_default $db_report timing_summary.impl.enable "false"]
    set timing_summary_impl_opts [::common::dict_get_default $db_report timing_summary.impl.opts ""]

    dict with resolved_db report {
        set timing_summary [dict create \
            synth [dict create \
                enable $timing_summary_synth_enable \
                opts $timing_summary_synth_opts] \
            impl [dict create \
                enable $timing_summary_impl_enable \
                opts $timing_summary_impl_opts]]
    }

    set drc_synth_enable [::common::dict_get_default $db_report drc.synth.enable "false"]
    set drc_synth_opts [::common::dict_get_default $db_report drc.synth.opts ""]
    set drc_impl_enable [::common::dict_get_default $db_report drc.impl.enable "false"]
    set drc_impl_opts [::common::dict_get_default $db_report drc.impl.opts ""]

    dict with resolved_db report {
        set drc [dict create \
            synth [dict create \
                enable $drc_synth_enable \
                opts $drc_synth_opts] \
            impl [dict create \
                enable $drc_impl_enable \
                opts $drc_impl_opts]]
    }

    set timing_synth_enable [::common::dict_get_default $db_report timing.synth.enable "false"]
    set timing_synth_opts [::common::dict_get_default $db_report timing.synth.opts ""]
    set timing_impl_enable [::common::dict_get_default $db_report timing.impl.enable "false"]
    set timing_impl_opts [::common::dict_get_default $db_report timing.impl.opts ""]

    dict with resolved_db report {
        set timing [dict create \
            synth [dict create \
                enable $timing_synth_enable \
                opts $timing_synth_opts] \
            impl [dict create \
                enable $timing_impl_enable \
                opts $timing_impl_opts]]
    }

    set clock_networks_synth_enable [::common::dict_get_default $db_report clock_networks.synth.enable "false"]
    set clock_networks_synth_opts [::common::dict_get_default $db_report clock_networks.synth.opts ""]
    set clock_networks_impl_enable [::common::dict_get_default $db_report clock_networks.impl.enable "false"]
    set clock_networks_impl_opts [::common::dict_get_default $db_report clock_networks.impl.opts ""]

    dict with resolved_db report {
        set clock_networks [dict create \
            synth [dict create \
                enable $clock_networks_synth_enable \
                opts $clock_networks_synth_opts] \
            impl [dict create \
                enable $clock_networks_impl_enable \
                opts $clock_networks_impl_opts]]
    }

    set clock_interaction_synth_enable [::common::dict_get_default $db_report clock_interaction.synth.enable "false"]
    set clock_interaction_synth_opts [::common::dict_get_default $db_report clock_interaction.synth.opts ""]
    set clock_interaction_impl_enable [::common::dict_get_default $db_report clock_interaction.impl.enable "false"]
    set clock_interaction_impl_opts [::common::dict_get_default $db_report clock_interaction.impl.opts ""]

    dict with resolved_db report {
        set clock_interaction [dict create \
            synth [dict create \
                enable $clock_interaction_synth_enable \
                opts $clock_interaction_synth_opts] \
            impl [dict create \
                enable $clock_interaction_impl_enable \
                opts $clock_interaction_impl_opts]]
    }

    set cdc_synth_enable [::common::dict_get_default $db_report cdc.synth.enable "false"]
    set cdc_synth_opts [::common::dict_get_default $db_report cdc.synth.opts ""]
    set cdc_impl_enable [::common::dict_get_default $db_report cdc.impl.enable "false"]
    set cdc_impl_opts [::common::dict_get_default $db_report cdc.impl.opts ""]

    dict with resolved_db report {
        set cdc [dict create \
            synth [dict create \
                enable $cdc_synth_enable \
                opts $cdc_synth_opts] \
            impl [dict create \
                enable $cdc_impl_enable \
                opts $cdc_impl_opts]]
    }

    set power_synth_enable [::common::dict_get_default $db_report power.synth.enable "false"]
    set power_synth_opts [::common::dict_get_default $db_report power.synth.opts ""]
    set power_impl_enable [::common::dict_get_default $db_report power.impl.enable "false"]
    set power_impl_opts [::common::dict_get_default $db_report power.impl.opts ""]

    dict with resolved_db report {
        set power [dict create \
            synth [dict create \
                enable $power_synth_enable \
                opts $power_synth_opts] \
            impl [dict create \
                enable $power_impl_enable \
                opts $power_impl_opts]]
    }

    set clock_utilization_synth_enable [::common::dict_get_default $db_report clock_utilization.synth.enable "false"]
    set clock_utilization_synth_opts [::common::dict_get_default $db_report clock_utilization.synth.opts ""]
    set clock_utilization_impl_enable [::common::dict_get_default $db_report clock_utilization.impl.enable "false"]
    set clock_utilization_impl_opts [::common::dict_get_default $db_report clock_utilization.impl.opts ""]

    dict with resolved_db report {
        set clock_utilization [dict create \
            synth [dict create \
                enable $clock_utilization_synth_enable \
                opts $clock_utilization_synth_opts] \
            impl [dict create \
                enable $clock_utilization_impl_enable \
                opts $clock_utilization_impl_opts]]
    }

    set qor_suggestions_synth_enable [::common::dict_get_default $db_report qor_suggestions.synth.enable "false"]
    set qor_suggestions_synth_opts [::common::dict_get_default $db_report qor_suggestions.synth.opts ""]
    set qor_suggestions_impl_enable [::common::dict_get_default $db_report qor_suggestions.impl.enable "false"]
    set qor_suggestions_impl_opts [::common::dict_get_default $db_report qor_suggestions.impl.opts ""]

    dict with resolved_db report {
        set qor_suggestions [dict create \
            synth [dict create \
                enable $qor_suggestions_synth_enable \
                opts $qor_suggestions_synth_opts] \
            impl [dict create \
                enable $qor_suggestions_impl_enable \
                opts $qor_suggestions_impl_opts]]
    }

    set high_fanout_nets_synth_enable [::common::dict_get_default $db_report high_fanout_nets.synth.enable "false"]
    set high_fanout_nets_synth_opts [::common::dict_get_default $db_report high_fanout_nets.synth.opts ""]
    set high_fanout_nets_impl_enable [::common::dict_get_default $db_report high_fanout_nets.impl.enable "false"]
    set high_fanout_nets_impl_opts [::common::dict_get_default $db_report high_fanout_nets.impl.opts ""]

    dict with resolved_db report {
        set high_fanout_nets [dict create \
            synth [dict create \
                enable $high_fanout_nets_synth_enable \
                opts $high_fanout_nets_synth_opts] \
            impl [dict create \
                enable $high_fanout_nets_impl_enable \
                opts $high_fanout_nets_impl_opts]]
    }

    set qor_assessment_synth_enable [::common::dict_get_default $db_report qor_assessment.synth.enable "false"]
    set qor_assessment_synth_opts [::common::dict_get_default $db_report qor_assessment.synth.opts ""]
    set qor_assessment_impl_enable [::common::dict_get_default $db_report qor_assessment.impl.enable "false"]
    set qor_assessment_impl_opts [::common::dict_get_default $db_report qor_assessment.impl.opts ""]

    dict with resolved_db report {
        set qor_assessment [dict create \
            synth [dict create \
                enable $qor_assessment_synth_enable \
                opts $qor_assessment_synth_opts] \
            impl [dict create \
                enable $qor_assessment_impl_enable \
                opts $qor_assessment_impl_opts]]
    }

    set design_analysis_synth_enable [::common::dict_get_default $db_report design_analysis.synth.enable "false"]
    set design_analysis_synth_opts [::common::dict_get_default $db_report design_analysis.synth.opts ""]
    set design_analysis_impl_enable [::common::dict_get_default $db_report design_analysis.impl.enable "false"]
    set design_analysis_impl_opts [::common::dict_get_default $db_report design_analysis.impl.opts ""]

    dict with resolved_db report {
        set design_analysis [dict create \
            synth [dict create \
                enable $design_analysis_synth_enable \
                opts $design_analysis_synth_opts] \
            impl [dict create \
                enable $design_analysis_impl_enable \
                opts $design_analysis_impl_opts]]
    }

    set dfx_summary_synth_enable [::common::dict_get_default $db_report dfx_summary.synth.enable "false"]
    set dfx_summary_synth_opts [::common::dict_get_default $db_report dfx_summary.synth.opts ""]
    set dfx_summary_impl_enable [::common::dict_get_default $db_report dfx_summary.impl.enable "false"]
    set dfx_summary_impl_opts [::common::dict_get_default $db_report dfx_summary.impl.opts ""]

    dict with resolved_db report {
        set dfx_summary [dict create \
            synth [dict create \
                enable $dfx_summary_synth_enable \
                opts $dfx_summary_synth_opts] \
            impl [dict create \
                enable $dfx_summary_impl_enable \
                opts $dfx_summary_impl_opts]]
    }

    set bus_skew_synth_enable [::common::dict_get_default $db_report bus_skew.synth.enable "false"]
    set bus_skew_synth_opts [::common::dict_get_default $db_report bus_skew.synth.opts ""]
    set bus_skew_impl_enable [::common::dict_get_default $db_report bus_skew.impl.enable "false"]
    set bus_skew_impl_opts [::common::dict_get_default $db_report bus_skew.impl.opts ""]

    dict with resolved_db report {
        set bus_skew [dict create \
            synth [dict create \
                enable $bus_skew_synth_enable \
                opts $bus_skew_synth_opts] \
            impl [dict create \
                enable $bus_skew_impl_enable \
                opts $bus_skew_impl_opts]]
    }

    set datasheet_synth_enable [::common::dict_get_default $db_report datasheet.synth.enable "false"]
    set datasheet_synth_opts [::common::dict_get_default $db_report datasheet.synth.opts ""]
    set datasheet_impl_enable [::common::dict_get_default $db_report datasheet.impl.enable "false"]
    set datasheet_impl_opts [::common::dict_get_default $db_report datasheet.impl.opts ""]

    dict with resolved_db report {
        set datasheet [dict create \
            synth [dict create \
                enable $datasheet_synth_enable \
                opts $datasheet_synth_opts] \
            impl [dict create \
                enable $datasheet_impl_enable \
                opts $datasheet_impl_opts]]
    }

    set route_status_synth_enable [::common::dict_get_default $db_report route_status.synth.enable "false"]
    set route_status_synth_opts [::common::dict_get_default $db_report route_status.synth.opts ""]
    set route_status_impl_enable [::common::dict_get_default $db_report route_status.impl.enable "false"]
    set route_status_impl_opts [::common::dict_get_default $db_report route_status.impl.opts ""]

    dict with resolved_db report {
        set route_status [dict create \
            synth [dict create \
                enable $route_status_synth_enable \
                opts $route_status_synth_opts] \
            impl [dict create \
                enable $route_status_impl_enable \
                opts $route_status_impl_opts]]
    }

    set io_synth_enable [::common::dict_get_default $db_report io.synth.enable "false"]
    set io_synth_opts [::common::dict_get_default $db_report io.synth.opts ""]
    set io_impl_enable [::common::dict_get_default $db_report io.impl.enable "false"]
    set io_impl_opts [::common::dict_get_default $db_report io.impl.opts ""]

    dict with resolved_db report {
        set io [dict create \
            synth [dict create \
                enable $io_synth_enable \
                opts $io_synth_opts] \
            impl [dict create \
                enable $io_impl_enable \
                opts $io_impl_opts]]
    }

    set utilization_synth_enable [::common::dict_get_default $db_report utilization.synth.enable "false"]
    set utilization_synth_opts [::common::dict_get_default $db_report utilization.synth.opts ""]
    set utilization_impl_enable [::common::dict_get_default $db_report utilization.impl.enable "false"]
    set utilization_impl_opts [::common::dict_get_default $db_report utilization.impl.opts ""]

    dict with resolved_db report {
        set utilization [dict create \
            synth [dict create \
                enable $utilization_synth_enable \
                opts $utilization_synth_opts] \
            impl [dict create \
                enable $utilization_impl_enable \
                opts $utilization_impl_opts]]
    }

    set control_sets_synth_enable [::common::dict_get_default $db_report control_sets.synth.enable "false"]
    set control_sets_synth_opts [::common::dict_get_default $db_report control_sets.synth.opts ""]
    set control_sets_impl_enable [::common::dict_get_default $db_report control_sets.impl.enable "false"]
    set control_sets_impl_opts [::common::dict_get_default $db_report control_sets.impl.opts ""]

    dict with resolved_db report {
        set control_sets [dict create \
            synth [dict create \
                enable $control_sets_synth_enable \
                opts $control_sets_synth_opts] \
            impl [dict create \
                enable $control_sets_impl_enable \
                opts $control_sets_impl_opts]]
    }

    set ssn_synth_enable [::common::dict_get_default $db_report ssn.synth.enable "false"]
    set ssn_synth_opts [::common::dict_get_default $db_report ssn.synth.opts ""]
    set ssn_impl_enable [::common::dict_get_default $db_report ssn.impl.enable "false"]
    set ssn_impl_opts [::common::dict_get_default $db_report ssn.impl.opts ""]

    dict with resolved_db report {
        set ssn [dict create \
            synth [dict create \
                enable $ssn_synth_enable \
                opts $ssn_synth_opts] \
            impl [dict create \
                enable $ssn_impl_enable \
                opts $ssn_impl_opts]]
    }

    set ram_utilization_synth_enable [::common::dict_get_default $db_report ram_utilization.synth.enable "false"]
    set ram_utilization_synth_opts [::common::dict_get_default $db_report ram_utilization.synth.opts ""]
    set ram_utilization_impl_enable [::common::dict_get_default $db_report ram_utilization.impl.enable "false"]
    set ram_utilization_impl_opts [::common::dict_get_default $db_report ram_utilization.impl.opts ""]

    dict with resolved_db report {
        set ram_utilization [dict create \
            synth [dict create \
                enable $ram_utilization_synth_enable \
                opts $ram_utilization_synth_opts] \
            impl [dict create \
                enable $ram_utilization_impl_enable \
                opts $ram_utilization_impl_opts]]
    }

    set resolved 1

    set prj_name [::project::internal::name]
    set prj_ver [::project::internal::version]

    puts ""
    puts "========================================"
    puts "Project resolved successfully."
    puts "Name: $prj_name"
    puts "Version: $prj_ver"
    puts "========================================"
}

proc ::project::internal::load_prj {path} {
    variable db {}
    variable resolved_db {}
    variable loaded 0
    variable resolved 0
    variable prepared 0
    variable designed 0
    variable synthesized 0
    variable implemented 0
    variable bitstream_generated 0
    variable xsa_generated 0
    variable PRJ_SRC_PATH

    ::project::close

    set cfg [yaml::load_yaml $path]

    if {![dict exists $cfg project]} {
        error "Invalid project configuration:\n$path"
    }

    set db $cfg
    set loaded 1

    set project_name [dict get $cfg project name]
    set project_path [file join $PRJ_SRC_PATH $project_name]

    puts ""
    puts "========================================"
    puts "Project loaded successfully."
    puts "Name: $project_name"
    puts "Path: $project_path"
    puts "========================================"
}

proc ::project::prepare {{log_mode "quiet"}} {
    variable internal::resolved_db
    variable internal::BUILD_PATH
    variable internal::PRJ_BUILD_PATH
    variable internal::PACKAGE_PATH
    variable internal::prepared

    ::project::internal::check_is_resolved

    set log_opts [::common::log_option $log_mode]

    set init_path [::project::internal::set_working_dir]

    # ------------------------------------------------------------------
    # Prepare build directories
    # ------------------------------------------------------------------
    set prj_build_path [::project::internal::get project.project_build_path]

    set bd_path [file join $prj_build_path bd]
    set dcp_path [file join $prj_build_path dcp]

    foreach path [list $bd_path $dcp_path] {
        if {![file exists $path]} {
            file mkdir $path
        }
    }

    # ------------------------------------------------------------------
    # Prepare project target
    # ------------------------------------------------------------------
    set target [::project::internal::target]
    set target_type [dict get $target type]
    set target_lang_prj [::project::internal::language]

    switch -- $target_type {
        part {
            set part [dict get $target part]

            if {$part eq ""} {
                error "Project target type is 'part' but no part was specified."
            }

            puts "Set target part: $part"
            set_part {*}$log_opts $part
        }

        board {
            set board [dict get $target board]

            if {$board eq ""} {
                error "Project target type is 'board' but no board was specified."
            }

            puts "Set target board: $board"
            create_project {*}$log_opts -in_memory
            set_property {*}$log_opts board_part $board [current_project]
        }

        default {
            error "Unsupported project target type: $target_type"
        }
    }

    # ------------------------------------------------------------------
    # Project Setting
    # ------------------------------------------------------------------
    set_property {*}$log_opts TARGET_LANGUAGE $target_lang_prj [current_project]
    set_property {*}$log_opts source_mgmt_mode All [current_project]

    # ------------------------------------------------------------------
    # Update IP Catalog
    # ------------------------------------------------------------------
    set_property {*}$log_opts ip_repo_paths [list $PACKAGE_PATH] [current_project]
    update_ip_catalog {*}$log_opts

    # ------------------------------------------------------------------
    # Read RTL sources
    # ------------------------------------------------------------------
    puts "\nPrepare RTL sources...\n"

    set rtl_files [::project::internal::get resources.rtl]

    foreach rtl_file $rtl_files {
        set ext [string tolower [file extension $rtl_file]]

        switch -- $ext {
            ".v" -
            ".vh" {
                puts "    read_verilog: $rtl_file"
                read_verilog {*}$log_opts $rtl_file
            }

            ".sv" -
            ".svh" {
                puts "    read_verilog -sv: $rtl_file"
                read_verilog {*}$log_opts -sv $rtl_file
            }

            ".vhd" -
            ".vhdl" {
                puts "    read_vhdl: $rtl_file"
                read_vhdl {*}$log_opts $rtl_file
            }

            default {
                error "Unsupported RTL file extension: $rtl_file"
            }
        }
    }

    # ------------------------------------------------------------------
    # Read IP
    # ------------------------------------------------------------------
    puts "\nPrepare IPs...\n"

    set ips [::project::internal::get resources.ip]

    foreach ip $ips {
        set ip_name [dict get $ip name]
        set ip_version [dict get $ip version]
        set ip_variant [dict get $ip variant]
        set ip_xci [dict get $ip path]

        puts "    read_ip: $ip_name v$ip_version ($ip_variant)"
        puts "             $ip_xci"

        read_ip {*}$log_opts $ip_xci
    }

    # ------------------------------------------------------------------
    # Prepare constraints
    # ------------------------------------------------------------------
    puts "\nPrepare constraints...\n"

    set constraints [::project::internal::get resources.constraints]

    foreach constraint $constraints {
        puts "    read_xdc: $constraint"
        read_xdc {*}$log_opts $constraint
    }

    update_compile_order {*}$log_opts

    # ------------------------------------------------------------------
    # Block designs
    #
    # Do NOT source the BD Tcl here.
    #
    # At this stage the user may still want to open Vivado and
    # construct the BD interactively.
    # ------------------------------------------------------------------
    set bd [::project::internal::get resources.bd]

    if {[llength $bd] == 0} {
        puts "No block designs specified."
    } else {
        puts "Block design available:"
        set bd_name [dict get $bd name]
        set bd_tcl [dict get $bd path]

        puts "    $bd_name"
        puts "      $bd_tcl"
    }

    ::common::set_working_dir $init_path

    # ------------------------------------------------------------------
    # Save preparation state
    # ------------------------------------------------------------------
    set prepared 1

    set prj_name [::project::internal::name]
    set prj_ver [::project::internal::version]

    puts ""
    puts "========================================"
    puts "Project preparation compeleted."
    puts "Name: $prj_name"
    puts "Version: $prj_ver"
    puts "========================================"
}

proc ::project::design {{log_mode "quiet"}} {
    variable internal::PRJ_BUILD_PATH
    variable internal::project_path
    variable internal::resolved_db
    variable internal::designed

    ::project::internal::check_is_prepared

    set log_opts [::common::log_option $log_mode]

    set init_path [::project::internal::set_working_dir]

    puts ""
    puts "========================================"
    puts "Create project design"
    puts "========================================"

    # ------------------------------------------------------------------
    # Block design
    #
    # The BD is optional. If specified, the exported BD Tcl is sourced
    # and the resulting block design is validated.
    # ------------------------------------------------------------------

    if {[dict exists $resolved_db resources bd]} {
        set bd [::project::internal::get resources.bd]

        set bd_name [dict get $bd name]
        set bd_path [dict get $bd path]

        if {$bd_name eq ""} {
            error "Block design name is empty."
        }

        if {$bd_path eq ""} {
            error "Block design path is empty."
        }

        if {![file exists $bd_path]} {
            error "Block design Tcl file does not exist: $bd_path"
        }

        puts "\nCreate block design..."
        puts "    Name: $bd_name"
        puts "    Tcl:  $bd_path"
        puts ""

        # Clean the build generated block-design
        set build_bd_path [file join [::project::internal::build_path] \
            [format "bd/%s" $bd_name]]

        if {[file exists $build_bd_path]} {
            file delete -force $build_bd_path
        }

        puts "    Source block design Tcl..."
        uplevel #0 [list source $bd_path]

        # Verify that the BD now exists.
        set bd_obj [get_bd_designs $bd_name -quiet]

        if {[llength $bd_obj] == 0} {
            error "Block design was not created: $bd_name"
        }

        # Make this BD the current BD.
        ::current_bd_design {*}$log_opts $bd_name

        set bd_file [format "%s.bd" $bd_name]

        set_property {*}$log_opts synth_checkpoint_mode None [get_files $bd_file]
        ::generate_target {*}$log_opts all [get_files $bd_file]
    } else {
        puts "No block design specified."
    }

    # ------------------------------------------------------------------
    # Top-level source
    #
    # The top is mandatory. It can be an RTL top or a generated BD
    # wrapper. project::resolve has already converted the path to an
    # absolute path.
    # ------------------------------------------------------------------

    if {![dict exists $resolved_db resources top]} {
        error "Error: No top design specified."
    }

    set top [::project::internal::get resources.top]
    set top_name [dict get $top name]
    set top_path [dict get $top path]

    if {$top_path eq ""} {
        error "Top design path is empty."
    }

    if {$top_name eq ""} {
        error "Top design name is empty."
    }

    if {![file exists $top_path]} {
        error "Top design file does not exist: $top_path"
    }

    puts ""
    puts "Add top-level source..."

    set top_ext [string tolower [file extension $top_path]]
    switch -- $top_ext {
        ".v" {
            puts "Add Verilog top design wrapper: $top_path"
            read_verilog {*}$log_opts $top_path
        }

        ".vhd" -
        ".vhdl" {
            puts "Add VHDL top design wrapper: $top_path"
            read_vhdl {*}$log_opts $top_path
        }

        default {
            error "Unsupported RTL file extension: $top_path"
        }
    }

    # ------------------------------------------------------------------
    # Determine top module/entity from the source file.
    # ------------------------------------------------------------------

    puts "\nSet top design: $top_name"

    set_property {*}$log_opts top $top_name [current_fileset]

    # ------------------------------------------------------------------
    # Verify top
    # ------------------------------------------------------------------

    set configured_top [get_property {*}$log_opts top [current_fileset]]

    if {$configured_top ne $top_name} {
        error "Failed to set top design. Expected '$top_name', got '$configured_top'."
    }

    ::common::set_working_dir $init_path

    # ------------------------------------------------------------------
    # Design status
    # ------------------------------------------------------------------

    set designed 1

    set prj_name [::project::internal::name]
    set prj_ver [::project::internal::version]

    puts ""
    puts "========================================"
    puts "Project design completed."
    puts "Name: $prj_name"
    puts "Version: $prj_ver"
    puts "Top: $top_name"
    puts "========================================"
}

proc ::project::synth {{log_mode "quiet"}} {
    variable internal::synthesized
    variable internal::PRJ_BUILD_PATH
    variable internal::resolved_db

    ::project::internal::check_is_designed

    set log_opts [::common::log_option $log_mode]

    set init_path [::project::internal::set_working_dir]

    # ------------------------------------------------------------------
    # Reset synthesis state
    # ------------------------------------------------------------------
    set synthesized 0

    # ------------------------------------------------------------------
    # Prepare output directories
    # ------------------------------------------------------------------
    set prj_build_path [::project::internal::build_path]

    set synth_path [file join $prj_build_path synth]
    set generateds_path [file join $synth_path generateds]
    set report_path [file join $synth_path reports]

    foreach path [list $synth_path $generateds_path $report_path] {
        if {![file exists $path]} {
            file mkdir $path
        }
    }

    # ------------------------------------------------------------------
    # Part
    # ------------------------------------------------------------------
    set part [get_property PART [current_project]]
    if {$part eq ""} {
        error "No target part is configured for the project."
    }

    # ------------------------------------------------------------------
    # Top
    # ------------------------------------------------------------------
    set top [::project::internal::get resources.top]

    set top_path [::common::dict_get_default $top path ""]
    set top_name [::common::dict_get_required $top name \
        "Top level name file is not specified"]

    if {![file exists $top_path]} {
        error "Top-level source file does not exist: $top_path"
    }

    # ------------------------------------------------------------------
    # Synthesis configuration
    # ------------------------------------------------------------------
    set strategy [::project::internal::get_default configuration.synth.strategy ""]
    set directive [::project::internal::get_default configuration.synth.directive ""]
    set opts [::project::internal::get_default configuration.synth.opts {}]

    # ------------------------------------------------------------------
    # Configure synthesis strategy
    # This option is supported from 2026.1
    # ------------------------------------------------------------------
    #    if {$strategy ne ""} {
    #        puts "Configure synthesis strategy:"
    #        puts "    $strategy"
    #
    #        config_flows -synth_strategy $strategy
    #    }
    if {$directive ne ""} {
        puts "Synthesis strategy:"
        puts "    $directive"
    }

    # ------------------------------------------------------------------
    # Explicit synthesis options
    # ------------------------------------------------------------------
    if {[llength $opts] > 0} {
        puts "Synthesis options:"
        puts "    $opts"
    }

    # ------------------------------------------------------------------
    # Run synthesis
    # ------------------------------------------------------------------
    puts ""
    puts "Run synthesis..."
    puts "    Top : $top_name"
    puts "    Part: $part"

    set synth_opts [list \
        -top $top_name \
        -part $part]

    if {$directive ne ""} {
        lappend synth_opts -directive $directive
    }

    set synth_opts [concat $synth_opts $opts]

    puts "Command: synth_design $synth_opts"

    ::synth_design {*}$log_opts {*}$synth_opts

    # ------------------------------------------------------------------
    # Checkpoint
    # ------------------------------------------------------------------
    set dcp_path [file join $prj_build_path dcp post_synth.dcp]

    puts ""
    puts "Write synthesis checkpoint:"
    puts "    $dcp_path"

    ::write_checkpoint {*}$log_opts -force $dcp_path

    # ------------------------------------------------------------------
    # Update state
    # ------------------------------------------------------------------
    set synthesized 1

    # ------------------------------------------------------------------
    # Generate
    # ------------------------------------------------------------------
    puts ""
    puts "Generate synthesis related files..."

    ::project::internal::generate_results synth $generateds_path $log_mode

    # ------------------------------------------------------------------
    # Reports
    # ------------------------------------------------------------------
    puts ""
    puts "Generate synthesis reports..."

    ::project::internal::generate_reports synth $report_path $log_mode

    ::common::set_working_dir $init_path

    puts ""
    puts "Synthesis completed successfully."
}

proc ::project::impl {{log_mode "quiet"}} {
    variable internal::implemented
    variable internal::PRJ_BUILD_PATH

    ::project::internal::check_is_synthesized

    set log_opts [::common::log_option $log_mode]

    set init_path [::project::internal::set_working_dir]

    # ------------------------------------------------------------------
    # Reset implementation state
    # ------------------------------------------------------------------
    set implemented 0

    # ------------------------------------------------------------------
    # Prepare output directories
    # ------------------------------------------------------------------
    set prj_build_path [::project::internal::build_path]

    set impl_path [file join $prj_build_path impl]
    set generateds_path [file join $impl_path generateds]
    set report_path [file join $impl_path reports]

    foreach path [list $impl_path $report_path $generateds_path] {
        if {![file exists $path]} {
            file mkdir $path
        }
    }

    # ------------------------------------------------------------------
    # Implementation configuration
    # ------------------------------------------------------------------
    set strategy [::project::internal::get_default configuration.impl.strategy ""]

    set optimize_directive [::project::internal::get_default configuration.impl.optimize.directive ""]
    set place_directive [::project::internal::get_default configuration.impl.place.directive ""]
    set route_directive [::project::internal::get_default configuration.impl.route.directive ""]
    set optimize_opts [::project::internal::get_default configuration.impl.optimize.opts {}]
    set place_opts [::project::internal::get_default configuration.impl.place.opts {}]
    set route_opts [::project::internal::get_default configuration.impl.route.opts {}]
    set power_optimize_cfg [::project::internal::get_default configuration.impl.power_optimize ""]
    set physical_optimize_cfg [::project::internal::get_default configuration.impl.physical_optimize ""]
    set power_optimize_enabled [dict get $power_optimize_cfg enabled]
    set power_optimize_opts [dict get $power_optimize_cfg opts]
    set physical_optimize_enabled [dict get $physical_optimize_cfg enabled]
    set physical_optimize_directive [dict get $physical_optimize_cfg directive]
    set physical_optimize_opts [dict get $physical_optimize_cfg opts]
    if {$physical_optimize_enabled eq "true"} {
        lappend physical_optimize_opts -directive $physical_optimize_directive
    }

    lappend optimize_opts -directive $optimize_directive
    lappend place_opts -directive $place_directive
    lappend route_opts -directive $route_directive

    puts "Optimize directive:  $optimize_directive"
    puts "Place directive:     $place_directive"
    puts "Route directive:     $route_directive"

    # ------------------------------------------------------------------
    # Configure implementation strategy
    # This feature is added from 2026.1
    # ------------------------------------------------------------------
    #    if {$strategy ne ""} {
    #        puts "Configure implementation strategy:"
    #        puts "    $strategy"
    #
    #        config_flows -impl_strategy $strategy
    #    }

    # ------------------------------------------------------------------
    # Optimization
    # ------------------------------------------------------------------
    puts ""
    puts "Run optimization..."

    puts "Command: opt_design $optimize_opts"
    ::opt_design {*}$log_opts {*}$optimize_opts

    # ------------------------------------------------------------------
    # Power optimization
    # ------------------------------------------------------------------
    if {$power_optimize_enabled eq "true"} {
        puts ""
        puts "Run power optimization..."

        puts "Command: power_opt_design $power_optimize_opts"
        ::power_opt_design {*}$log_opts {*}$power_optimize_opts
    }

    # ------------------------------------------------------------------
    # Placement
    # ------------------------------------------------------------------
    puts ""
    puts "Run placement..."

    puts "Command: place_design $place_opts"
    ::place_design {*}$log_opts {*}$place_opts

    # ------------------------------------------------------------------
    # Post-Place Power optimization
    # ------------------------------------------------------------------
    if {$power_optimize_enabled eq "true"} {
        puts ""
        puts "Run post-place power optimization..."

        puts "Command: power_opt_design $power_optimize_opts"
        ::power_opt_design {*}$log_opts {*}$power_optimize_opts
    }

    # ------------------------------------------------------------------
    # Post-Place physical optimization
    # ------------------------------------------------------------------
    if {$physical_optimize_enabled eq "true"} {
        puts ""
        puts "Run post-place physical optimization..."

        puts "Command: phys_opt_design $physical_optimize_opts"
        ::phys_opt_design {*}$log_opts {*}$physical_optimize_opts
    }

    # ------------------------------------------------------------------
    # Routing
    # ------------------------------------------------------------------
    puts ""
    puts "Run routing..."

    puts "Command: route_design $route_opts"
    ::route_design {*}$log_opts {*}$route_opts

    # ------------------------------------------------------------------
    # Post-Routing physical optimization
    # ------------------------------------------------------------------
    if {$physical_optimize_enabled eq "true"} {
        puts ""
        puts "Run post-routing physical optimization..."

        puts "Command: phys_opt_design $physical_optimize_opts"
        ::phys_opt_design {*}$log_opts {*}$physical_optimize_opts
    }

    # ------------------------------------------------------------------
    # Checkpoint
    # ------------------------------------------------------------------
    set dcp_path [file join $prj_build_path dcp post_impl.dcp]

    puts ""
    puts "Write implementation checkpoint:"
    puts "    $dcp_path"

    ::write_checkpoint {*}$log_opts -force $dcp_path

    # ------------------------------------------------------------------
    # Update state
    # ------------------------------------------------------------------
    set implemented 1

    # ------------------------------------------------------------------
    # Generate
    # ------------------------------------------------------------------
    puts ""
    puts "Generate synthesis related files..."

    ::project::internal::generate_results impl $generateds_path $log_mode

    # ------------------------------------------------------------------
    # Reports
    # ------------------------------------------------------------------
    puts ""
    puts "Generate synthesis reports..."

    ::project::internal::generate_reports impl $report_path $log_mode

    ::common::set_working_dir $init_path

    puts ""
    puts "Implementation completed successfully."
}

proc ::project::bitstream_gen {{log_mode "quiet"}} {
    variable internal::PRJ_BUILD_PATH
    variable internal::bitstream_generated

    ::project::internal::check_is_implemented

    set bitstream_generated 0

    set log_opts [::common::log_option $log_mode]

    set init_path [::project::internal::set_working_dir]

    # ------------------------------------------------------------------
    # Prepare output directories
    # ------------------------------------------------------------------
    set prj_build_path [::project::internal::build_path]

    set bitstream_path [file join $prj_build_path bitstream]

    foreach path [list $bitstream_path] {
        if {![file exists $path]} {
            file mkdir $path
        }
    }

    # ------------------------------------------------------------------
    # Generate bitstream
    # ------------------------------------------------------------------
    set opts [::project::internal::get_default configuration.bitstream.opts {}]

    set bit_path [file join $bitstream_path \
        [format "%s_v%s.bit" [::project::internal::name] [::project::internal::version]]]

    puts ""
    puts "Generate bitstream..."
    puts "    Output: $bit_path"

    puts "Command: write_bitstream -force $bit_path {*}$opts"

    ::write_bitstream {*}$log_opts \
        -force \
        {*}$opts \
        $bit_path


    ::common::set_working_dir $init_path

    # ------------------------------------------------------------------
    # Update state
    # ------------------------------------------------------------------
    set bitstream_generated 1

    puts ""
    puts "Bitstream generation completed successfully."
}

proc ::project::xsa_gen {{log_mode "quiet"}} {
    variable internal::PRJ_BUILD_PATH
    variable internal::xsa_generated

    ::project::internal::check_is_bitstream_generated

    set xsa_generated 0

    set log_opts [::common::log_option $log_mode]

    set init_path [::project::internal::set_working_dir]

    # ------------------------------------------------------------------
    # Prepare output directories
    # ------------------------------------------------------------------
    set prj_build_path [::project::internal::build_path]

    set xsa_path [file join $prj_build_path xsa]

    if {![file exists $xsa_path]} {
        file mkdir $xsa_path
    }

    # ------------------------------------------------------------------
    # XSA options
    # ------------------------------------------------------------------
    set opts [::project::internal::get_default configuration.xsa.opts {}]

    # ------------------------------------------------------------------
    # Generate XSA
    # ------------------------------------------------------------------
    set xsa_file [file join $xsa_path \
        [format "%s_v%s.xsa" [::project::internal::name] [::project::internal::version]]]

    puts ""
    puts "Generate XSA..."
    puts "    Output: $xsa_file"

    puts "Command: write_hw_platform -fixed -include_bit -force $xsa_file {*}$opts"

    ::write_hw_platform {*}$log_opts \
        -fixed \
        -include_bit \
        -force \
        {*}$opts \
        $xsa_file

    ::common::set_working_dir $init_path

    # ------------------------------------------------------------------
    # Update state
    # ------------------------------------------------------------------
    set xsa_generated 1

    puts ""
    puts "XSA generation completed successfully."
}

proc ::project::bd_create {bd_name {log_mode "quiet"}} {
    variable internal::PRJ_BUILD_PATH

    ::project::internal::check_is_prepared

    set log_opts [::common::log_option $log_mode]

    set init_path [::project::internal::set_working_dir]

    set build_path [::project::internal::build_path]

    set bd_path [file join $build_path "bd"]

    puts "Creating Block-Design..."
    ::create_bd_design {*}$log_opts -dir $bd_path $bd_name

    ::update_compile_order {*}$log_opts

    ::common::set_working_dir $init_path

    puts ""
    puts "Block-Design created successfully."
    puts "    Name: $bd_name"
    puts "    Path: $bd_path"
}

proc ::project::bd_regenerate {bd_name bd_path {log_mode "quiet"}} {
    variable internal::PRJ_BUILD_PATH

    ::project::internal::check_is_prepared

    if {$bd_path eq ""} {
        error "Block design path is empty."
    }

    if {![file exists $bd_path]} {
        error "Block design Tcl file does not exist: $bd_path"
    }

    set log_opts [::common::log_option $log_mode]

    set init_path [::project::internal::set_working_dir]

    puts "Re-Generate block design..."
    puts "    Tcl:  $bd_path"

    # Clean the build generated block-design
    set build_path [::project::internal::build_path]
    set build_bd_path [file join $build_path [format "bd/%s" $bd_name]]

    if {[file exists $build_bd_path]} {
        file delete -force $build_bd_path
    }

    puts "    Source block design Tcl..."
    uplevel #0 [list source $bd_path]

    # Verify that the BD now exists.
    set bd_obj [get_bd_designs $bd_name -quiet]

    if {[llength $bd_obj] == 0} {
        error "Block design was not created: $bd_name"
    }

    ::common::set_working_dir $init_path

    puts ""
    puts "Block-Design re-generated successfully."
    puts "    Name: $bd_name"
    puts "    Path: $build_bd_path"
}

proc ::project::bd_upgrade {bd_name {log_mode "quiet"}} {
    variable internal::PRJ_BUILD_PATH

    ::project::internal::check_is_prepared

    set log_opts [::common::log_option $log_mode]

    set init_path [::project::internal::set_working_dir]

    set build_path [::project::internal::build_path]

    set bd_file [file join $build_path [format "bd/%s/%s.bd" $bd_name $bd_name]]

    ::project::bd_open $bd_name $log_mode

    ::upgrade_ip {*}$log_opts [get_bd_cells -hierarchical *]
    ::reset_target {*}$log_opts all [get_files $bd_file]
    ::generate_target {*}$log_opts all [get_files $bd_file]

    ::common::set_working_dir $init_path

    puts ""
    puts "Block-Design upgraded successfully."
    puts "You can re-create HDL wrapper using ::project::bd_make_wrapper"
}

proc ::project::bd_open {bd_name {log_mode "quiet"}} {
    variable internal::PRJ_BUILD_PATH

    ::project::internal::check_is_prepared

    set log_opts [::common::log_option $log_mode]

    set init_path [::project::internal::set_working_dir]

    set build_path [::project::internal::build_path]

    set bd_file [file join $build_path [format "bd/%s/%s.bd" $bd_name $bd_name]]

    if {![file exists $bd_file]} {
        error "The block-design file does not exists:\n$bd_file"
    }

    ::read_bd {*}$log_opts $bd_file
    ::open_bd_design {*}$log_opts $bd_file
    ::current_bd_design {*}$log_opts $bd_file
    ::update_compile_order {*}$log_opts

    ::common::set_working_dir $init_path

    puts ""
    puts "Block-Design opened successfully."
    puts "    Name: $bd_name"
    puts "    Path: $bd_file"
}

proc ::project::bd_close {{log_mode "quiet"}} {
    variable internal::PRJ_BUILD_PATH

    ::project::internal::check_is_prepared

    set log_opts [::common::log_option $log_mode]

    set init_path [::project::internal::set_working_dir]

    ::close_bd_design {*}$log_opts [current_bd_design]

    ::common::set_working_dir $init_path

    puts ""
    puts "Block-Design closed successfully."
}

proc ::project::bd_export_tcl {{log_mode "quiet"}} {
    ::project::internal::check_is_prepared

    set log_opts [::common::log_option $log_mode]

    if {[catch {current_bd_design} bd_name]} {
        error "Error: No block design is currently open."
    } else {
        puts "Current block design: $bd_name"
    }

    set init_path [::project::internal::set_working_dir]

    set bd_export_path [file join [::project::internal::build_path] "bd/export"]
    set bd_export_path_filename [file join $bd_export_path [current_bd_design]]
    set rel_bd_create_path "./bd"

    if {![file exists $bd_export_path]} {
        file mkdir $bd_export_path
    }

    ::write_bd_tcl -force {*}$log_opts \
        -bd_folder $rel_bd_create_path \
        $bd_export_path_filename

    ::common::set_working_dir $init_path
}

proc ::project::bd_make_wrapper {bd_name {log_mode "quiet"}} {
    variable internal::PRJ_BUILD_PATH

    ::project::internal::check_is_prepared

    set log_opts [::common::log_option $log_mode]

    set init_path [::project::internal::set_working_dir]

    set build_path [::project::internal::build_path]

    set bd_path [file join $build_path [format "bd/%s" $bd_name]]
    set bd_file [file join $bd_path [format "%s.bd" $bd_name]]
    set hdl_wrapper_path [file join $bd_path [format "hdl/%s_wrapper" $bd_name]]

    if {![file exists $bd_file]} {
        error "The block-design file does not exists:\n$bd_file"
    }

    ::make_wrapper {*}$log_opts -files [get_files $bd_file] -top -force
    ::update_compile_order {*}$log_opts

    ::common::set_working_dir $init_path

    puts ""
    puts "Block-Design HDL wrapper created successfully."
    puts "    Name: $bd_name"
    puts "    Path: $hdl_wrapper_path"
}

proc ::project::close {{log_mode "quiet"}} {
    variable internal::db
    variable internal::resolved_db
    variable internal::loaded
    variable internal::resolved
    variable internal::prepared
    variable internal::designed
    variable internal::synthesized
    variable internal::implemented
    variable internal::bitstream_generated
    variable internal::xsa_generated

    set log_opts [::common::log_option $log_mode]

    if {[info commands current_project] ne ""} {
        if {[llength [current_project -quiet]] > 0} {
            close_project {*}$log_opts

            puts "Project closed."
        }
    }

    set db {}
    set resolved_db {}
    set loaded 0
    set resolved 0
    set prepared 0
    set designed 0
    set synthesized 0
    set implemented 0
    set bitstream_generated 0
    set xsa_generated 0
}

proc ::project::internal::generate_results {stage path {log_mode "quiet"}} {
    switch -- $stage {
        synth {

        }

        impl {

        }

        default {
            error "Error: The stage value for generate results is incorrect!"
        }
    }

    if {[::project::internal::get "generation.write_verilog.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "generation.write_verilog.$stage.opts"]
        set filename "project_netlist"
        ::project::internal::write_verilog $opts $path $filename $log_mode
        puts "write_verilog"
    }

    if {[::project::internal::get "generation.write_vhdl.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "generation.write_vhdl.$stage.opts"]
        set filename "project_netlist"
        ::project::internal::write_vhdl $opts $path $filename $log_mode
        puts "write_vhdl"
    }

    if {[::project::internal::get "generation.write_sdf.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "generation.write_sdf.$stage.opts"]
        set filename "project_sdf_delays"
        ::project::internal::write_sdf $opts $path $filename $log_mode
        puts "write_sdf"
    }

    if {[::project::internal::get "generation.write_edif.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "generation.write_edif.$stage.opts"]
        set filename "project_netlist"
        ::project::internal::write_edif $opts $path $filename $log_mode
        puts "write_edif"
    }

    if {[::project::internal::get "generation.write_xdc.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "generation.write_xdc.$stage.opts"]
        set filename "project_constraints"
        ::project::internal::write_xdc $opts $path $filename $log_mode
        puts "write_xdc"
    }

    if {[::project::internal::get "generation.write_waivers.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "generation.write_waivers.$stage.opts"]
        set filename "project_waivers"
        ::project::internal::write_waivers $opts $path $filename $log_mode
        puts "write_waivers"
    }

    if {[::project::internal::get "generation.write_schematic.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "generation.write_schematic.$stage.opts"]
        set filename "project_schematic"
        ::project::internal::write_schematic $opts $path $filename $log_mode
        puts "write_schematic"
    }
}

proc ::project::internal::generate_reports {stage path {log_mode "quiet"}} {
    switch -- $stage {
        synth {

        }

        impl {

        }

        default {
            error "Error: The stage value for generate results is incorrect!"
        }
    }

    if {[::project::internal::get "report.methodology.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.methodology.$stage.opts"]
        ::project::internal::report_methodology $opts $path $log_mode
        puts "report_methodology"
    }

    if {[::project::internal::get "report.timing_summary.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.timing_summary.$stage.opts"]
        ::project::internal::report_timing_summary $opts $path $log_mode
        puts "report_timing_summary"
    }

    if {[::project::internal::get "report.drc.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.drc.$stage.opts"]
        ::project::internal::report_drc $opts $path $log_mode
        puts "report_drc"
    }

    if {[::project::internal::get "report.timing.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.timing.$stage.opts"]
        ::project::internal::report_timing $opts $path $log_mode
        puts "report_timing"
    }

    if {[::project::internal::get "report.clock_networks.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.clock_networks.$stage.opts"]
        ::project::internal::report_clock_networks $opts $path $log_mode
        puts "report_clock_networks"
    }

    if {[::project::internal::get "report.clock_interaction.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.clock_interaction.$stage.opts"]
        ::project::internal::report_clock_interaction $opts $path $log_mode
        puts "report_clock_interaction"
    }

    if {[::project::internal::get "report.cdc.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.cdc.$stage.opts"]
        ::project::internal::report_cdc $opts $path $log_mode
        puts "report_cdc"
    }

    if {[::project::internal::get "report.power.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.power.$stage.opts"]
        ::project::internal::report_power $opts $path $log_mode
        puts "report_power"
    }

    if {[::project::internal::get "report.clock_utilization.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.clock_utilization.$stage.opts"]
        ::project::internal::report_clock_utilization $opts $path $log_mode
        puts "report_clock_utilization"
    }

    if {[::project::internal::get "report.qor_suggestions.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.qor_suggestions.$stage.opts"]
        ::project::internal::report_qor_suggestions $opts $path $log_mode
        puts "report_qor_suggestions"
    }

    if {[::project::internal::get "report.high_fanout_nets.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.high_fanout_nets.$stage.opts"]
        ::project::internal::report_high_fanout_nets $opts $path $log_mode
        puts "report_high_fanout_nets"
    }

    if {[::project::internal::get "report.qor_assessment.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.qor_assessment.$stage.opts"]
        ::project::internal::report_qor_assessment $opts $path $log_mode
        puts "report_qor_assessment"
    }

    if {[::project::internal::get "report.design_analysis.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.design_analysis.$stage.opts"]
        ::project::internal::report_design_analysis $opts $path $log_mode
        puts "report_design_analysis"
    }

    if {[::project::internal::get "report.dfx_summary.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.dfx_summary.$stage.opts"]
        ::project::internal::report_dfx_summary $opts $path $log_mode
        puts "report_dfx_summary"
    }

    if {[::project::internal::get "report.bus_skew.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.bus_skew.$stage.opts"]
        ::project::internal::report_bus_skew $opts $path $log_mode
        puts "report_bus_skew"
    }

    if {[::project::internal::get "report.datasheet.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.datasheet.$stage.opts"]
        ::project::internal::report_datasheet $opts $path $log_mode
        puts "report_datasheet"
    }

    if {[::project::internal::get "report.route_status.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.route_status.$stage.opts"]
        ::project::internal::report_route_status $opts $path $log_mode
        puts "report_route_status"
    }

    if {[::project::internal::get "report.io.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.io.$stage.opts"]
        ::project::internal::report_io $opts $path $log_mode
        puts "report_io"
    }

    if {[::project::internal::get "report.utilization.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.utilization.$stage.opts"]
        ::project::internal::report_utilization $opts $path $log_mode
        puts "report_utilization"
    }

    if {[::project::internal::get "report.control_sets.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.control_sets.$stage.opts"]
        ::project::internal::report_control_sets $opts $path $log_mode
        puts "report_control_sets"
    }

    if {[::project::internal::get "report.ssn.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.ssn.$stage.opts"]
        ::project::internal::report_ssn $opts $path $log_mode
        puts "report_ssn"
    }

    if {[::project::internal::get "report.ram_utilization.$stage.enable"] eq "true"} {
        set opts [::project::internal::get "report.ram_utilization.$stage.opts"]
        ::project::internal::report_ram_utilization $opts $path $log_mode
        puts "report_ram_utilization"
    }
}

proc ::project::internal::write_verilog {opts path filename {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.v" $filename]]

    ::write_verilog {*}$log_opts {*}$opts -force $path_file_name
}

proc ::project::internal::write_vhdl {opts path filename {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.vhd" $filename]]

    ::write_vhdl {*}$log_opts {*}$opts -force $path_file_name
}

proc ::project::internal::write_sdf {opts path filename {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.sdf" $filename]]

    ::write_sdf {*}$log_opts {*}$opts -force $path_file_name
}

proc ::project::internal::write_edif {opts path filename {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.edn" $filename]]

    ::write_edif {*}$log_opts {*}$opts -force $path_file_name
}

proc ::project::internal::write_xdc {opts path filename {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.xdc" $filename]]

    ::write_xdc {*}$log_opts {*}$opts -force $path_file_name
}

proc ::project::internal::write_waivers {opts path filename {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.xdc" $filename]]

    ::write_waivers {*}$log_opts {*}$opts -force $path_file_name
}

proc ::project::internal::write_schematic {opts path filename {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set log_opts [::common::log_option $log_mode]

    set path_file_name_pdf [file join $path [format "%s.pdf" $filename]]
    set path_file_name_svg [file join $path [format "%s.svg" $filename]]
    set path_file_name_txt [file join $path [format "%s.txt" $filename]]

    ::write_schematic {*}$log_opts {*}$opts -format pdf -force $path_file_name_pdf
    ::write_schematic {*}$log_opts {*}$opts -format svg -force $path_file_name_svg
    ::write_schematic {*}$log_opts {*}$opts -format native -force $path_file_name_txt
}

proc ::project::internal::report_methodology {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "methodology"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]
    set path_file_name_rpx [file join $path [format "%s.rpx" $filename]]

    ::report_methodology {*}$log_opts {*}$opts -rpx $path_file_name_rpx -file $path_file_name
}

proc ::project::internal::report_timing_summary {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "timing_summary"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]
    set path_file_name_rpx [file join $path [format "%s.rpx" $filename]]

    ::report_timing_summary {*}$log_opts {*}$opts -rpx $path_file_name_rpx -file $path_file_name
}

proc ::project::internal::report_drc {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "drc"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]
    set path_file_name_rpx [file join $path [format "%s.rpx" $filename]]

    ::report_drc {*}$log_opts {*}$opts -rpx $path_file_name_rpx -file $path_file_name
}

proc ::project::internal::report_timing {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "timing"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]
    set path_file_name_rpx [file join $path [format "%s.rpx" $filename]]

    ::report_timing {*}$log_opts {*}$opts -rpx $path_file_name_rpx -file $path_file_name
}

proc ::project::internal::report_clock_networks {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "clock_networks"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_clock_networks {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_clock_interaction {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "clock_interaction"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_clock_interaction {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_cdc {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "cdc"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_cdc {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_power {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "power"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]
    set path_file_name_rpx [file join $path [format "%s.rpx" $filename]]
    set path_file_name_xpe [file join $path [format "%s.xpe" $filename]]

    ::report_power {*}$log_opts {*}$opts -rpx $path_file_name_rpx \
        -xpe $path_file_name_xpe \
        -file $path_file_name
}

proc ::project::internal::report_clock_utilization {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "clock_utilization"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_clock_utilization {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_qor_suggestions {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "qor_suggestions"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_qor_suggestions {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_high_fanout_nets {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "high_fanout_nets"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_high_fanout_nets {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_qor_assessment {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "qor_assessment"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_qor_assessment {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_design_analysis {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "design_analysis"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_design_analysis {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_dfx_summary {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "dfx_summary"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_dfx_summary {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_bus_skew {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "bus_skew"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]
    set path_file_name_rpx [file join $path [format "%s.rpx" $filename]]

    ::report_bus_skew {*}$log_opts {*}$opts -rpx $path_file_name_rpx -file $path_file_name
}

proc ::project::internal::report_datasheet {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "datasheet"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]
    set path_file_name_rpx [file join $path [format "%s.rpx" $filename]]

    ::report_datasheet {*}$log_opts {*}$opts -rpx $path_file_name_rpx -file $path_file_name
}

proc ::project::internal::report_route_status {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "route_status"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_route_status {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_io {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "io"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_io {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_utilization {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "utilization"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_utilization {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_control_sets {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "control_sets"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_control_sets {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::report_ssn {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "ssn"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]
    set path_file_name_csv [file join $path [format "%s.csv" $filename]]
    set path_file_name_html [file join $path [format "%s.html" $filename]]

    ::report_ssn {*}$log_opts {*}$opts -format tct -file $path_file_name
    ::report_ssn {*}$log_opts {*}$opts -format csv -file $path_file_name_csv
    ::report_ssn {*}$log_opts {*}$opts -format html -file $path_file_name_html
}

proc ::project::internal::report_ram_utilization {opts path {log_mode "quiet"}} {
    ::project::internal::check_is_synthesized

    set filename "ram_utilization"

    set log_opts [::common::log_option $log_mode]

    set path_file_name [file join $path [format "%s.txt" $filename]]

    ::report_ram_utilization {*}$log_opts {*}$opts -file $path_file_name
}

proc ::project::internal::set_working_dir {} {
    variable resolved_db

    ::project::internal::check_is_resolved

    set prj_build_dir [::common::dict_get_required $resolved_db project.project_build_path \
        "Error: The project build path is not specified in resolve step!!!"]

    if {![file exists $prj_build_dir]} {
        error "Error: The project build path does not exists!!! : $prj_build_dir"
    }

    set init_path [::common::set_working_dir $prj_build_dir]

    puts "Set the current working directory: $prj_build_dir"

    return $init_path
}

proc ::project::internal::is_loaded {} {
    variable loaded

    return $loaded
}

proc ::project::internal::is_resolved {} {
    variable resolved

    return $resolved
}

proc ::project::internal::is_prepared {} {
    variable prepared

    return $prepared
}

proc ::project::internal::is_designed {} {
    variable designed

    return $designed
}

proc ::project::internal::is_synthesized {} {
    variable synthesized

    return $synthesized
}

proc ::project::internal::is_implemented {} {
    variable implemented

    return $implemented
}

proc ::project::internal::is_bitstream_generated {} {
    variable bitstream_generated

    return $bitstream_generated
}

proc ::project::internal::is_xsa_generated {} {
    variable xsa_generated

    return $xsa_generated
}

proc ::project::internal::check_is_loaded {} {
    if {![::project::internal::is_loaded]} {
        error "No project loaded."
    }
}

proc ::project::internal::check_is_resolved {} {
    ::project::internal::check_is_loaded

    if {![::project::internal::is_resolved]} {
        error "Project has not been resolved."
    }
}

proc ::project::internal::check_is_prepared {} {
    ::project::internal::check_is_resolved

    if {![::project::internal::is_prepared]} {
        error "Project has not been prepared."
    }
}

proc ::project::internal::check_is_designed {} {
    ::project::internal::check_is_prepared

    if {![::project::internal::is_designed]} {
        error "Project has not been designed."
    }
}

proc ::project::internal::check_is_synthesized {} {
    ::project::internal::check_is_designed

    if {![::project::internal::is_synthesized]} {
        error "Project has not been synthesized."
    }
}

proc ::project::internal::check_is_implemented {} {
    ::project::internal::check_is_synthesized

    if {![::project::internal::is_implemented]} {
        error "Project has not been implemented."
    }
}

proc ::project::internal::check_is_bitstream_generated {} {
    ::project::internal::check_is_implemented

    if {![::project::internal::is_bitstream_generated]} {
        error "The bitstream has not been generated."
    }
}

proc ::project::internal::check_is_xsa_generated {} {
    ::project::internal::check_is_bitstream_generated

    if {![::project::internal::is_xsa_generated]} {
        error "The XSA has not been generated."
    }
}

proc ::project::internal::get {path} {
    variable resolved_db

    if {![::project::internal::is_resolved]} {
        error "The project is not resolved."
    }

    return [::common::dict_get_required $resolved_db $path \
        "The '$path' does not exists in the project database."]
}

proc ::project::internal::get_default {path default} {
    variable resolved_db

    if {![::project::internal::is_resolved]} {
        error "The project is not resolved."
    }

    return [::common::dict_get_default $resolved_db $path $default]
}

proc ::project::internal::src_path {} {
    return [::project::internal::get project.project_src_path]
}

proc ::project::internal::build_path {} {
    return [::project::internal::get project.project_build_path]
}

proc ::project::internal::name {} {
    return [::project::internal::get project.name]
}

proc ::project::internal::version {} {
    return [::project::internal::get project.version]
}

proc ::project::internal::language {} {
    return [::project::internal::get project.language]
}

proc ::project::internal::target {} {
    return [::project::internal::get target]
}

proc ::project::internal::resources {} {
    return [::project::internal::get resources]
}

proc ::project::internal::top {} {
    return [::project::internal::get resources.top]
}

proc ::project::internal::configuration {} {
    return [::project::internal::get configuration]
}

proc ::project::internal::simulation {} {
    return [::project::internal::get simulation]
}

proc ::project::internal::_split_path {path} {
    if {$path eq ""} {
        return {}
    }

    return [split $path "."]
}
