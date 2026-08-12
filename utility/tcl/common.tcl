namespace eval ::common {
    variable ROOT_DIR
    variable BUILD_PATH
    variable PRJ_SRC_PATH
    variable PRJ_BUILD_PATH
    variable SRC_PATH
    variable HDL_PATH
    variable IP_PATH
    variable SIM_PATH
    variable LIB_PATH
    variable ELAB_PATH
    variable PACKAGE_PATH
    variable DOCS_PATH
    variable PROPS_PATH
    variable LIB_NAME
}

set ::common::LIB_NAME "userlib"

set ::common::SCRIPT_DIR [file dirname [file normalize [info script]]]
set ::common::ROOT_DIR [file normalize [file join $::common::SCRIPT_DIR ../..]]
set ::common::BUILD_PATH [file join $::common::ROOT_DIR build]
set ::common::PRJ_SRC_PATH [file join $::common::ROOT_DIR prjs]
set ::common::PRJ_BUILD_PATH [file join $::common::BUILD_PATH "prj"]
set ::common::SRC_PATH [file join $::common::ROOT_DIR srcs]
set ::common::HDL_PATH [file join $::common::SRC_PATH hdl]
set ::common::SIM_PATH [file join $::common::BUILD_PATH "sim"]
set ::common::IP_PATH [file join $::common::BUILD_PATH "ip"]
set ::common::LIB_PATH [file join $::common::SIM_PATH $::common::LIB_NAME]
set ::common::ELAB_PATH [file join $::common::SIM_PATH "elab"]
set ::common::PACKAGE_PATH [file join $::common::BUILD_PATH "pkg"]
set ::common::DOCS_PATH [file join $::common::BUILD_PATH "docs"]
set ::common::PROPS_PATH [file join $::common::DOCS_PATH "props"]

proc ::common::dict_get_default {dict_data key_path default_value} {
    set keys [split $key_path "."]

    if {![dict exists $dict_data {*}$keys]} {
        return $default_value
    }

    set value [dict get $dict_data {*}$keys]

    if {$value eq "null"} {
        return $default_value
    }

    return $value
}


proc ::common::dict_get_required {dict_data key_path error_message} {
    set keys [split $key_path "."]

    if {![dict exists $dict_data {*}$keys]} {
        error $error_message
    }

    set value [dict get $dict_data {*}$keys]

    if {$value eq "null"} {
        error $error_message
    }

    return $value
}

proc ::common::run {cmd {work_dir ""}} {
    set old_dir [pwd]

    if {$work_dir ne ""} {
        cd $work_dir
    }

    puts "Running:"
    puts "  [join $cmd { }]"

    set result [catch {
        exec {*}$cmd 2>@1
    } output]

    cd $old_dir

    puts $output

    if {$result} {
        error $output
    }

    return $output
}

proc ::common::log_option {{mode "quiet"}} {
    switch -- $mode {
        quiet {
            return {-quiet}
        }
        normal {
            return {}
        }
        verbose {
            return {-verbose}
        }
        default {
            error "Invalid log mode '$mode'. Expected: quiet, normal, or verbose."
        }
    }
}

proc ::common::set_working_dir {path} {
    set last_path [pwd]

    cd $path

    return $last_path
}
