namespace eval ::module {}

namespace eval ::module::internal {
    variable cfg {}
    variable module_path ""
    variable database {}
    variable loaded 0
    variable project_root_path $::common::ROOT_DIR
}

package require json

proc ::module::scan {} {
    variable internal::database
    variable internal::project_root_path

    set database {}

    foreach type {hdl venip lib} {
        set root [file join $project_root_path srcs $type]

        if {![file exists $root]} {
            continue
        }

        foreach dir [glob -nocomplain -directory $root *] {
            if {![file isdirectory $dir]} {
                continue
            }

            if {![file exists [file join $dir module.yaml]]} {
                continue
            }

            set name [file tail $dir]

            if {[dict exists $database $name]} {
                error "Duplicate module name: $name"
            }

            dict set database $name \
                [dict create \
                    name $name \
                    type $type \
                    path [file normalize $dir]]
        }
    }
}

proc ::module::find {name} {
    variable internal::database

    if {![dict exists $database $name]} {
        error "Module '$name' not found."
    }

    return [dict get $database $name path]
}

proc ::module::exists {name} {
    variable internal::database

    return [dict exists $database $name]
}

proc ::module::type {name} {
    variable internal::database

    if {![dict exists $database $name]} {
        return ""
    }

    return [dict get $database $name type]
}

proc ::module::database {} {
    variable internal::database

    return $database
}

proc ::module::load {path} {
    variable internal::cfg
    variable internal::module_path
    variable internal::loaded

    set loaded 0

    set module_path [file normalize $path]

    set cfg [::yaml::load_yaml $module_path]

    set loaded 1

    return
}

proc ::module::is_loaded {} {
    variable internal::loaded

    return $loaded
}

proc ::module::get {path} {
    variable internal::cfg

    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    set keys [::module::internal::split_path $path]

    return [dict get $cfg {*}$keys]
}

proc ::module::get_default {path default} {
    variable internal::cfg

    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    set keys [::module::internal::split_path $path]

    if {[dict exists $cfg {*}$keys]} {
        return [dict get $cfg {*}$keys]
    }

    return $default
}

proc ::module::variants {} {
    return [dict keys [::module::get variants]]
}

proc ::module::variant_exists {variant} {
    variable internal::cfg

    return [dict exists $cfg variants $variant]
}

proc ::module::variant_get {variant path} {
    variable internal::cfg

    if {![::module::variant_exists $variant]} {
        error "Variant \"$variant\" does not exist."
    }

    set keys [::module::internal::split_path $path]

    return [dict get $cfg variants $variant {*}$keys]
}

proc ::module::variant_get_default {variant path default} {
    variable internal::cfg

    if {![::module::variant_exists $variant]} {
        error "Variant \"$variant\" does not exist."
    }

    set keys [::module::internal::split_path $path]

    if {[dict exists $cfg variants $variant {*}$keys]} {
        return [dict get $cfg variants $variant {*}$keys]
    }

    return $default
}

proc ::module::validate_variant {variant} {
    if {![::module::variant_exists $variant]} {
        set variants [dict keys [::module::get variants]]

        error "Variant '$variant' does not exist.\n\
           Available variants:\n  [join $variants "\n  "]"
    }
}

proc ::module::vlnv {} {
    return [::module::get ip.vlnv]
}

proc ::module::vendor {} {
    return [::module::get ip.vendor]
}

proc ::module::library {} {
    return [::module::get ip.library]
}

proc ::module::name {} {
    return [::module::get ip.name]
}

proc ::module::version {} {
    return [::module::get ip.version]
}

proc ::module::taxonomy {} {
    return [::module::get ip.taxonomy]
}

proc ::module::type {} {
    return [::module::get type]
}

proc ::module::description {} {
    return [::module::get ip.description]
}

proc ::module::display_name {} {
    return [::module::get ip.display_name]
}

proc ::module::simulation {sim_mode} {
    return [::module::get simulation.$sim_mode]
}

proc ::module::dump {} {
    variable internal::cfg

    if {![::module::is_loaded]} {
        error "No module loaded."
    }

    return $cfg
}

proc ::module::reload {} {
    variable internal::module_path

    if {$module_path eq ""} {
        error "No module has been loaded."
    }

    ::module::load $module_path
}

proc ::module::path {} {
    variable internal::module_path

    return $module_path
}

proc ::module::internal::split_path {path} {
    if {$path eq ""} {
        return {}
    }

    return [split $path "."]
}
