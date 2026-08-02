#!/usr/bin/env bash
set -Eeo pipefail

# Set PostgreSQL version
PGVER=${PGVER:-15}

#Define  proper shutdown
# This is only needed with the postgresql instance
cleanup() {
    echo "Container stopped, performing shutdown"
    su -c "/usr/lib/postgresql/${PGVER}/bin/pg_ctl -D /data/database stop" postgres
}
# Check for an existing DB.
function DBCheck {
        DB=$(su -c " psql -lqt" postgres | awk /gvmd/'{print $1}')
        if [ "$DB" = "gvmd" ]; then
		echo 1
	else
		echo 0
        fi
}
# Clear out the old sockets so we can test for it in gvmd
if [ -S /run/postgresql/.s.PGSQL.5432 ]; then
	rm -f /run/postgresql/.s.PGSQL.5432
fi
# Until I find a better way, Force this here.
chown -R postgres /run/postgresql

# Postgres config should be tighter.
# Actually, postgress should be in its own container!
# maybe redis should too.
if [ ! -f "/setup" ]; then
	echo "Creating postgresql.conf and pg_hba.conf"
	# Create conf.d directory if it doesn't exist
	mkdir -p /data/database/conf.d
	# Need to look at restricting this. Maybe to localhost ?
	echo "listen_addresses = '*'" > /data/database/postgresql.conf
	echo "port = 5432" >> /data/database/postgresql.conf
	echo "log_destination = 'stderr'" >> /data/database/postgresql.conf
	echo "logging_collector = on" >> /data/database/postgresql.conf
	echo "log_directory = '/data/var-log/postgresql/'" >> /data/database/postgresql.conf
	echo "log_filename = 'postgresql-gvmd.log'" >> /data/database/postgresql.conf
	echo "log_file_mode = 0666" >> /data/database/postgresql.conf
	echo "log_truncate_on_rotation = off" >> /data/database/postgresql.conf
	echo "log_line_prefix = '%m [%p] %q%u@%d '" >> /data/database/postgresql.conf
	echo "log_timezone = 'Etc/UTC'" >> /data/database/postgresql.conf
	# This probably tooooo open.
	echo -e "host\tall\tall\t0.0.0.0/0\tmd5" > /data/database/pg_hba.conf
	echo -e "host\tall\tall\t::0/0\tmd5" >> /data/database/pg_hba.conf
	echo -e "local\tall\tall\ttrust"  >> /data/database/pg_hba.conf
	chown postgres:postgres -R /data/database
	touch /setup
fi

PGFAIL=0
PGUPFAIL=0
# Clean up stale PostgreSQL lock files from previous unclean shutdowns.
# pg_ctl otherwise refuses to start, and the container mistakes the failure
# for a DB version mismatch and bails out ("keeps going down").
if [ -f /data/database/postmaster.pid ]; then
	PID=$(head -1 /data/database/postmaster.pid 2>/dev/null || echo 0)
	if [ -n "$PID" ] && [ "$PID" != "0" ] && ! kill -0 "$PID" 2>/dev/null; then
		echo "Removing stale PostgreSQL lock file (PID $PID not running)"
		rm -f /data/database/postmaster.pid
		rm -f /data/database/postmaster.opts
	fi
fi
echo "Starting PostgreSQL..."
# -t 180: after an unclean shutdown (power/IO), PostgreSQL crash recovery can
# take minutes. The default 60s timeout made pg_ctl report failure, which the
# container then misread as a DB version mismatch, causing the container to exit.
su -c "/usr/lib/postgresql/${PGVER}/bin/pg_ctl -D /data/database -t 180 start" postgres || PGFAIL=$?
echo "pg exit with $PGFAIL ."
if [ $PGFAIL -ne 0 ]; then
        echo "It looks like postgres failed to start. ( Exit code: \"$PGFAIL\" "
        echo "Assuming this is due to different database version and starting upgrade."
        /scripts/db-upgrade.sh || PGUPFAIL=$?
        if [ $PGUPFAIL -ne 0 ]; then
                echo "Looks like this is either not an upgrade problem, or the upgrade failed."
                exit
        else
                echo " DB Upgrade was a success. Starting postgresql ${PGVER}"
                su -c "/usr/lib/postgresql/${PGVER}/bin/pg_ctl -D /data/database start" postgres
        fi
fi

trap 'cleanup' SIGTERM
echo "Checking for existing DB"
su -c " psql -lqt " postgres
DB=$(su -c " psql -lqt" postgres | awk /gvmd/'{print $1}')
# Do we need to load the default DB from archives in the image?
echo "DB is $DB"
ls -l /usr/lib/*.xz
if [ "$DB" = "gvmd" ]; then
	LOADDEFAULT="false"
elif ! [ -f /usr/lib/gvmd.sql.xz ] || [ $(stat -c%s /usr/lib/gvmd.sql.xz 2>/dev/null || echo 0) -lt 100 ]; then
	LOADDEFAULT="false"
else
	LOADDEFAULT="true"
fi

# Pass this variable to gvmd via /run
echo $LOADDEFAULT > /run/loaddefault
#
# If no default is being loaded, then we need to create an empty database.
if [ -z $DB ] && [ $LOADDEFAULT = "false" ]; then
	if [ $(DBCheck) -eq 1 ]; then
		echo " It looks like there is already a gvmd database."
		echo " Failing out to prevent overwriting the existing DB"
		exit
	fi
	echo "Creating Greenbone Vulnerability Manager database"
	su -c "createuser -DRS gvm" postgres
	su -c "createdb -O gvm gvmd" postgres
	su -c "psql --dbname=gvmd --command='create role dba with superuser noinherit;'" postgres
	su -c "psql --dbname=gvmd --command='grant dba to gvm;'" postgres
	su -c "psql --dbname=gvmd --command='create extension \"uuid-ossp\";'" postgres
	su -c "psql --dbname=gvmd --command='create extension \"pgcrypto\";'" postgres
	chown postgres:postgres -R /data/database
	su -c "/usr/lib/postgresql/${PGVER}/bin/pg_ctl -D /data/database restart" postgres

#	su -c "gvm-manage-certs -V" gvm
#	NOCERTS=$?
#	while [ $NOCERTS -ne 0 ] ; do
		su -c "gvm-manage-certs -vaf " gvm
#		su -c "gvm-manage-certs -V " gvm
#		NOCERTS=$?
#	done
fi



tail -f /data/var-log/postgresql/postgresql-gvmd.log &
# This is part of making sure we shutdown postgres properly on container shutdown and only needs to exist
# in postgresql instance
wait $!
