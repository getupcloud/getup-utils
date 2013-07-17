#!/bin/bash

set -e

OPENSHIFT_BASEDIR=/var/lib/openshift

usage()
{
cat << EOF
usage: $0 options

This script is used to migrate v1 -> v2 Openshift Origin Cartridges

OPTIONS:
   -h | --help      Show this message
   -a      Application container UUID
   -n      Application namespace
   -m      Application name
   -c      Cartridge Type
   -u 		 DB Username (Required for database cartridges)
   -p      DB Password (Required for database cartridges)
EOF
}

migrate_common()
{



	#enable cgroups
	echo
	echo "Enabling Cgroups..."
	/usr/bin/oo-cgroup-enable -c $APP_UUID

	cd /var/lib/openshift/$APP_UUID


	pushd .env
	#remove old env vars
	echo
	echo "Removing old env vars..."
	[ -f USER_VARS ] && rm -f USER_VARS
	[ -f OPENSHIFT_INTERNAL_IP ] && rm -f OPENSHIFT_INTERNAL_IP
	[ -f OPENSHIFT_INTERNAL_PORT ] && rm -f OPENSHIFT_INTERNAL_PORT

	#convert vars for new model
	echo
	echo "Converting env vars to new format..."
	for i in `grep -l ^export *`; do source $i; eval echo -n \$$i > $i; done

	#create missing env vars
	echo
	echo "Creating APP_NAMESPACE env var..."
	echo -n  $APP_NAMESPACE > OPENSHIFT_NAMESPACE
	chcon -u system_u -r object_r -t openshift_var_lib_t *

	popd

	#fix git hooks
	echo
	echo "Fixing git hooks..."
	echo "gear prereceive" > /var/lib/openshift/$APP_UUID/git/${APP_NAME}.git/hooks/pre-receive
	echo "gear postreceive" > /var/lib/openshift/$APP_UUID/git/${APP_NAME}.git/hooks/post-receive

}


migrate_php()

{

	cd /var/lib/openshift/$APP_UUID
	
	if [ -d php-5.3 ]; then
		echo
		echo "PHP-5.3 v1 cartridge detected..."


		#remove old env var
		pushd .env
		[ -f OPENSHIFT_PHP_LOG_DIR ] && rm -f OPENSHIFT_PHP_LOG_DIR
		popd

		#Php-5.3 v1 cartridges upgrade.
		echo
		echo "Creating php-5.3 v2 cartridge..."
		if [ ! -d ${OPENSHIFT_BASEDIR}/$APP_UUID/php ]; then
			oo-cartridge --with-container-uuid $APP_UUID --action add --with-cartridge-name php-5.3
		fi

		echo
		echo "Stopping gear..."
		oo-admin-ctl-gears stopgear $APP_UUID

		#clean up old php cartridge
		if [ -d php-5.3 ]; then
			rm -Rf php-5.3
		fi
		echo
		echo "All good!"
	else 
		echo
		echo "No php-5.3 v1 cartridge detected! Nothing to do."
		exit 1
	fi
}

migrate_mysql()
{


	cd /var/lib/openshift/$APP_UUID

	if [ -d mysql-5.1 ]; then

		#save the old ip configuration due grant access
		echo
		echo "Saving old mysql internal ip..."
		old_mysql_ip=$(<.env/OPENSHIFT_MYSQL_DB_HOST)

				#remove old env vars
		echo
		echo "Cleaning up old env vars..."
		pushd .env

		openshift_mysql_db_log_dir=$(<OPENSHIFT_MYSQL_DB_LOG_DIR)
		openshift_mysql_db_password=$(<OPENSHIFT_MYSQL_DB_PASSWORD)
		openshift_mysql_db_socket=$(<OPENSHIFT_MYSQL_DB_SOCKET)
		openshift_mysql_db_url=$(<OPENSHIFT_MYSQL_DB_URL)
		openshift_mysql_db_username=$(<OPENSHIFT_MYSQL_DB_USERNAME)


		[ -f OPENSHIFT_MYSQL_DB_LOG_DIR ] && rm -f OPENSHIFT_MYSQL_DB_LOG_DIR
		[ -f OPENSHIFT_MYSQL_DB_PASSWORD ] && rm -f OPENSHIFT_MYSQL_DB_PASSWORD
		[ -f OPENSHIFT_MYSQL_DB_URL ] && rm -f OPENSHIFT_MYSQL_DB_URL
		[ -f OPENSHIFT_MYSQL_DB_SOCKET ] && rm -f OPENSHIFT_MYSQL_DB_SOCKET
		[ -f OPENSHIFT_MYSQL_DB_USERNAME ] && rm -f OPENSHIFT_MYSQL_DB_USERNAME

		popd


		echo
		echo "Creating mysql-5.1 v2 cartridge..."
		if [ ! -d ${OPENSHIFT_BASEDIR}/$APP_UUID/mysql ]; then
			oo-cartridge --with-container-uuid $APP_UUID --action add --with-cartridge-name mysql-5.1
		fi

		echo
		echo "Stopping gear..."
		oo-admin-ctl-gears stopgear $APP_UUID

		#save new ip configuration. NOTE this is pretty ugly since there's no way to figure out what is the new ip until run oo-cartridge 
		echo
		echo "Saving new mysql internal ip..."
		new_mysql_ip=$(<.env/OPENSHIFT_MYSQL_DB_HOST)

		#substitue internal ip due grant permitions 
		echo
		echo "Fixing mysql internal ip..."
		sed -i s/${new_mysql_ip}/${old_mysql_ip}/g .env/OPENSHIFT_MYSQL_DB_HOST
		sed -i s/${new_mysql_ip}/${old_mysql_ip}/g mysql/conf/my.cnf
		sed -i s/${new_mysql_ip}/${old_mysql_ip}/g mysql/env/OPENSHIFT_MYSQL_DB_URL


		#keep data dir
		echo
		echo "Moving mysql data dir..."
		if [ -d ${OPENSHIFT_BASEDIR}/$APP_UUID/mysql-5.1/data ]; then
			cp -af ${OPENSHIFT_BASEDIR}/$APP_UUID/mysql-5.1/data ${OPENSHIFT_BASEDIR}/$APP_UUID/mysql/
		fi

		#keep username and password
		echo
		echo "Setting username and password..."
		echo $openshift_mysql_db_username > mysql/env/OPENSHIFT_MYSQL_DB_USERNAME
		echo $openshift_mysql_db_password > mysql/env/OPENSHIFT_MYSQL_DB_PASSWORD
		

		#clean up old php cartridge
		if [ -d mysql-5.1 ]; then
			rm -Rf mysql-5.1
		fi

	else
		echo
		echo "No mysql-5.1 v1 cartridge detected! Nothing to do."
		exit 1
	fi 
}

migrate_postgresql() {

	cd /var/lib/openshift/$APP_UUID
	
	if [ -d postgresql-8.4 ]; then

		#remove pgpass
		echo
		echo "Removing old pgpass file..."
		rm -f .pgpass

		#remove old env vars
		echo
		echo "Cleaning up old env vars..."
		pushd .env
		openshift_postgresql_db_log_dir=$(<OPENSHIFT_POSTGRESQL_DB_LOG_DIR)
		openshift_postgresql_db_password=$(<OPENSHIFT_POSTGRESQL_DB_PASSWORD)
		openshift_postgresql_db_socket=$(<OPENSHIFT_POSTGRESQL_DB_SOCKET)
		openshift_postgresql_db_url=$(<OPENSHIFT_POSTGRESQL_DB_URL)
		openshift_postgresql_db_username=$(<OPENSHIFT_POSTGRESQL_DB_USERNAME)


		[ -f OPENSHIFT_POSTGRESQL_DB_LOG_DIR ] && rm -f OPENSHIFT_POSTGRESQL_DB_LOG_DIR
		[ -f OPENSHIFT_POSTGRESQL_DB_PASSWORD ] && rm -f OPENSHIFT_POSTGRESQL_DB_PASSWORD
		[ -f OPENSHIFT_POSTGRESQL_DB_SOCKET ] && rm -f OPENSHIFT_POSTGRESQL_DB_SOCKET
		[ -f OPENSHIFT_POSTGRESQL_DB_URL ] && rm -f OPENSHIFT_POSTGRESQL_DB_URL
		[ -f OPENSHIFT_POSTGRESQL_DB_USERNAME ] && rm -f OPENSHIFT_POSTGRESQL_DB_USERNAME

		popd

		echo
		echo "Creating postgresql-8.4 v2 cartridge..."
		if [ ! -d ${OPENSHIFT_BASEDIR}/$APP_UUID/postgresql ]; then
			oo-cartridge --with-container-uuid $APP_UUID --action add --with-cartridge-name postgresql-8.4
		fi

		echo
		echo "Stopping gear..."
		oo-admin-ctl-gears stopgear $APP_UUID

		echo 
		echo "Moving data dir..."
		if [ -d postgresql-8.4/data ]; then
			if [ -d postgresql/data ]; then 
				mv postgresql/data postgresql/data_
			fi
			cp -af postgresql-8.4/data postgresql/
		fi

		echo
		echo "Setting up conf files..."

		echo ".pgpass..."
		cat << EOF > .pgpass
*:*:*:${openshift_postgresql_db_username}:${openshift_postgresql_db_password}
EOF

		echo "pg_hba.conf..."
		cp -af postgresql/data_/pg_hba.conf postgresql/data/

		echo "postgresql.conf..."
		cp -af postgresql/data_/postgresql.conf postgresql/data/

		#keep username and password
		echo
		echo "Setting username and password..."
		
		echo $openshift_postgresql_db_username  > postgresql/env/OPENSHIFT_POSTGRESQL_DB_USERNAME
		echo $openshift_postgresql_db_username  > postgresql/env/PGUSER
		echo $openshift_postgresql_db_password > postgresql/env/OPENSHIFT_POSTGRESQL_DB_PASSWORD
		echo $openshift_postgresql_db_url > postgresql/env/OPENSHIFT_POSTGRESQL_DB_URL

			#clean up old php cartridge
	if [ -d postgresql-8.4 ]; then
		rm -Rf postgresql-8.4
	fi
	else
		echo
		echo "No postgresql-8.4 v1 cartridge detected! Nothing to do."
		exit 1
fi 

}


migrate_mongodb() {

	cd /var/lib/openshift/$APP_UUID
	
	if [ -d mongodb-2.2 ]; then

		#remove old env vars
		echo
		echo "Cleaning up old env vars..."
		pushd .env

		openshift_mongo_db_log_dir=$(<OPENSHIFT_MONGODB_DB_LOG_DIR)
		openshift_mongo_db_password=$(<OPENSHIFT_MONGODB_DB_PASSWORD)
		openshift_mongo_db_url=$(<OPENSHIFT_MONGODB_DB_URL)
		openshift_mongo_db_username=$(<OPENSHIFT_MONGODB_DB_USERNAME)


		[ -f OPENSHIFT_MONGODB_DB_LOG_DIR ] && rm -f OPENSHIFT_MONGODB_DB_LOG_DIR
		[ -f OPENSHIFT_MONGODB_DB_PASSWORD ] && rm -f OPENSHIFT_MONGODB_DB_PASSWORD
		[ -f OPENSHIFT_MONGODB_DB_URL ] && rm -f OPENSHIFT_MONGODB_DB_URL
		[ -f OPENSHIFT_MONGODB_DB_USERNAME ] && rm -f OPENSHIFT_MONGODB_DB_USERNAME

		popd		

		echo
		echo "Creating mongodb-2.2 v2 cartridge..."
		if [ ! -d ${OPENSHIFT_BASEDIR}/$APP_UUID/mongodb ]; then
			oo-cartridge --with-container-uuid $APP_UUID --action add --with-cartridge-name mongodb-2.2
		fi

		echo
		echo "Stopping gear..."
		oo-admin-ctl-gears stopgear $APP_UUID

		echo 
		echo "Moving data dir..."
		if [ -d mongodb-2.2/data ]; then
			if [ -d mongodb/data ]; then 
				rm -Rf mongodb/data
			fi
			cp -af mongodb-2.2/data mongodb/
		fi	

		#keep username and password
		echo
		echo "Setting username and password..."
		echo $openshift_mongo_db_username > mongodb/env/OPENSHIFT_MONGODB_DB_USERNAME
		echo $openshift_mongo_db_password > mongodb/env/OPENSHIFT_MONGODB_DB_PASSWORD
		echo $openshift_mongo_db_url > mongodb/env/OPENSHIFT_MONGODB_DB_URL
		
		#clean up old php cartridge
		if [ -d mongodb-2.2 ]; then
			rm -Rf mongodb-2.2
		fi

	else
		echo
		echo "No mongodb-2.2 v1 cartridge detected! Nothing to do."
		exit 1
	fi 
}

while :
do
	case $1 in
		-h | --help | -\?)
			usage
			exit 0
			;;
		-n)
			APP_NAMESPACE=$2
			shift 2
			;;
		-a)
			APP_UUID=$2
			shift 2
			;;
		-m)
			APP_NAME=$2
			shift 2
			;;
		-c)
			CARTRIDGE=$2
			shift 2
			;;
		-u)
			DBUSERNAME=$2
			shift 2
			;;
		-p)
			DBPASSWORD=$2
			shift 2
			;;
		*)
			break
			;;
	esac
done

if [ ! "$APP_NAMESPACE" ]; then
		echo "ERROR: option -n not given. See --help" 
		exit 1
fi

if [ ! "$APP_UUID" ]; then
		echo "ERROR: option -a not given. See --help" 
		exit 1
fi

if [ ! "$APP_NAME" ]; then
		echo "ERROR: option -m not given. See --help" 
		exit 1
fi

if [ ! "$CARTRIDGE" ]; then
		echo "ERROR: option -c not given. See --help" 
		exit 1
fi


case $CARTRIDGE in
	php-5.3)
		migrate_common
		migrate_php
		;;
	mysql-5.1)
		migrate_mysql
		;;
	postgresql-8.4)
		migrate_postgresql
		;;
	mongodb-2.2)
		migrate_mongodb
		;;
	*)
		echo "Invalid cartridge type."
		;;
esac