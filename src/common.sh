#!/bin/bash
#
# Common Functions
#

function write_log () {
    STAMP=$(date +"%F %H:%M:%S" | perl -pe 's/\n//')
    if [ ${DRY_RUN} -eq 1 ]
    then
	echo "[${STAMP}] $1" | tee -a /var/log/parental-time-curb.log
    else
	echo "[${STAMP}] $1" >> /var/log/parental-time-curb.log
    fi
}

function is_logged_in () {
    user=$1
    /usr/bin/w -f -h | grep -q "^${user}"
    [ $? -eq 0 ] && return 0
    return 1
}

function is_enabled () {
    check_enabled() (
        [ -f /etc/default/parental-time-curb ] && . /etc/default/parental-time-curb
        [ "$ENABLED" == "1" ] && return 0
        return 1
    )
    return $(check_enabled)
}

function get_current_daily_total () {
    user=$1
    daily_total_file=/var/lib/parental-time-curb/${user}.daily_total
    if [ -f ${daily_total_file} ]
    then
        echo -n $(cat ${daily_total_file} | perl -pe 's/\n//')
    else
        echo -n 0
    fi
}

function set_current_daily_total () {
    user=$1
    value=$2
    daily_total_file=/var/lib/parental-time-curb/${user}.daily_total
    echo "${value}" > ${daily_total_file}
}

function inc_current_daily_total () {
    user=$1
    current_daily_total=$(get_current_daily_total ${user})
    daily_total=$(expr $current_daily_total + 1)
    set_current_daily_total ${user} ${daily_total}
    echo -n ${daily_total}
}

function is_user_locked () {
    user=$1
    STATUS=$(passwd --status ${user} | awk {'print $2'})
    [ "${STATUS}" == "L" ] && return 0
    return 1
}

function lock_user () {
    user=$1
    is_user_locked ${user}
    if [ $? -ne 0 ]
    then
        write_log "[ACTION] LOCKING USER: ${user}"
        [ ${DRY_RUN} -eq 1 ] || passwd --lock ${user} 2>&1 > /dev/null
    fi
}

function unlock_user () {
    user=$1
    is_user_locked ${user}
    if [ $? -eq 0 ]
    then
        write_log "[ACTION] UNLOCKING USER: ${user}"
        [ ${DRY_RUN} -eq 1 ] || passwd --unlock ${user} 2>&1 > /dev/null
    fi
}

function slay_user () {
    user=$1
    notify_user_error ${user} "The Dragon..." "... is about to be slain. C-YA"
    sleep 2
    write_log "[ACTION] SLAYING USER: ${user}"
    [ ${DRY_RUN} -eq 1 ] || slay ${user} 2>&1 > /dev/null
}

function lock_and_slay () {
    user=$1
    lock_user ${user}
    is_logged_in ${user}
    [ $? -eq 0 ] && slay_user ${user}
}

function notify_user_info () {
    user=$1
    subject=$2
    message=$3
    sudo -u ${user} -H DISPLAY=:0 notify-send --urgency=critical --icon=dialog-information "${subject}" "${message}"
}

function notify_user_warn () {
    user=$1
    subject=$2
    message=$3
    sudo -u ${user} -H DISPLAY=:0 notify-send --urgency=critical --icon=dialog-warning "${subject}" "${message}"
}

function notify_user_error () {
    user=$1
    subject=$2
    message=$3
    sudo -u ${user} -H DISPLAY=:0 notify-send --urgency=critical --icon=dialog-error "${subject}" "${message}"
}
