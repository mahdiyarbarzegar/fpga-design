namespace eval ::package_append {

}

proc ::package_append::do_package_append {ctx} {
    set core [dict get $ctx core]
    set module_path [dict get $ctx module_path]
    set project_root [dict get $ctx project_root]
    set quiet [dict get $ctx quiet]

    ::ipx::infer_bus_interfaces {*}$quiet $core

    #
    # ipx::add_bus_interface irq $core
    #
    # set_property abstraction_type_vlnv \
    #     xilinx.com:signal:interrupt_rtl:1.0 \
    #     [ipx::get_bus_interfaces irq -of_objects $core]
    #
    # set_property interface_mode master \
    #     [ipx::get_bus_interfaces irq -of_objects $core]
    #
}
