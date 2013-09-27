#!/bin/bash
#
# Common Functions
#

VERSION=0.1.7

USR_LIB_DIR=/usr/lib/parental-time-curb
VAR_LIB_DIR=/var/lib/parental-time-curb
ETC_USR_DIR=/etc/parental-time-curb/users.d
VAR_LOG_FILE=/var/log/parental-time-curb.log
ETC_DEF_FILE=/etc/default/parental-time-curb
export USR_LIB_DIR VAR_LIB_DIR ETC_USR_DIR VAR_LOG_FILE ETC_DEF_FILE

ENABLED=0
LOG_LEVEL=0
NO_ACTIONS=0

[ -f ${ETC_DEF_FILE} ] && . ${ETC_DEF_FILE}
[ $DRY_RUN -eq 1 -a $NO_ACTIONS -eq 0 ] && NO_ACTIONS=1
IS_ENABLED=$ENABLED
unset ENABLED
export IS_ENABLED LOG_LEVEL NO_ACTIONS

export LOG_NORMAL=0
export LOG_VERBOSE=1
export LOG_DEBUG=2

function write_log () {
    LEVEL=$1
    MESSAGE=$2
    [ $LEVEL -gt $LOG_LEVEL ] && return
    STAMP=$(date +"%F %H:%M:%S" | perl -pe 's/\n//')
    if [ ${NO_ACTIONS} -eq 1 ]
    then
	    echo "[${STAMP}] $MESSAGE" | tee -a ${VAR_LOG_FILE}
    else
	    echo "[${STAMP}] $MESSAGE" >> ${VAR_LOG_FILE}
    fi
}

function log_normal () {
    write_log $LOG_NORMAL "$1"
}

function log_verbose () {
    write_log $LOG_VERBOSE "$1"
}

function log_debug () {
    write_log $LOG_DEBUG "$1"
}

function write_user_stats {
    user_name=$1
    echo "# ${user_name} stats
daily_total=$2
daily_bonus=$3
daily_max=$4
total_daily_max=$5
daily_delta=$6
open_time=$7
close_time=$8
is_enabled=$9
lock_modifier=${10}" \
    > "/var/log/parental-time-curb.${user_name}"
}

function get_display () {
    user=$1
    # we want just the one with the main DISPLAY (\:[0-9]+) not sub-displays
    display=$(/usr/bin/who | egrep "^${user}" | egrep '\(\:[0-9]+\)' | perl -pe 's/^.+?\((\:\d+)\)\s*$/$1/')
    echo -n ${display}
    log_debug "get_display (${user}) = ${display}"
}

function is_logged_in () {
    user=$1
    /usr/bin/w -f -h | grep -q "^${user}"
    rv=$?
    log_debug "is_logged_in (${user}) = ${rv}"
    [ $rv -eq 0 ] && return 0
    return 1
}

function is_screen_locked () {
    user=$1
    display=$(get_display ${user})
    [ -n "${display}" ] || return 0 # no display? no lockscreen possible
    (sudo -u ${user} -H DISPLAY=${display} /usr/bin/gnome-screensaver-command -q) 2>&1 | grep -q "is active"
    rv=$?
    log_debug "sudo -u ${user} -H DISPLAY=${display} /usr/bin/gnome-screensaver-command -q = ${rv}"
    [ $rv -eq 0 ] && return 0
    return 1
}

function was_screen_locked () {
    user=$1
    lock_screen_file=${VAR_LIB_DIR}/${user}.lock_count
    [ ! -e ${lock_screen_file} ] && return 1
    lsf_epoch=$(date -r ${lock_screen_file} +%s)
    now_epoch=$(date +%s)
    # if the file was touched within the last minute
    delta_epoch=$(expr $now_epoch - $lsf_epoch)
    if [ $delta_epoch -ge 60 ]
    then
        log_verbose "    ${user} lockscreen active last cycle"
        return 0
    fi
    log_verbose "    ${user} lockscreen inactive last cycle"
    return 1
}

function is_enabled () {
    [ "$IS_ENABLED" == "1" ] && return 0
    return 1
}

function get_current_daily_total () {
    user=$1
    daily_total_file=${VAR_LIB_DIR}/${user}.daily_total
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
    daily_total_file=${VAR_LIB_DIR}/${user}.daily_total
    echo "${value}" > ${daily_total_file}
}

function inc_current_daily_total () {
    user=$1
    current_daily_total=$(get_current_daily_total ${user})
    daily_total=$(expr $current_daily_total + 1)
    set_current_daily_total ${user} ${daily_total}
    echo -n ${daily_total}
}

function get_current_lock_count () {
    user=$1
    lock_count_file=${VAR_LIB_DIR}/${user}.lock_count
    count=0
    if [ -f ${lock_count_file} ]
    then
        count=$(cat ${lock_count_file} | perl -pe 's/\n//')
    fi
    log_debug "get_current_lock_count (${user}) = ${count}"
    echo -n "${count}"
}

function set_current_lock_count () {
    user=$1
    value=$2
    lock_count_file=${VAR_LIB_DIR}/${user}.lock_count
    echo -n "${value}" > ${lock_count_file}
}

function inc_current_lock_count () {
    user=$1
    current_lock_count=$(get_current_lock_count ${user})
    lock_count_value=$(expr $current_lock_count + 1)
    set_current_lock_count ${user} ${lock_count_value}
}

function inc_modified_daily_total () {
    user=$1
    modifier=$2
    current_lock_count=$(get_current_lock_count ${user})
    if [ $modifier -gt 0 -a $current_lock_count -ge $modifier ]
    then
        # threshold met, actually bump a minute
        set_current_lock_count ${user} 0
        inc_current_daily_total ${user}
    else
        # just bump the counter
        inc_current_lock_count ${user}
    fi
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
        log_normal "[ACTION] LOCKING USER: ${user}"
        [ ${NO_ACTIONS} -eq 1 ] || passwd --lock ${user} 2>&1 > /dev/null
    fi
}

function unlock_user () {
    user=$1
    is_user_locked ${user}
    if [ $? -eq 0 ]
    then
        log_normal "[ACTION] UNLOCKING USER: ${user}"
        [ ${NO_ACTIONS} -eq 1 ] || passwd --unlock ${user} 2>&1 > /dev/null
    fi
}

function slay_user () {
    user=$1
    notify_user_error ${user} "The Dragon..." "... is about to be slain. C-YA"
    sleep 2
    log_normal "[ACTION] SLAYING USER: ${user}"
    [ ${NO_ACTIONS} -eq 1 ] || slay ${user} 2>&1 > /dev/null
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
    display=$(get_display ${user})
    if [ -n "${display}" ]
    then
        sudo -u ${user} -H DISPLAY=${display} notify-send --urgency=critical --icon=dialog-information "${subject}" "${message}"
    else
        echo -e "${subject}\n${message}" | sudo write ${user}
    fi
}

function notify_user_warn () {
    user=$1
    subject=$2
    message=$3
    display=$(get_display ${user})
    if [ -n "${display}" ]
    then
        sudo -u ${user} -H DISPLAY=${display} notify-send --urgency=critical --icon=dialog-warning "${subject}" "${message}"
    else
        echo -e "${subject}\n${message}" | sudo write ${user}
    fi
}

function notify_user_error () {
    user=$1
    subject=$2
    message=$3
    display=$(get_display ${user})
    if [ -n "${display}" ]
    then
        sudo -u ${user} -H DISPLAY=${display} notify-send --urgency=critical --icon=dialog-error "${subject}" "${message}"
    else
        echo -e "${subject}\n${message}" | sudo write ${user}
    fi
}
