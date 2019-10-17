#!/bin/bash
#
#    .VERSION
#    0.1
#
#    .DESCRIPTION
#    Author: Nikitin Maksim
#    Github: https://github.com/nikimaxim/zbx-smartmonitor.git
#    Note: Zabbix lld for smartctl
#
#    .TESTING
#    Smartmontools: 7.1 and later
#

CTL='/usr/sbin/smartctl'


LLDSmart()
{
    smart_scan=$($CTL --scan-open | sed -e 's/\s*$/;/')
    disk_sn_all=()

    IFS=";"
    for device in ${smart_scan}; do
        device=$(/bin/echo $device | grep -iE "^(\w*|\d*).")

        storage_args=""
        storage_name=""
        storage_cmd=""
        storage_type=0
        storage_model=""
        storage_sn=""
        storage_smart=0

        # Remove non-working disks
        # Example: "# /dev/sdb -d scsi"
        if [[ ! ${device} =~ (^\s*#|^#) ]]; then
            storage_args=$(/bin/echo ${device} | cut -f 1 -d'#' | awk '{print $2 $3}')
            storage_name=$(/bin/echo ${device} | cut -f 1 -d'#' | awk '{print $1}')

            temp_info=$($CTL -i $storage_name $storage_args)

            storage_sn=$(/bin/echo ${temp_info} | grep "Serial Number:" | cut -f2 -d":" | sed -e 's/^\s*//')

            if [[ ! -z $storage_sn ]] && [[ ! $disk_sn_all == *"$storage_sn"* ]]; then
                if [ -z $disk_sn_all ]; then
                    disk_sn_all=$storage_sn
                else
                    disk_sn_all+=" ${storage_sn}"
                fi

                storage_cmd="${storage_name} ${storage_args}"

                # Device smart
                if [ -n $(/bin/echo $temp_info | grep -iE "^SMART support is:.+Enabled\s*$") ]; then
                    storage_smart=1
                fi

                if [[ $storage_args == *"nvme"* ]] || [[ $storage_name == *"nvme"* ]]; then
                    storage_type=1
                    storage_smart=1
                fi

                # Device Model
                d=$(/bin/echo $temp_info | grep "Device Model:" | cut -f2 -d":" | sed -e 's/^\s*//')
                if [ -n $d ]; then
                    storage_model=$d
                else
                    p=$(/bin/echo $temp_info | grep "Product:" | cut -f2 -d":" | sed -e 's/^\s*//')
                    if [ -n $p ]; then
                        storage_model=$p
                    else
                        v=$(/bin/echo $temp_info | grep "Vendor:" | cut -f2 -d":" | sed -e 's/^\s*//')
                        if [ -n $v ]; then
                            storage_model=$v
                        else
                            storage_model="Not find"
                        fi
                    fi
                fi

                # 0 is for HDD
                # 1 is for SSD/NVMe
                if [ -n $(/bin/echo $temp_info | grep -iE "^Rotation Rate:\s*rpm\s*$") ]; then
                    storage_type=0
                elif [ -n $(/bin/echo $temp_info | grep -iE "^Rotation Rate:\s*Solid State Device\s*$") ]; then
                    storage_type=1
                fi

                storage_info="{\"{#STORAGE.SN}\":\"${storage_sn}\",\"{#STORAGE.MODEL}\":\"${storage_model}\",\"{#STORAGE.NAME}\":\"${storage_name}\",\"{#STORAGE.CMD}\":\"${storage_cmd}\",\"{#STORAGE.SMART}\":\"${storage_smart}\",\"{#STORAGE.TYPE}\":\"${storage_type}\"},"
                storage_json=$storage_json$storage_info
            fi
        fi
    done

    echo "{\"data\":[$(/bin/echo ${storage_json} | sed -e 's/,$//')]}"
}

LLDSmart
