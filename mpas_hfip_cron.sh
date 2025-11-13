#! /bin/bash --login

# This is the cron script used in the MPAS HFIP experiment.
# It is included here for posterity.

cd /scratch4/BMC/gsd-fv3-dev/role.rtgsd-fv3-dev/MPAS_HFIP_2025/mpas_app
source load_wflow_modules.sh  ursa
cd /scratch3/BMC/gsd-fv3/role.rtgsd-fv3-dev/MPAS_HFIP_2025/exp

# The start cycle (202510180000) was often changed to avoid automatically submitting cycles that had manual intervention.

rocotorun -w rocoto.xml -d rocoto.db -c 202510180000:202512310000
