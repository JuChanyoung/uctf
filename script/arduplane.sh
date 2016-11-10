#!/usr/bin/env sh

executable=$1
mav_sys_id=$2
base_port=$3
rc_in_port=$4
gazebo_port_in=$5
gazebo_port_out=$6
default_params=$7
model=$8
home_str=$9

# Run the autopilot in a tempdir so that the eeprom.bin doesn't conflict
dir=`mktemp -d`
echo "temporary rootfs: $dir"
cd $dir

CMD="$executable -S --base-port $base_port --rc-in-port $rc_in_port --gazebo-port-in $gazebo_port_in --gazebo-port-out $gazebo_port_out --home $home_str --model $model --speedup 10 --defaults $default_params"
echo "Running [[$CMD]]"
$CMD