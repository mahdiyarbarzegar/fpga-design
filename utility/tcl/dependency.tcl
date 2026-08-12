namespace eval ::dependency {}

namespace eval ::dependency::internal {
    variable visited
    variable visiting
    variable ordered
}

proc ::dependency::resolve {module_path {consume "null"} {variant "null"}} {
    variable internal::visited
    variable internal::visiting
    variable internal::ordered

    array unset visited
    array unset visiting
    set ordered {}

    ::dependency::internal::visit $module_path $consume $variant

    return $ordered
}

proc ::dependency::internal::visit {module_path {consume "null"} {variant "null"}} {
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

    set deps [::module::get_default dependencies {}]

    foreach dep $deps {
        set dep_module [dict get $dep "module"]
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

    lappend ordered \
        [dict create \
            path $module_path \
            consume $consume \
            variant $variant]
}
