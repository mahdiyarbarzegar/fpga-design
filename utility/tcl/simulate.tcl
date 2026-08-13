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

proc ::simulate::compile {module_path sim_mode} {
    variable internal::SIM_PATH

    set module_path [file normalize $module_path]

    try {
        set init_path [::common::set_working_dir $SIM_PATH]
        ::simulate::internal::compile $module_path $sim_mode
    } on error {result options} {
        ::simulate::internal::close_prj
        puts stderr "Operation failed:"
        puts stderr $result
        puts "Error occured during compilation."
    } finally {
        ::common::set_working_dir $init_path
    }
}

proc ::simulate::internal::compile {module_path sim_mode} {
    variable compile_db
    variable SIM_PATH

    set compile_db {}
    dict lappend compile_db includes
    dict lappend compile_db files

    ::module::scan
    ::module::load $module_path
    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    set consume [dict get [::module::simulation $sim_mode] consume]
    set variant [dict get [::module::simulation $sim_mode] variant]
    set opts [dict get [::module::simulation $sim_mode] xvlog_opts]
    if {$opts eq "null"} {
        set opts ""
    }

    set deps [::dependency::resolve $module_path $consume $variant]

    foreach node $deps {
        ::simulate::internal::compile_collect $node
    }

    ::simulate::internal::add_sim_files $module_path $sim_mode

    ::simulate::internal::compile_all $opts
}

proc ::simulate::elaborate {module_path sim_mode} {
    variable internal::SIM_PATH

    set module_path [file normalize $module_path]

    try {
        set init_path [::common::set_working_dir $SIM_PATH]
        ::simulate::internal::elaborate $module_path $sim_mode
    } on error {result options} {
        ::simulate::internal::close_prj
        puts stderr "Operation failed:"
        puts stderr $result
        puts "Error occured during elaboration."
    } finally {
        ::common::set_working_dir $init_path
    }
}

proc ::simulate::internal::elaborate {module_path sim_mode} {
    variable project_root_path
    variable SIM_PATH
    variable LIB_NAME
    variable LIB_PATH
    variable ELAB_PATH

    ::module::load $module_path
    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    set elab_dir [file join $ELAB_PATH [::module::name] $sim_mode]
    file mkdir $elab_dir

    set sim_cfg [::module::simulation $sim_mode]
    set top [dict get $sim_cfg top]
    set snapshot [dict get $sim_cfg snapshot]
    set timescale [dict get $sim_cfg timescale]

    set opts [dict get $sim_cfg xelab_opts]
    if {$opts eq "null"} {
        set opts ""
    }

    set includes {}
    foreach inc [::module::get include] {
        if {$inc ne "null"} {
            lappend includes \
                -i [file join $project_root_path $module_path $inc]
        }
    }

    set cmd [list xelab \
        -L ${LIB_NAME}=${LIB_PATH} \
        {*}$includes \
        -timescale $timescale \
        -s $snapshot \
        --debug all \
        {*}$opts \
        $LIB_NAME.$top]

    common::run $cmd $elab_dir
}

proc ::simulate::simulate {module_path sim_mode} {
    variable internal::SIM_PATH

    set module_path [file normalize $module_path]

    try {
        set init_path [::common::set_working_dir $SIM_PATH]
        ::simulate::internal::simulate $module_path $sim_mode
    } on error {result options} {
        ::simulate::internal::close_prj
        puts stderr "Operation failed:"
        puts stderr $result
        puts "Error occured during simulation."
    } finally {
        ::common::set_working_dir $init_path
    }
}

proc ::simulate::internal::simulate {module_path sim_mode} {
    variable project_root_path
    variable ELAB_PATH
    variable SIM_PATH

    ::module::load $module_path

    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    set sim_cfg [::module::simulation $sim_mode]

    set snapshot [dict get $sim_cfg snapshot]
    set tclbatch [dict get $sim_cfg tclbatch]
    set waveform [dict get $sim_cfg waveform]
    set opts [dict get $sim_cfg xsim_opts]

    if {$opts eq "null"} {
        set opts {}
    }

    set elab_dir [file join $ELAB_PATH [::module::name] $sim_mode]

    if {![file isdirectory $elab_dir]} {
        error "Elaboration directory does not exist: $elab_dir"
    }

    switch -- $sim_mode {
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
            error "Unsupported simulation mode: $sim_mode"
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
    puts "  Mode:      $sim_mode"
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
            puts "$f"
            dict lappend compile_db files \
                [file join $IP_PATH $ip_dir $variant_name $f]
        }

        foreach f [::ip::get_xml_field simulation.wrapper] {
            puts "$f"
            dict lappend compile_db files \
                [file join $IP_PATH $ip_dir $variant_name $f]
        }
    }
}

proc ::simulate::internal::add_sim_files {module_path sim_mode} {
    variable compile_db
    variable project_root_path

    set sim_cfg [::module::simulation $sim_mode]

    foreach f [dict get $sim_cfg files] {
        dict lappend compile_db files \
            [file join $project_root_path $module_path $f]
    }
}

proc ::simulate::internal::compile_all {{opts ""}} {
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
            ".vhd" {
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
        lappend opts -sv
    }

    if {$enable_vlog} {
        set cmd [list xvlog \
            -L ${LIB_NAME}=${LIB_PATH} \
            -work ${LIB_NAME}=${LIB_PATH} \
            {*}$includes \
            {*}$opts \
            {*}$verilog_files]

        common::run $cmd
    }

    if {$enable_vhdl} {
        set cmd [list xvhdl \
            -L ${LIB_NAME}=${LIB_PATH} \
            -work ${LIB_NAME}=${LIB_PATH} \
            {*}$opts \
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
