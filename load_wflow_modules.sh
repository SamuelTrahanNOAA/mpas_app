
scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )

if [[ "${1:-FORGETFUL}" == FORGETFUL ]] ; then
  echo "ERROR: Specify the machine name."
else
  module use $scrfunc_dir/modulefiles
  module load wflow_$1 > /dev/null 2>&1

  conda activate mpas_app
fi
