#! /bin/bash --login

# This script is run every day to force Rocoto to start the 0 UTC cycle.

cd /scratch4/BMC/gsd-fv3-dev/role.rtgsd-fv3-dev/MPAS_HFIP_2025/mpas_app
source load_wflow_modules.sh  ursa
cd /scratch3/BMC/gsd-fv3/role.rtgsd-fv3-dev/MPAS_HFIP_2025/exp

cycle=$( date +%Y%m%d0000 )

rocotoboot -w rocoto.xml -d rocoto.db -c $cycle -t dummy_job_to_force_rocoto_to_start_the_cycle
