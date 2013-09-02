# /etc/cron.d/parental-time-curb: crontab entries for the parental-time-curb package

SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# run this task every minute of every day
# (stdout is logged anyways, so send to /dev/null)
# (stderr is actual errors, so log somewhere)
*  *  *  *  *    root    /usr/lib/parental-time-curb/tracker 1>/dev/null 2>> /var/log/parental-time-curb.log
