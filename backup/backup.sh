#!/bin/bash

#
# Configs
#

# Where to store backups
BACKUP_DIR="${OPENSHIFT_DATA_DIR}backup/"

# Number of days to keep backup files
CYCLE_DAYS=7

# Space-separated list of mongodb databases to backup
MONGODB_DATABASES="$OPENSHIFT_APP_NAME"

# Don't need to touch below
#####################################################

set -eu

if [ ! -d $BACKUP_DIR ]; then
	mkdir -p $BACKUP_DIR
fi

SECONDS_IN_A_DAY=86400
TIMESTAMP=`date +%s`
ISODATE=`date --rfc-3339=seconds --date=@$TIMESTAMP | tr -s ' ' _` # Format: 1970-01-01_00:00:00+00:00
function from_iso() { date --date="${1/_/ }" +%s; }

CRON_PERIOD=${0##*/cron/}
CRON_PERIOD=${CRON_PERIOD%%/*}
case "$CRON_PERIOD" in
	minutely|hourly|daily) SENTINEL=$[ TIMESTAMP - SECONDS_IN_A_DAY ];;
	*) SENTINEL=${SENTINEL:-0}
esac

function info() { echo "[`date`]" INFO $*; }
function error() { echo "[`date`]" ERROR $*; }

function remove_old_backup()
{
	local DIR=$1
	cd $DIR
	for FILE in *.gz; do
		if [ -f "${FILE}" ]; then
			FILE_DATE="${FILE%%.*}"
			FILE_DATE="${FILE_DATE##*/}"
			FILE_TIMESTAMP=`from_iso $FILE_DATE`
			if [ "$FILE_TIMESTAMP" -lt $SENTINEL ]; then
				rm -fv "./$FILE"
			fi
		fi
	done
}

function backup_database()
{
	local NAME="$1"
	shift
	local CMD="$*"
	if [ ! -d $BACKUP_DIR/$NAME ]; then
		mkdir $BACKUP_DIR/$NAME
	fi
	info Start backup: $NAME

	cd $BACKUP_DIR/$NAME
	info "-> " "[${BACKUP_DIR}${NAME}/${ISODATE}.gz]"
	if $CMD | gzip > "${BACKUP_DIR}${NAME}/${ISODATE}.gz"; then
		remove_old_backup $PWD
		info Finished backup: $NAME
	else
		error Backup failed: $NAME
	fi	 

}

function mysql()
{
	
	local DB_PARAM='--add-drop-table --add-locks --extended-insert --single-transaction -quick'
	backup_database mysql mysqldump $DB_PARAM -h $OPENSHIFT_MYSQL_DB_HOST -P $OPENSHIFT_MYSQL_DB_PORT -u $OPENSHIFT_MYSQL_DB_USERNAME -p$OPENSHIFT_MYSQL_DB_PASSWORD --all-databases
}

function postgresql()
{
	backup_database postgresql pg_dumpall -c -h "$OPENSHIFT_POSTGRESQL_DB_HOST" -p "$OPENSHIFT_POSTGRESQL_DB_PORT" -U "$OPENSHIFT_POSTGRESQL_DB_USERNAME"
}

function mongodb_dump()
{
	local DBNAME=$1
	local DUMPDIR=dump_$TIMESTAMP
	mongodump --db $DBNAME --host $OPENSHIFT_MONGODB_DB_HOST --port $OPENSHIFT_MONGODB_DB_PORT --username $OPENSHIFT_MONGODB_DB_USERNAME --password $OPENSHIFT_MONGODB_DB_PASSWORD --out $DUMPDIR > /dev/null
	tar cf - $DUMPDIR && rm -rf $DUMPDIR >/dev/null || rm -rf $DUMPDIR >/dev/null
}

function mongodb()
{
	for _DB in $MONGODB_DATABASES; do
		backup_database mongodb mongodb_dump $_DB
	done
}

[ ${OPENSHIFT_MYSQL_DB_HOST}      ] && mysql
[ ${OPENSHIFT_POSTGRESQL_DB_HOST} ] && postgresql
[ ${OPENSHIFT_MONGODB_DB_HOST}    ] && mongodb
