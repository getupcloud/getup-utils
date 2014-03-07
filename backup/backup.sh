#!/bin/bash
 

BACKUP_DIR="${OPENSHIFT_DATA_DIR}backup/"

if [ ! -d $BACKUP_DIR ]; then
	mkdir -p $BACKUP_DIR
fi

DATE=`date +%d-%m-%Y_%H_%M`



mysql() {
	
	DB_USER=$OPENSHIFT_MYSQL_DB_USERNAME
	DB_PASS=$OPENSHIFT_MYSQL_DB_PASSWORD
	DB_HOST=$OPENSHIFT_MYSQL_DB_HOST
	DB_PORT=$OPENSHIFT_MYSQL_DB_PORT
	FINAL_BACKUP_DIR=$BACKUP_DIR"mysql/"
	DB_PARAM='--add-drop-table --add-locks --extended-insert --single-transaction -quick'
	BACKUP_NAME="${DATE}"

	if [ ! -d  $FINAL_BACKUP_DIR ]; then
		mkdir $FINAL_BACKUP_DIR
	fi

	echo -e "\nBacking up MySQL databases..."
	if ! mysqldump $DB_PARAM  -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS --all-databases | gzip > "${FINAL_BACKUP_DIR}${BACKUP_NAME}.sql.gz"; then
		echo "[!!ERROR!!] Failed to produce mysql backup database $DB_NAME"
	fi	 

	echo -e "\nMySQL Backup Complete!"
}

postgresql() {


	DB_HOST=$OPENSHIFT_POSTGRESQL_DB_HOST
	DB_PORT=$OPENSHIFT_POSTGRESQL_DB_PORT
	DB_USER=$OPENSHIFT_POSTGRESQL_DB_USERNAME
	DB_PASS=$OPENSHIFT_POSTGRESQL_DB_PASSWORD
	DB_NAME=$OPENSHIFT_APP_NAME
	FINAL_BACKUP_DIR=$BACKUP_DIR"postgresql/"
	BACKUP_NAME="${DATE}"
 
 	if [ ! -d $FINAL_BACKUP_DIR ]; then
		mkdir $FINAL_BACKUP_DIR
	fi
 
	echo -e "\nBacking up PostgreSQL databases..." 
	if ! pg_dumpall -c -h "$DB_HOST" -U "$DB_USER" -p "$DB_PORT" | gzip > "${FINAL_BACKUP_DIR}${BACKUP_NAME}".sql.gz.in_progress; then
		echo "[!!ERROR!!] Failed to produce postgresql backup database $DB_NAME"
	else
		mv "${FINAL_BACKUP_DIR}${BACKUP_NAME}".sql.gz.in_progress "${FINAL_BACKUP_DIR}${BACKUP_NAME}".sql.gz
	fi
	 
	echo -e "\nPostgreSQL backup complete!"
}


mongodb() {

	DB_HOST=$OPENSHIFT_MONGODB_DB_HOST
	DB_PORT=$OPENSHIFT_MONGODB_DB_PORT
	DB_USER=$OPENSHIFT_MONGODB_DB_USERNAME
	DB_PASS=$OPENSHIFT_MONGODB_DB_PASSWORD
	DB_NAME=$OPENSHIFT_APP_NAME
	FINAL_BACKUP_DIR=$BACKUP_DIR"mongodb/"
	BACKUP_NAME="${DATE}"

	if [ ! -d $FINAL_BACKUP_DIR ]; then
		mkdir $FINAL_BACKUP_DIR
	fi

	echo -e "\nBacking up MongoDB databases..."
	if ! mongodump --host $DB_HOST --port $DB_PORT --username $DB_USER --password $DB_PASS --out "${FINAL_BACKUP_DIR}dump/" > /dev/null; then
		echo "[!!ERROR!!] Failed to produce mongo backup database $DATABASE"
	else
		cd $FINAL_BACKUP_DIR
		tar cfz "${BACKUP_NAME}.tar.gz" dump
		rm -rf dump
	fi

	echo -e "\nMongodb Backup Complete!"
}

if [ ! -z $OPENSHIFT_MYSQL_DB_HOST ]; then
	mysql
fi

if [ ! -z $OPENSHIFT_POSTGRESQL_DB_HOST ]; then
	postgresql
fi

if [ ! -z $OPENSHIFT_MONGODB_DB_HOST ]; then
	mongodb
fi
