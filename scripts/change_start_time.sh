#! /bin/sh

# This is a shell library that is meant to be sourced, not executed.

change_start_time() {
    set -xue

    local forecast_dir="$1" # path to exp forecast directory where original mpas ran
    local mpas_app="$2" # full path to mpas executable (eg. /path/to/exec/atmosphere_model)
    local forecast_module="$3" # module to load from mpas_app/modulefiles before running; eg. build_ursa_intel_ifort
    local start_time="$4" # format 2025-08-12t00:00:00 where non-digits can be any character
    local lead_time=$( in_base_10 "$5" )

    load_modules "$mpas_app" "$forecast_module"

    local s="$start_time"
    local config_start_time="${s:0:4}-${s:5:2}-${s:8:2}_${s:11:2}:${s:14:2}:${s:17:2}"
    local start_time_posix="${s:0:4}-${s:5:2}-${s:8:2}t${s:11:2}:${s:14:2}:${s:17:2} UTC+0"

    local history_file=$( file_at_lead_time "history." ".nc" "$start_time_posix" "$lead_time" )
    local diag_file=$( file_at_lead_time "diag." ".nc" "$start_time_posix" "$lead_time" )

    cd "$forecast_dir"

    for file in "$history_file" "$diag_file" ; do
        ncatted -a "config_start_time,global,o,c,$config_start_time" "$file"
    done
    echo Normal completion.
}

file_at_lead_time() {
    local prefix="$1"
    local suffix="$2"
    local start_time_posix="$3"
    local lead_time="$4"

    date -d "$start_time_posix + $lead_time hours" +"$prefix%Y-%m-%d_%H.%M.%S$suffix"
}

in_base_10() {
    local number="$1" # decimal with possible leading zeroes eg. 013
    local force_base_10=$( eval "n=10#$number ; echo \$n" ) # Prepend 10# to convert to base 10 (10#013)
    local base_10=$(( force_base_10 + 0 )) # final base 10 with zeroes removed (eg. 10#013 becomes 13)
    echo $base_10
}

load_modules() {
    local mpas_app="$1"
    local forecast_module="$2"

    set +x
    module use "$mpas_app/modulefiles"
    module load "$forecast_module"
    module load nco
    set -x
}
