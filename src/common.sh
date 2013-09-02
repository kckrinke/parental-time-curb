#!/bin/bash
#
# Common Functions
#

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
export LOG_VERBOSE=0

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

function is_logged_in () {
    user=$1
    /usr/bin/w -f -h | grep -q "^${user}"
    [ $? -eq 0 ] && return 0
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
