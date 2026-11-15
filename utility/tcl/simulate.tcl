namespace eval ::simulate {}

namespace eval ::simulate::internal {
    variable project_root_path $::common::ROOT_DIR
    variable SIM_PATH $::common::SIM_PATH
    variable ELAB_PATH $::common::ELAB_PATH
    variable IP_PATH $::common::IP_PATH
    variable LIB_NAME $::common::LIB_NAME
    variable LIB_PATH $::common::LIB_PATH
    variable compile_db {}
}

proc ::simulate::compile {module_path sim_profile {sim_mode "behave"}} {
    variable internal::SIM_PATH

    set module_path [file normalize $module_path]

    try {
        set init_path [::common::set_working_dir $SIM_PATH]
        ::simulate::internal::compile $module_path $sim_profile $sim_mode
    } on error {result options} {
        ::simulate::internal::close_prj
        puts stderr "Operation failed:"
        puts stderr $result
        puts "Error occured during compilation."
    } finally {
        ::common::set_working_dir $init_path
    }
}

proc ::simulate::internal::compile {module_path sim_profile sim_mode} {
    variable compile_db
    variable SIM_PATH
    variable IP_PATH

    if {$sim_mode ni {"behave" "post_synth"}} {
        error "The simulation mode is wrong! sim_mode: $sim_mode"
    }

    # Initialize compilation database
    set compile_db {}
    dict lappend compile_db includes
    dict lappend compile_db files

    # Load module configuration
    ::module::scan
    ::module::load $module_path
    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    set sim_cfg [::module::simulation $sim_profile]

    set top [dict get $sim_cfg top]
    set consume [dict get $sim_cfg consume]
    set variant [dict get $sim_cfg variant]
    set xvlog_opts [dict get $sim_cfg xvlog_opts]
    set xvhdl_opts [dict get $sim_cfg xvhdl_opts]

    if {$top eq "null"} {
        error "The simulation profile $sim_profile does not have any top module"
    }

    if {$xvlog_opts eq "null"} {
        set xvlog_opts {}
    }

    if {$xvhdl_opts eq "null"} {
        set xvhdl_opts {}
    }

    # Get simulation testbench files
    set sim_files [::simulate::internal::get_sim_files $module_path $sim_profile]

    # Mode-specific dependency and source preparation
    switch -- $sim_mode {
        behave {
            set deps [::dependency::resolve $module_path $consume $variant]
            set sim_deps [::dependency::resolve \
                $module_path $consume $variant "true" $sim_profile]

            set all_deps [concat $deps $sim_deps]
        }

        post_synth {
            if {$consume ne "ip"} {
                error "For post-synthesis simulation, the consume type should be 'ip'"
            }

            if {$variant eq "null"} {
                error "For post-synthesis simulation, the variant param should not be null"
            }

            # Get generated timing netlist
            set ip_name [::module::name]
            set ip_version [::module::version]
            set variant_name [::module::variant_get $variant name]

            set ip_dir "${ip_name}_v${ip_version}"
            set ip_dir_path [file join $IP_PATH $ip_dir]
            set variant_dir_path [file join $ip_dir_path $variant_name]

            set sim_netlist_file [file join \
                $variant_dir_path "${variant_name}_timesim_netlist.v"]

            if {![file exists $sim_netlist_file]} {
                error "Post-synthesis timing netlist not found: $sim_netlist_file"
            }

            dict lappend compile_db files $sim_netlist_file

            # Resolve simulation dependencies only
            set sim_deps [::dependency::resolve \
                $module_path $consume $variant "true" $sim_profile]

            set all_deps $sim_deps
        }
    }

    # Collect dependency source files
    foreach node $all_deps {
        ::simulate::internal::compile_collect $node
    }

    # Reload root module after dependency collection
    ::module::load $module_path
    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    # Add testbench files
    dict lappend compile_db files $sim_files

    # Compile all collected sources
    ::simulate::internal::compile_all $xvlog_opts $xvhdl_opts $sim_mode
}

proc ::simulate::elaborate {module_path sim_profile {sim_mode "behave"}} {
    variable internal::SIM_PATH

    set module_path [file normalize $module_path]

    try {
        set init_path [::common::set_working_dir $SIM_PATH]
        ::simulate::internal::elaborate $module_path $sim_profile $sim_mode
    } on error {result options} {
        ::simulate::internal::close_prj
        puts stderr "Operation failed:"
        puts stderr $result
        puts "Error occured during elaboration."
    } finally {
        ::common::set_working_dir $init_path
    }
}

proc ::simulate::internal::elaborate {module_path sim_profile sim_mode} {
    variable project_root_path
    variable SIM_PATH
    variable LIB_NAME
    variable LIB_PATH
    variable ELAB_PATH

    if {$sim_mode ni {"behave" "post_synth"}} {
        error "The simulation mode is wrong! sim_mode: $sim_mode"
    }

    ::module::load $module_path
    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    set elab_dir [file join $ELAB_PATH $sim_mode [::module::name] $sim_profile]
    set lib_dir [file join $LIB_PATH $sim_mode]
    file mkdir $elab_dir

    set sim_cfg [::module::simulation $sim_profile]

    set top [dict get $sim_cfg top]
    set snapshot "${sim_profile}_${sim_mode}"
    set timescale [dict get $sim_cfg timescale]
    set parameters [dict get $sim_cfg parameters]

    set opts [dict get $sim_cfg xelab_opts]
    if {$opts eq "null"} {
        set opts {}
    }

    set includes {}
    foreach inc [::module::get include] {
        if {$inc ne "null"} {
            lappend includes \
                -i [file join $project_root_path $module_path $inc]
        }
    }

    set generic_top {}
    foreach pair $parameters {
        if {$pair ne "null"} {
            lassign $pair param value
            lappend generic_top -generic_top "${param}=${value}"
        }
    }

    set mode_opts {}

    switch -- $sim_mode {
        behave {
            lappend mode_opts \
                -L unisims_ver
        }

        post_synth {
            lappend mode_opts \
                --maxdelay \
                -L simprims_ver \
                -L secureip \
                -transport_int_delays \
                -pulse_r 0 \
                -pulse_int_r 0 \
                -pulse_e 0 \
                -pulse_int_e 0
        }
    }

    set cmd [list xelab \
        --incr \
        --debug typical \
        --relax \
        --mt 8 \
        -L ${LIB_NAME}=${lib_dir} \
        {*}$mode_opts \
        {*}$includes \
        -timescale $timescale \
        --snapshot $snapshot \
        {*}$generic_top \
        {*}$opts \
        ${LIB_NAME}.${top}]

    # Add Xilinx global simulation module for post-synthesis simulation
    if {$sim_mode eq "post_synth"} {
        lappend cmd "${LIB_NAME}.glbl"
    }

    common::run $cmd $elab_dir
}

proc ::simulate::simulate {module_path sim_profile {sim_mode "behave"}} {
    variable internal::SIM_PATH

    set module_path [file normalize $module_path]

    try {
        set init_path [::common::set_working_dir $SIM_PATH]
        ::simulate::internal::simulate $module_path $sim_profile $sim_mode
    } on error {result options} {
        ::simulate::internal::close_prj
        puts stderr "Operation failed:"
        puts stderr $result
        puts "Error occured during simulation."
    } finally {
        ::common::set_working_dir $init_path
    }
}

proc ::simulate::internal::simulate {module_path sim_profile sim_mode} {
    variable project_root_path
    variable ELAB_PATH
    variable SIM_PATH

    ::module::load $module_path

    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    if {$sim_mode ni {"behave" "post_synth"}} {
        error "The simulation mode is wrong! sim_mode: $sim_mode"
    }

    set sim_cfg [::module::simulation $sim_profile]

    set snapshot "${sim_profile}_${sim_mode}"
    set sim_type [dict get $sim_cfg type]
    set tclbatch [dict get $sim_cfg tclbatch]
    set waveform [dict get $sim_cfg waveform]
    set opts [dict get $sim_cfg xsim_opts]

    if {$opts eq "null"} {
        set opts {}
    }

    set elab_dir [file join $ELAB_PATH $sim_mode [::module::name] $sim_profile]

    if {![file isdirectory $elab_dir]} {
        error "Elaboration directory does not exist: $elab_dir"
    }

    switch -- $sim_type {
        batch {
            lappend opts --runall
        }

        gui {
            lappend opts --gui

            if {$tclbatch ne "null" && $tclbatch ne ""} {
                set path [file join $project_root_path $module_path $tclbatch]

                if {![file exists $path]} {
                    error "Simulation Tcl file does not exist: $path"
                }

                lappend opts --tclbatch $path
            }

            if {$waveform ne "null" && $waveform ne ""} {
                set path [file join $project_root_path $module_path $waveform]

                if {![file exists $path]} {
                    error "Waveform configuration does not exist: $path"
                }

                lappend opts --view $path
            }
        }

        default {
            error "Unsupported simulation mode: $sim_type"
        }
    }

    set cmd [list xsim \
        $snapshot \
        --xsimdir $elab_dir \
        --nolog \
        {*}$opts]

    puts ""
    puts "Simulation"
    puts "  Module:    [::module::name]"
    puts "  Snapshot:  $snapshot"
    puts "  Type:      $sim_type"
    puts "  Tcl Batch: $tclbatch"
    puts "  Waveform:  $waveform"
    puts ""

    common::run $cmd $elab_dir
}

proc ::simulate::internal::compile_collect {node} {
    variable compile_db
    variable project_root_path
    variable IP_PATH

    set module_path [dict get $node path]
    set consume [dict get $node consume]
    set variant [dict get $node variant]

    ::module::load $module_path
    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    foreach inc [::module::get include] {
        if {$inc ne "null"} {
            dict lappend compile_db includes \
                [file join $project_root_path $module_path $inc]
        }
    }

    set module_type [::module::get type]

    if {$module_type eq "lib"} {
        foreach f [::module::get src] {
            dict lappend compile_db files \
                [file join $project_root_path $module_path $f]
        }
    } else {
        if {$consume eq "rtl"} {
            foreach f [::module::get rtl] {
                dict lappend compile_db files \
                    [file join $project_root_path $module_path $f]
            }
        } elseif {$consume eq "ip"} {
            set module_name [::module::name]
            set module_version [::module::version]
            set variant_name [::module::variant_get $variant name]

            set ip_dir "${module_name}_v${module_version}"

            set xml_fileset [file join \
                $IP_PATH $ip_dir $variant_name "${variant_name}.xml"]

            ::ip::load_xml_fileset $xml_fileset

            foreach f [::ip::get_xml_field simulation.behavioral] {
                dict lappend compile_db files \
                    [file join $IP_PATH $ip_dir $variant_name $f]
            }

            foreach f [::ip::get_xml_field simulation.wrapper] {
                dict lappend compile_db files \
                    [file join $IP_PATH $ip_dir $variant_name $f]
            }
        }
    }
}

proc ::simulate::internal::get_sim_files {module_path sim_profile} {
    variable project_root_path

    set sim_files {}

    set sim_cfg [::module::simulation $sim_profile]

    foreach f [dict get $sim_cfg files] {
        lappend sim_files [file join $project_root_path $module_path $f]
    }

    return $sim_files
}

proc ::simulate::internal::compile_all {xvlog_opts xvhdl_opts sim_mode} {
    variable LIB_NAME
    variable LIB_PATH
    variable compile_db

    set includes {}
    set verilog_files {}
    set vhdl_files {}
    set enable_vlog 0
    set enable_sv 0
    set enable_vhdl 0

    foreach inc [lsort -unique [dict get $compile_db includes]] {
        lappend includes -i $inc
    }

    foreach f [dict get $compile_db files] {
        switch -- [file extension $f] {
            ".v" {
                puts [format "Adding %-20s %s" "Verilog" [file tail $f]]
                set enable_vlog 1
                lappend verilog_files $f
            }
            ".sv" {
                puts [format "Adding %-20s %s" "SystemVerilog" [file tail $f]]
                set enable_vlog 1
                set enable_sv 1
                lappend verilog_files $f
            }
            ".vhd" - ".vhdl" {
                puts [format "Adding %-20s %s" "VHDL" [file tail $f]]
                set enable_vhdl 1
                lappend vhdl_files $f
            }
            default {
                error "Unsupported HDL file: $f"
            }
        }
    }

    if {$enable_sv} {
        lappend xvlog_opts -sv
    }

    set lib_dir [file join $LIB_PATH $sim_mode]

    if {$enable_vlog} {
        set cmd [list xvlog \
            -L ${LIB_NAME}=${lib_dir} \
            -work ${LIB_NAME}=${lib_dir} \
            --incr \
            {*}$includes \
            {*}$xvlog_opts \
            {*}$verilog_files]

        common::run $cmd
    }

    if {$enable_vhdl} {
        set cmd [list xvhdl \
            -L ${LIB_NAME}=${lib_dir} \
            -work ${LIB_NAME}=${lib_dir} \
            --incr \
            -2019 \
            {*}$xvhdl_opts \
            {*}$vhdl_files]

        common::run $cmd
    }
}

proc ::simulate::internal::close_prj {} {
    if {[info commands current_project] ne ""} {
        if {[llength [current_project -quiet]] > 0} {
            close_project -quiet
        }
    }
}
