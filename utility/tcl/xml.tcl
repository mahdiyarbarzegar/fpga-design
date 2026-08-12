namespace eval ::xml {
    variable document ""
}

package require tdom

proc ::xml::load_xml {file_path} {
    variable document

    if {![file exists $file_path]} {
        error "XML file does not exist: $file_path"
    }

    if {$document ne ""} {
        catch {$document delete}
        set document ""
    }

    set fp [open $file_path r]
    set data [read $fp]
    close $fp

    set document [dom parse $data]

    return $document
}

proc ::xml::root {} {
    variable document

    if {$document eq ""} {
        error "No XML document loaded."
    }

    return [$document documentElement]
}
