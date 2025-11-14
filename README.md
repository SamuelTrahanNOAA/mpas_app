MPAS HFIP 2025 GFS-Initialized Parallel
=======================================

This branch contains the code and scripts used for the MPAS HFIP experiment in 2025, using GFS-only initial conditions.
A second configuration using GFS and HAFS will be in another branch. Both are based on the mpas_app.

Many capabilities of this branch are not yet in the authoritative mpas_app. This includes:

1. Archiving.
2. Scrubbing.
3. Automatic restart when the model fails.
4. Detection of model hangs, resulting in Rocoto resubmitting a restart.
5. GFDL Vortex Tracker.

Also, this branch includes the cron scripts and Rocoto XML that were used in real-time (with comments added).

### General Documentation for the `mpas_app`

This section is paraphrased from the `mpas_app`'s documentation.

- This is a branch of the MPAS App, an app for building and running the [MPAS-Model](https://github.com/NOAA-GSL/MPAS-Model).

- Full documentation for the authoritative branch of the app is hosted on [Read the Docs](https://mpas-app.readthedocs.io/en/latest).

- For bugs, questions, and requests related to the app, please use GitHub Issues in the `NOAA-GSL`/`mpas_app` repository. These will be monitored closely, and we will get back to you as quickly as possible.

Real-time Workflow
------------------

Step-by-step:

1. Just after the synoptic time, a cron job submits the *dummy_job_to_force_rocoto_to_start_the_cycle* job to force Rocoto to start the cycle. This job does nothing on its own; the act of running it is enough.
2. *get_ics_data* pulls GFS data from AWS. (In the HAFS-initialized parallel, this step would copy the merged HAFS+GFS GRIB files from another workflow.)
3. *ungrib_ics* converts GRIB files to intermediate files usable by MPAS.
4. *mpas_ics* generates an MPAS input file from the prior step's files.
5. *mpas* attempts to run the MPAS 120 hour forecast, and usually hangs.
6. *mpas_restart* only runs if the *mpas* job hangs. It forecasts a maximum of 24 hours before resubmitting. This is a simpler job than *mpas*, reducing the chances of errors from, for example, conflicting library versions from conda.
7. Each time model output files diag and history streams are both available for a forecast time, the following happens.
   1. *change_start_time* edits the history and diag file start times to be the initial start time. This is necessary for the restart jobs whose output files' start time is set to the restart time instead.
   2. *delete_old_restarts* deletes all but the two latest restart files. This is to save disk space.
   3. *mpassit* runs MPASSIT to convert history and diag files to gridded data usable by UPP
   3. *upp* runs UPP to generate GRIB files, three per output time
   3. *combine_grib* concatinates the three output GRIB files into one, to feed the graphics
   3. *delete_model_and_mpassit_output* doesn't do what it says. All it deletes is the history and diag files. The mpassit files aren't deleted until after archiving.
8. *tracker* is run after all post-processing is complete
9. *graphics* is run at the same time as the tracker
10. Archiving and Scrubbing - Several of these jobs may run at once. All wait for post-processing to complete, but some may have additional dependencies.
    1. *archive_mpassit* archives all MPASSIT output files using htar. They're split into six archives, one per day, due to htar archive size limitations.
    1. *archive_upp* archives the three UPP output GRIB files from each output time using htar.
    1. *archive_tracker* archives the entire tracker directory using htar, including intermediate GRIB files, configuration, and output.
    1. *archive_init* archives the init files from the forecast directory. Unlike other jobs, this one uses "hsi put" since the init file is too large for an htar archive.
    1. *scrub_forecast* runs after the tracker completes. It deletes all diag, history, and restart files from the forecast directory. This should only be the final two restart files.
    1. *scrub_mpassit* runs as soon as the post-processing is complete and mpassit files are archived. It deletes all mpassit intermediate and output files.
    2. *scrub_init* runs when the *archive_init* completes. It deletes the init file and the graph files (which were copied from elsewhere).
    9. *scrub_mpas_ics* scrubs the directory that ran MPAS's init_atmosphere. This is a duplicate of the file in *scrub_init*.
11. *final* marks the cycle as complete when all jobs are complete except *mpas* or *mpas_restart*. This is necessary because no cycles will complete both jobs, and hence Rocoto wouldn't ever think the cycle is complete.