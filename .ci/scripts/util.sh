#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Start the metrics collection of both docker stats and the miscellaneous os statistics.
# Parameters:
#     container_info:  the name of the docker file from which to gather statistics
#     sample_time:  The time between sampling of the statistics.
metrics_collection_start()
{
    local pge=$1
    # Split seconds argument into docker name and tag
    local cont_name="$(echo "$2" | cut -d':' -f1)"
    local container_tag="$(echo "$2" | cut -d':' -f2)"
    # cont_info should always contain pge_docker_tag, PGE, and runconfig (at a minimum)
    # container_info="${pge}_${cont_name}_${container_tag}"

    local container_info="$pge"

    # If no sample_time value is passed - default to a value of 1
    if [[ -z "$2" ]]
    then
        local sample_time=1
    else
        local sample_time=$3
    fi

    echo "Using sample time of: $sample_time"
    # Initialize output files and statistics format
    metrics_stats="${container_info}_metrics_stats.csv"
    echo "local file name from assignment at line 30: $metrics_stats"

    metrics_misc="${container_info}_metrics_misc.csv"
    echo "local file name from assignment at line 33: $metrics_misc"

    stat_format="{{.Name}},CPU,{{.CPUPerc}},MEM,{{.MemUsage}},MEM %,{{.MemPerc}},NET,{{.NetIO}},BLOCK,{{.BlockIO}},PIDS,{{.PIDs}}"

    # initialize start seconds and csv file contents - put on first line of each file
    METRICS_START_SECONDS=$SECONDS
    echo "SECONDS,$stat_format" > "$metrics_stats"

    # start the background processes to monitor docker stats
    { while true; do ds=$(docker stats --no-stream --format "${stat_format}" "${pge}" 2>/dev/null); \
    echo "$(metrics_seconds)","$ds" >> "${metrics_stats}"; sleep "$sample_time"; done } & \
    echo "$!" > "${container_info}_metrics_stats_bg_pid.txt"

    # Miscellaneous Statistics

    # test for MAC operating system for OS statistics
    if [[ $OSTYPE == "darwin"* ]]
    then
        echo "Mac Operating system: $OSTYPE"
        echo "SECONDS,disk_used,total_threads,last_line" > "$metrics_misc"

        block_space_cmd='df -B 1024 | grep "/System/Volumes/VM"'

        sys_threads_cmd='ps -elf | wc -l'

        # Set directory fo the log file
        last_log_line_dir='pwd'

        lll_file="last_log_line.txt"
        lll_cmd="echo $(find ${last_log_line_dir} -name ${lll_file} -exec rm {} \; 2>/dev/null)"

        { while true; do dus=$(eval "$block_space_cmd"); ths=$(eval "$sys_threads_cmd"); lll=$(eval "$lll_cmd"); \
        echo "$(metrics_seconds),$dus,$ths,$lll" >> "${metrics_misc}"; sleep "$sample_time"; done } & \
        echo "$!" > "${container_info}_metrics_misc_bg_pid.txt"
    else
        echo "Linux Operating system: $OSTYPE"
        echo "SECONDS, disk_used, swap_used, total_threads, last_line" > "$metrics_misc"
        # Use 'df' command to capture the amount of space on the '/dev/vda1' file system (-B sets block size (1K)
        # the line represent Filesystem  1K-blocks  Used Blocks Available Blocks %Used Mounted_On
        block_space_cmd='df -B 1024 | grep "/dev/vda1"'

        # Get the number of system threads
        sys_threads_cmd='ps -elf | wc -l'

        # Use 'free' to get the total amount of Swap space available
        swap_space_cmd='free -g | grep Swap'

        # Set directory fo the log file
        last_log_line_dir='pwd'

        lll_file="last_log_line.txt"
        find ${last_log_line_dir} -name ${lll_file} -exec rm {} \; 2>/dev/null
        lll_cmd="echo $(find ${last_log_line_dir} -name ${lll_file} -exec rm {} \; 2>/dev/null)"

        { while true; do dus=$(eval "$block_space_cmd"); swu=$(eval "$swap_space_cmd"); ths=$(eval "$sys_threads_cmd"); \
        lll=$(eval "$lll_cmd"); echo "$(metrics_seconds), $dus, $swu, $ths, $lll" >> "${metrics_misc}"; \
        sleep "$sample_time"$; done } & \
        echo "$!" >> "${container_info}_metrics_misc_bg_pid.txt"
    fi

}

metrics_collection_end()
{
    local container_info=$1
    local exit_code=$2
    # TODO The variables below will be used in the future.
    # mce_pge=$3
    # mce_runconfig=$4

    local metrics_stats="${container_info}_metrics_stats.csv"
    local metrics_misc="${container_info}_metrics_misc.csv"

    # kill the background tasks
    kill "$(cat "${container_info}_metrics_stats_bg_pid.txt")"
    rm "${container_info}"_metrics_stats_bg_pid.txt
    kill "$(cat "${container_info}_metrics_misc_bg_pid.txt")"
    rm "${container_info}"_metrics_misc_bg_pid.txt

    if [[ $exit_code == 0 ]]
    then
        python3 "$SCRIPT_DIR"/process_metric_data.py "$container_info" "$metrics_stats" "$metrics_misc"
        process_metrics_exit_code=$?
        if [[ $process_metrics_exit_code == 0 ]]
        then
            rm "$metrics_stats"
            rm "$metrics_misc"
        fi
    else
        echo "Docker exited with an error and so metrics will not be processed or uploaded (csv files will be saved)."
        echo "Error code: $process_metrics_exit_code"
    fi

    echo "metrics_collection has completed."
}

metrics_seconds()
{
    echo $(( SECONDS - METRICS_START_SECONDS ))
}
