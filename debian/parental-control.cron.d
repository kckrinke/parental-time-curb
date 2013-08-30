# /etc/cron.d/parental-control: crontab entries for the parental-control package

SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# run this task every minute of every day
*  *  *  *  *    root    /usr/lib/parental-control/tracker
