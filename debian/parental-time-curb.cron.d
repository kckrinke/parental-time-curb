# /etc/cron.d/parental-time-curb: crontab entries for the parental-time-curb package

SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# run this task every minute of every day
*  *  *  *  *    root    /usr/lib/parental-time-curb/tracker
