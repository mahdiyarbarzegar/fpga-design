namespace eval ::dependency {}

namespace eval ::dependency::internal {
    variable visited
    variable visiting
    variable ordered
}

proc ::dependency::resolve {module_path {consume "null"} {variant "null"} {sim_dep "false"} {sim_mode "batch"}} {
    variable internal::visited
    variable internal::visiting
    variable internal::ordered

    array unset visited
    array unset visiting
    set ordered {}

    ::dependency::internal::visit $module_path $consume $variant $sim_dep $sim_mode

    return $ordered
}

proc ::dependency::internal::visit {module_path {consume "null"} {variant "null"} {sim_dep "false"} {sim_mode "batch"}} {
    variable visited
    variable visiting
    variable ordered

    set key "${module_path}::${consume}::${variant}"

    if {[info exists visited($key)]} {
        return
    }

    if {[info exists visiting($key)]} {
        error "Dependency cycle detected at $key"
    }

    set visiting($key) 1

    ::module::load $module_path

    if {![::module::is_loaded]} {
        error "Cannot load module $module_path"
    }

    if {$sim_dep eq "true"} {
        set deps [::module::get_default "simulation.$sim_mode.dependencies" {}]
    } else {
        set deps [::module::get_default dependencies {}]
    }

    set deps_lib [::common::dict_get_default $deps "lib" ""]
    set deps_module [::common::dict_get_default $deps "module" ""]

    foreach libdep $deps_lib {
        set dep_path [::module::find $libdep]

        ::module::load $dep_path

        if {![::module::is_loaded]} {
            error "Cannot load module $module_path"
        }

        ::dependency::internal::visit $dep_path "rtl"
    }

    foreach dep $deps_module {
        set dep_module [dict get $dep "name"]
        set dep_consume [dict get $dep "consume"]
        set dep_variant [dict get $dep "variant"]

        if {$dep_module eq "null" || $dep_consume eq "null"} {
            continue
        }

        if {$dep_consume ne "rtl" && $dep_consume ne "ip"} {
            error "The dependency type is wrong: $dep_consume!!!"
        }

        set dep_path [::module::find $dep_module]

        ::module::load $dep_path

        if {![::module::is_loaded]} {
            error "Cannot load module $module_path"
        }

        if {$dep_consume eq "ip"} {
            ::module::validate_variant $dep_variant
        }

        ::dependency::internal::visit $dep_path $dep_consume $dep_variant
    }

    unset visiting($key)

    set visited($key) 1

    if {$sim_dep eq "false"} {
        lappend ordered \
            [dict create \
                path $module_path \
                consume $consume \
                variant $variant]
    }
}
