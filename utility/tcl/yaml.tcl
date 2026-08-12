namespace eval ::yaml {
    variable project_root_path $::common::ROOT_DIR
    variable parser_script [file join $project_root_path "utility/py/yaml_parser.py"]
}

package require json

proc ::yaml::load_yaml {path} {
    variable parser_script

    set path [file normalize $path]

    if {[file isdirectory $path]} {
        set candidates {
            module.yaml
            project.yaml
        }

        set yaml_file ""

        foreach filename $candidates {
            set candidate [file join $path $filename]

            if {[file exists $candidate]} {
                if {$yaml_file ne ""} {
                    error "Multiple YAML configuration files found in:\n$path"
                }

                set yaml_file $candidate
            }
        }

        if {$yaml_file eq ""} {
            error "No module.yaml or project.yaml found in:\n$path"
        }
    } elseif {[file isfile $path]} {
        set filename [file tail $path]

        if {$filename ni {module.yaml project.yaml}} {
            error "Unsupported YAML file:\n$path\n\nExpected module.yaml or project.yaml"
        }

        set yaml_file $path
    } else {
        error "Path does not exist:\n$path"
    }

    if {
        [catch {
            exec python $parser_script $yaml_file
        } json_string]
    } {
        error "Failed to parse YAML file:\n$yaml_file\n\n$json_string"
    }

    if {
        [catch {
            ::json::json2dict $json_string
        } cfg]
    } {
        error "Invalid JSON returned from yaml_parser.py:\n$yaml_file"
    }

    return $cfg
}
