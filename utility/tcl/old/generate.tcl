namespace eval ::generate {
    variable IP_PATH $::common::IP_PATH
    variable PACKAGE_PATH $::common::PACKAGE_PATH
}

proc generate::do_generate {part_number module_path variant {be_quiet ""}} {
    module::scan
    module::load $module_path
    module::validate_variant $variant

    set deps [dependency::resolve $module_path "ip" $variant]

    foreach node $deps {
        generate::_generate_one $part_number $node $be_quiet
    }
}

proc generate::_generate_one {part_number node {be_quiet ""}} {
    variable IP_PATH
    variable PACKAGE_PATH

    set quiet {}
    if {$be_quiet eq "-quiet"} {
        lappend quiet -quiet
    }

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

    set_part {*}$quiet $part_number

    set_property ip_repo_paths [list $PACKAGE_PATH] [current_project]

    update_ip_catalog {*}$quiet

    create_ip -vlnv $ip_vlnv -module_name $variant_name -dir $ip_dir_path -force {*}$quiet

    set ip_obj [get_ips $variant_name]
    set params [module::variant_get $dep_variant parameters]

    if {$params ne "null"} {

        set_property -dict $params $ip_obj
    }

    generate_target -force {*}$quiet all $ip_obj

    get_files -compile_order sources -used_in simulation

    close_project
}
