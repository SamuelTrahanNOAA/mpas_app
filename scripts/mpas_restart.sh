#! /bin/sh

# This is a shell library that is meant to be sourced, not executed.

mpas_restart() {
    set -xue

    local forecast_dir="$1" # path to exp forecast directory where original mpas ran
    local mpas_app="$2" # full path to mpas executable (eg. /path/to/exec/atmosphere_model)
    local start_time="$3" # format 2025-08-12t00:00:00 where non-digits can be any character
    local forecast_length="$4" # integer number of hours
    local mpi_command="$5" # srun, mpiexec, or similar
    local forecast_module="$6" # module to load from mpas_app/modulefiles before running; eg. build_ursa_intel_ifort
    local max_run_duration="$7"

    local forecast_exe=$mpas_app/exec/atmosphere_model

    cd "$forecast_dir"

    move_old_files log.atmosphere.*.out # Must rename ASAP since it is a Rocoto hang dependency

    set +x
    load_modules "$mpas_app" "$forecast_module"
    module list
    set -x

    clean_directory

    local restart=$( find_restart || true )
    local incomplete_run=NO
    local restart_lead_time=0
    local run_duration=$forecast_length
    local do_restart=ERROR_IF_UNSET
    local restart_time="$start_time"

    if [[ -n "$restart" && -s "$restart" ]] ; then
        restart_time=$( timestamp_from_filename "$restart" )
        restart_lead_time=$( calculate_lead_time "$start_time" "$restart_time" )
        run_duration=$(( forecast_length - restart_lead_time ))
        do_restart=.true.
    else
        echo "No restart found. Will cold start."
        do_restart=.false.
    fi

    if (( run_duration > max_run_duration )) ; then
        echo "Reducing run duration from $run_duration to $max_run_duration hours for testing."
        incomplete_run=YES
        run_duration=$max_run_duration
    fi

    update_namelist namelist.atmosphere "$restart_time" "$run_duration" "$do_restart"

    if (( run_duration > 0 )) ; then
       ldd "$forecast_exe"
       echo Run "$forecast_exe"
       echo Log to "$PWD/runscript.mpas_restart.out"
       $mpi_command hostname
       if ( ! $mpi_command "$forecast_exe" ) ; then
           echo MPAS failed. See log for errors. 1>&2
           exit 1
       fi
    else
        echo "Estimated run duration is 0."
        echo "Forecast already completed?"
    fi

    if [[ "$incomplete_run" == NO ]] ; then
        echo "Forecast completed at $( date )" > completion_timestamp
        echo "Deleting restart files because they're so frelling huge."
        rm -f restart.*
    else
        echo "Successful execution!"
        echo "Forecast has not completed full duration yet."
        echo "Deleting old restart files."
        for restart in restart* ; do
            local file_time=$( timestamp_from_filename "$restart" )
            local file_lead_time=$( calculate_lead_time "$start_time" "$file_time" )
            if (( file_lead_time < restart_lead_time )) ; then
                rm -f "$restart"
            fi
        done
        echo "Exiting with status 108 to ensure rocoto submits the next restart job."
        exit 108
    fi
}

load_modules() {
    local mpas_app="$1"
    local forecast_module="$2"

    module use "$mpas_app/modulefiles"
    module load "$forecast_module"
}

clean_directory() {
    rm -f core*
    tar_old_err_files
    copy_old_files namelist.atmosphere runscript.mpas_restart.out
}

tar_old_err_files() {
    if [[ $( find . -name 'log.atmosphere*err' | wc -c ) > 0 ]] ; then
        local old="log.atmosphere.err.$( date +"%Y-%m-%d_%H-%M-%S" ).tar"
        tar -cpf "$old" log.atmosphere*err
        test -s "$old" || rm -f "$old"
        rm -f log.atmosphere*err
    fi
}

copy_old_files() {
    local log
    local old

    for log in "$@" ; do
        old="$log.$( date +"%Y-%m-%d_%H-%M-%S" ).old"

        if [[ -f "$log" ]] ; then
            cp -fp "$log" "$old"
            chmod a-w "$old"
        fi
    done
}

move_old_files() {
    local log
    local old

    for log in "$@" ; do
        old="$log.$( date +"%Y-%m-%d_%H-%M-%S" ).old"

        if [[ -f "$log" ]] ; then
            mv -f "$log" "$old"
            chmod a-w "$old"
        fi
    done
}

timestamp_from_filename() {
    echo "$1" | perl -ne '
      chomp;
      m,(\d\d\d\d).(\d\d).(\d\d).(\d\d).00.00,
        or die "Found no timestamp in \"$_\"";
      print("${1}-${2}-${3}_${4}:00:00 UTC+0\n")
    '
}

mpas_to_posix_time() {
    echo "$1" | perl -ne '
      chomp;
      m,(\d\d\d\d).(\d\d).(\d\d).(\d\d).00.00,
        or die "Found no timestamp in \"$_\"";
      print("${1}-${2}-${3}t${4}:00:00 UTC+0\n")
    '
}

find_restart() {
    # Find the first restart file that appears to be complete and print it to stdout.
    # Return 0 on success, 1 on failure.

    for restart in $( ls -1t restart.*.nc || echo NONE ) ; do
        if [[ "$restart" == NONE ]] ; then
            break
        fi
        local history=$( echo "$restart" | sed s,restart,history,g )
        local diag=$( echo "$restart" | sed s,restart,diag,g )
        if [[ ! -s "$history" ]] ; then
            echo "$restart": no "$history" 1>&2
        elif [[ ! -s "$diag" ]] ; then
            echo "$restart": no "$diag" 1>&2
        elif [[ ! -s "$restart" ]] ; then
            echo "$restart": no "$restart" 1>&2
        else
            echo "$restart": appears valid 1>&2
            echo "$restart"
            return 0
        fi
    done

    return 1
}

calculate_lead_time() {
    local start_time="$1"
    local restart_time="$2"

    local restart_posix_time=$( mpas_to_posix_time "$restart_time" )
    local restart_epoch_time=$( date +%s -d "$restart_posix_time" )

    local start_posix_time=$( mpas_to_posix_time "$start_time" )
    local start_epoch_time=$( date +%s -d "$start_posix_time" )

    local restart_lead_time=$(( (restart_epoch_time - start_epoch_time + 3599)/3600 ))

    echo "$restart_lead_time"
}

update_namelist() {
    local namelist="$1"
    local restart_time="$2"
    local run_duration="$3"
    local do_restart="$4"

    cat "$namelist" | \
        /usr/bin/env RESTART_TIME="$restart_time" \
                     RUN_DURATION="$run_duration" \
                     DO_RESTART="$do_restart" \
            perl -ne '
              s/config_start_time.*/config_start_time = "$ENV{RESTART_TIME}"/g ;
              s/config_do_restart.*/config_do_restart = $ENV{DO_RESTART}/g ;
              s/config_run_duration.*/config_run_duration = "$ENV{RUN_DURATION}:00:00"/g ;
              print
            ' \
        > "$namelist".tmp && \
    mv -f "$namelist".tmp "$namelist"
}
