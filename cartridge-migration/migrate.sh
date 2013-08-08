#!/bin/bash

set -e

OPENSHIFT_BASEDIR=/var/lib/openshift
CLEANUP=0

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
   -z      Clean up v1 cartridge directory (default no)
EOF
}

enable_cgroups()
{
	#enable cgroups
	echo
	echo "Enabling Cgroups..."
	/usr/bin/oo-cgroup-enable -c $APP_UUID	
}

migrate_common()
{

	enable_cgroups	

	cd /var/lib/openshift/$APP_UUID


	cd .env
	#remove old env vars
	echo
	echo "Removing old env vars..."
	[ -f USER_VARS ] && rm -f USER_VARS
	[ -d .uservars ] && rm -Rf .uservars
	#[ -f OPENSHIFT_INTERNAL_IP ] && rm -f OPENSHIFT_INTERNAL_IP
	#[ -f OPENSHIFT_INTERNAL_PORT ] && rm -f OPENSHIFT_INTERNAL_PORT

	#convert vars for new model
	echo
	echo "Converting env vars to new format..."
	for i in `grep -l ^export *`; do source $i; eval echo -n \$$i > $i; done

	#create missing env vars
	echo
	echo "Creating APP_NAMESPACE env var..."
	echo -n  $APP_NAMESPACE > OPENSHIFT_NAMESPACE
	chcon -u system_u -r object_r -t openshift_var_lib_t *

	#Log env_vars
	echo
	echo "Logging env vars..."
	for i in *; do echo -n "${i}:"; cat $i; echo; done

	cd - 


	#fix git hooks
	echo
	echo "Fixing git hooks..."

  if [ -d ${OPENSHIFT_BASEDIR}/${APP_UUID}/git/${APP_NAME}.git ]; then
		[ -f ${OPENSHIFT_BASEDIR}/${APP_UUID}/git/${APP_NAME}.git/hooks/pre-receive ] 	&& echo "gear prereceive" 	> ${OPENSHIFT_BASEDIR}/${APP_UUID}/git/${APP_NAME}.git/hooks/pre-receive
		[ -f ${OPENSHIFT_BASEDIR}/${APP_UUID}/git/${APP_NAME}.git/hooks/post-receive ] 	&& echo "gear postreceive" 	> ${OPENSHIFT_BASEDIR}/${APP_UUID}/git/${APP_NAME}.git/hooks/post-receive
	else
		[ -f ${OPENSHIFT_BASEDIR}/${APP_UUID}/git/${APP_UUID}.git/hooks/pre-receive ] 	&& echo "gear prereceive" 	> ${OPENSHIFT_BASEDIR}/${APP_UUID}/git/${APP_UUID}.git/hooks/pre-receive
		[ -f ${OPENSHIFT_BASEDIR}/${APP_UUID}/git/${APP_UUID}.git/hooks/post-receive ] 	&& echo "gear postreceive" 	> ${OPENSHIFT_BASEDIR}/${APP_UUID}/git/${APP_UUID}.git/hooks/post-receive
	fi
}


migrate_web()

{

	cd /var/lib/openshift/$APP_UUID
	
	v2_cart_name=$(echo $1 | cut -d- -f 1)
	cap_v2_cart_name=$(echo $v2_cart_name | tr '[a-z]' '[A-Z]')

	if [ -d $1 ] || [ -d "nodejs-0.6" ]; then
		echo
		echo "$1 v1 cartridge detected..."

		#remove old env var
		cd .env
		case $1 in
			php-5.3)
				[ -f OPENSHIFT_PHP_LOG_DIR ] && rm -f OPENSHIFT_PHP_LOG_DIR
				;;
			python-2.6)
				[ -f OPENSHIFT_PYTHON_LOG_DIR ] && rm -f OPENSHIFT_PYTHON_LOG_DIR
				;;
			python-2.7)
				[ -f OPENSHIFT_PYTHON_LOG_DIR ] && rm -f OPENSHIFT_PYTHON_LOG_DIR
				[ -f OPENSHIFT_SYNC_GEARS_DIRS ] && rm -f OPENSHIFT_SYNC_GEARS_DIRS
				;;
			ruby-1.8)
				[ -f OPENSHIFT_RUBY_LOG_DIR ] && rm -f OPENSHIFT_RUBY_LOG_DIR
				;;
			ruby-1.9)
				[ -f OPENSHIFT_RUBY_LOG_DIR ] && rm -f OPENSHIFT_RUBY_LOG_DIR
				[ -f MANPATH ] && rm -f MANPATH
				[ -f LD_LIBRARY_PATH ] && rm -f LD_LIBRARY_PATH
				;;
			nodejs-0.10)
				[ -f OPENSHIFT_NODEJS_LOG_DIR ] && rm -f OPENSHIFT_NODEJS_LOG_DIR
				;;
			jbossews-1.0)
				[ -f OPENSHIFT_JBOSSEWS_LOG_DIR ] && rm -f OPENSHIFT_JBOSSEWS_LOG_DIR
				[ -f M2_HOME ] && rm -f M2_HOME
				[ -f JAVA_HOME ] && rm -f JAVA_HOME
				;;
			jbossews-2.0)
				[ -f OPENSHIFT_JBOSSEWS_LOG_DIR ] && rm -f OPENSHIFT_JBOSSEWS_LOG_DIR
				[ -f M2_HOME ] && rm -f M2_HOME
				[ -f JAVA_HOME ] && rm -f JAVA_HOME
				;;
			diy-0.1)
				[ -f OPENSHIFT_DIY_LOG_DIR ] && rm -f OPENSHIFT_DIY_LOG_DIR
				;;
			haproxy-1.4)
				[ -f OPENSHIFT_HAPROXY_LOG_DIR ] && rm -f OPENSHIFT_HAPROXY_LOG_DIR
				old_haproxy_ip=$(<OPENSHIFT_HAPROXY_INTERNAL_IP)
				old_haproxy_status_ip=$(<OPENSHIFT_HAPROXY_STATUS_IP)
				;;
		esac
		cd -

		#Remove old python directoy before add new one
		if [ $1 = 'python-2.6' -o $1 = 'python-2.7' ]; then
			rm -Rf $1
		fi

		#Web cartridges upgrade.
		echo
		echo "Creating $1 v2 cartridge..."
		if [ ! -d ${OPENSHIFT_BASEDIR}/$APP_UUID/${v2_cart_name} ]; then
			oo-cartridge --with-container-uuid $APP_UUID --action add --with-cartridge-name $1
		fi

		#Keep old env vars for ip and port

		if [ ! $1 = 'haproxy-1.4' ]; then
		echo
		echo "Keeping old env vars for ip and port..."
		[ -f .env/OPENSHIFT_${cap_v2_cart_name}_IP ] && cat .env/OPENSHIFT_${cap_v2_cart_name}_IP > .env/OPENSHIFT_INTERNAL_IP
		[ -f .env/OPENSHIFT_${cap_v2_cart_name}_PORT ] && cat .env/OPENSHIFT_${cap_v2_cart_name}_PORT > .env/OPENSHIFT_INTERNAL_PORT	
		fi

		#Virtual env should be recreated
		if [ $1 = 'python-2.6' -o $1 = 'python-2.7' ]; then
		echo 
		echo "Running postreceive for virtualenv..."
			/usr/sbin/oo-su $APP_UUID -c "/usr/bin/gear build && /usr/bin/gear deploy" || true
		fi

		if [ $1 = 'ruby-1.9' -o  $1 = 'ruby-1.8' ]; then
			echo
			echo "Rebuilding ruby gear..."
			/usr/sbin/oo-su $APP_UUID -c "/usr/bin/gear deploy" || true
		fi
		
		if [ $1 = 'jbossews-1.0' -o  $1 = 'jbossews-2.0' ]; then
			echo
			echo "Rebuilding ruby gear..."
			/usr/sbin/oo-su $APP_UUID -c "/usr/bin/gear deploy" || true
		fi

		#php gear rebuild
		if [ $1 = 'php-5.3' ]; then
		echo 
		echo "Rebuilding gear..."
			 /usr/sbin/oo-su $APP_UUID -c "/usr/bin/gear deploy" || true
		fi

		if [ $1 = 'nodejs-0.10' ]; then
			echo
			echo "Installing modules for nodejs..."
			/usr/sbin/oo-su $APP_UUID -c "rm -Rf ~/app-root/repo/node_modules; /usr/bin/gear deploy" || true
		fi

		if [ $1 = 'haproxy-1.4' ]; then

				#keep ssh keys
				[ -f haproxy-1.4/.ssh/haproxy_id_rsa ] && cat haproxy-1.4/.ssh/haproxy_id_rsa > .openshift_ssh/id_rsa
				[ -f haproxy-1.4/.ssh/haproxy_id_rsa.pub ] && cat haproxy-1.4/.ssh/haproxy_id_rsa.pub > .openshift_ssh/id_rsa.pub

				#keep gear_registry
				[ -f haproxy-1.4/conf/gear-registry.db ] && cat haproxy-1.4/conf/gear-registry.db > haproxy/conf/gear-registry.db


				#config file
				new_haproxy_ip=$(<.env/OPENSHIFT_HAPROXY_IP)
				new_haproxy_status_ip=$(<.env/OPENSHIFT_HAPROXY_STATUS_IP)

				[ -f haproxy-1.4/conf/haproxy.cfg ] && cat haproxy-1.4/conf/haproxy.cfg > haproxy/conf/haproxy.cfg

				#fix config file

				sed -i "s/${old_haproxy_ip}/${new_haproxy_ip}/g" haproxy/conf/haproxy.cfg
				sed -i "s/${old_haproxy_status_ip}/${new_haproxy_status_ip}/g" haproxy/conf/haproxy.cfg

		fi

		#fix local-gear endpoint

		if [ -d haproxy -a ! $1 = 'haproxy-1.4' ]; then


			#get local gear ip and port
			local_ip=$(<.env/OPENSHIFT_INTERNAL_IP)
			local_port=$(<.env/OPENSHIFT_INTERNAL_PORT)

			local_ep=$local_ip:$local_port

			#fix config file
	    sed -i "/\s*server\s*local-gear\s.*/d" haproxy/conf/haproxy.cfg
	    echo "	server local-gear $local_ep maxconn 2 check fall 2 rise 3 inter 2000 cookie local-$APP_UUID" >> haproxy/conf/haproxy.cfg

	    sed -i "s/haproxy-1.4/haproxy/g" haproxy/conf/haproxy.cfg

	    [ -f .env/OPENSHIFT_PRIMARY_CARTRIDGE_DIR ] && sed -i "s/haproxy/${v2_cart_name}/" .env/OPENSHIFT_PRIMARY_CARTRIDGE_DIR 
		fi

		echo
		echo "Stopping gear..."
		[ -f app-root/runtime/.stop_lock ] && rm -f app-root/runtime/.stop_lock
		oo-admin-ctl-gears stopgear $APP_UUID

		#clean up old cartridge
		if [ -d $1 -a $CLEANUP = 1 ]; then
			rm -Rf $1 && echo; echo "All good!"
		fi 
	else 
		echo
		echo "No $1 v1 cartridge detected! Nothing to do."
		exit 1
	fi
}

migrate_mysql()
{

	if [ -d mysql-5.1 ]; then

		cd .env

		#save the old ip configuration due grant access

	
		[ -f OPENSHIFT_MYSQL_DB_LOG_DIR ] 	&& openshift_mysql_db_log_dir=$(<OPENSHIFT_MYSQL_DB_LOG_DIR) 		&& rm -f OPENSHIFT_MYSQL_DB_LOG_DIR
		[ -f OPENSHIFT_MYSQL_DB_HOST ] 			&& old_mysql_ip=$(<OPENSHIFT_MYSQL_DB_HOST) 										&& rm -f OPENSHIFT_MYSQL_DB_HOST		
		[ -f OPENSHIFT_MYSQL_DB_PASSWORD ] 	&& openshift_mysql_db_password=$(<OPENSHIFT_MYSQL_DB_PASSWORD) 	&& rm -f OPENSHIFT_MYSQL_DB_PASSWORD
		[ -f OPENSHIFT_MYSQL_DB_URL ] 			&& openshift_mysql_db_url=$(<OPENSHIFT_MYSQL_DB_URL) 						&& rm -f OPENSHIFT_MYSQL_DB_URL
		[ -f OPENSHIFT_MYSQL_DB_SOCKET ] 		&& openshift_mysql_db_socket=$(<OPENSHIFT_MYSQL_DB_SOCKET) 			&& rm -f OPENSHIFT_MYSQL_DB_SOCKET
		[ -f OPENSHIFT_MYSQL_DB_USERNAME ] 	&& openshift_mysql_db_username=$(<OPENSHIFT_MYSQL_DB_USERNAME) 	&& rm -f OPENSHIFT_MYSQL_DB_USERNAME

		cd -


		echo
		echo "Creating mysql-5.1 v2 cartridge..."
		if [ ! -d ${OPENSHIFT_BASEDIR}/$APP_UUID/mysql ]; then
			oo-cartridge --with-container-uuid $APP_UUID --action add --with-cartridge-name mysql-5.1
		fi

		echo
		echo "Stopping gear..."
		[ -f app-root/runtime/.stop_lock ] && rm -f app-root/runtime/.stop_lock
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
		echo "Setting env vars..."
		echo $openshift_mysql_db_username > mysql/env/OPENSHIFT_MYSQL_DB_USERNAME
		echo $openshift_mysql_db_password > mysql/env/OPENSHIFT_MYSQL_DB_PASSWORD
		echo "mysql://${openshift_mysql_db_username}:${openshift_mysql_db_password}@${old_mysql_ip}/" > mysql/env/OPENSHIFT_MYSQL_DB_URL
		

		#clean up old cartridge
		if [ -d mysql-5.1 -a $CLEANUP = 1 ]; then
			rm -Rf mysql-5.1
		fi
	else
		echo
		echo "No mysql-5.1 v1 cartridge detected! Nothing to do."
		exit 1
	fi 
}

migrate_postgresql() {

	
	if [ -d postgresql-8.4 ]; then

		#remove pgpass
		echo
		echo "Removing old pgpass file..."
		rm -f .pgpass

		#remove old env vars
		echo
		echo "Cleaning up old env vars..."
		cd .env
		
		[ -f OPENSHIFT_POSTGRESQL_DB_LOG_DIR ] 	&& openshift_postgresql_db_log_dir=$(<OPENSHIFT_POSTGRESQL_DB_LOG_DIR) 		&& rm -f OPENSHIFT_POSTGRESQL_DB_LOG_DIR
		[ -f OPENSHIFT_POSTGRESQL_DB_SOCKET ] 	&& openshift_postgresql_db_socket=$(<OPENSHIFT_POSTGRESQL_DB_SOCKET) 			&& rm -f OPENSHIFT_POSTGRESQL_DB_SOCKET
		[ -f OPENSHIFT_POSTGRESQL_DB_URL ] 			&& openshift_postgresql_db_url=$(<OPENSHIFT_POSTGRESQL_DB_URL) 						&& rm -f OPENSHIFT_POSTGRESQL_DB_URL
		[ -f OPENSHIFT_POSTGRESQL_DB_USERNAME ] && openshift_postgresql_db_username=$(<OPENSHIFT_POSTGRESQL_DB_USERNAME) 	&& rm -f OPENSHIFT_POSTGRESQL_DB_USERNAME
		[ -f OPENSHIFT_POSTGRESQL_DB_PASSWORD ] && openshift_postgresql_db_password=$(<OPENSHIFT_POSTGRESQL_DB_PASSWORD) 		&& rm -f OPENSHIFT_POSTGRESQL_DB_PASSWORD
		
		cd -

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
		echo $openshift_postgresql_db_password 	> postgresql/env/OPENSHIFT_POSTGRESQL_DB_PASSWORD
		echo $openshift_postgresql_db_url 			> postgresql/env/OPENSHIFT_POSTGRESQL_DB_URL

			#clean up old cartridge
	if [ -d postgresql-8.4 -a $CLEANUP = 1 ]; then
		rm -Rf postgresql-8.4
		rm -Rf postgresql/data_
	fi
	else
		echo
		echo "No postgresql-8.4 v1 cartridge detected! Nothing to do."
		exit 1
fi 

}


migrate_mongodb() {

	
	if [ -d mongodb-2.2 ]; then

		#remove old env vars
		echo
		echo "Cleaning up old env vars..."
		cd .env

		[ -f OPENSHIFT_MONGODB_DB_LOG_DIR ]		&& openshift_mongo_db_log_dir=$(<OPENSHIFT_MONGODB_DB_LOG_DIR) 		&& rm -f OPENSHIFT_MONGODB_DB_LOG_DIR
		[ -f OPENSHIFT_MONGODB_DB_PASSWORD ]	&& openshift_mongo_db_password=$(<OPENSHIFT_MONGODB_DB_PASSWORD)  && rm -f OPENSHIFT_MONGODB_DB_PASSWORD
		[ -f OPENSHIFT_MONGODB_DB_URL ]				&& openshift_mongo_db_url=$(<OPENSHIFT_MONGODB_DB_URL) 						&& rm -f OPENSHIFT_MONGODB_DB_URL
		[ -f OPENSHIFT_MONGODB_DB_USERNAME ]	&& openshift_mongo_db_username=$(<OPENSHIFT_MONGODB_DB_USERNAME)  && rm -f OPENSHIFT_MONGODB_DB_USERNAME

		cd -		

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
				mv mongodb/data mongodb/data_
			fi
			cp -af mongodb-2.2/data mongodb/
		fi	

		#keep username and password
		echo
		echo "Setting username and password..."
		echo $openshift_mongo_db_username > mongodb/env/OPENSHIFT_MONGODB_DB_USERNAME
		echo $openshift_mongo_db_password > mongodb/env/OPENSHIFT_MONGODB_DB_PASSWORD
		echo $openshift_mongo_db_url > mongodb/env/OPENSHIFT_MONGODB_DB_URL
		
		#clean up old cartridge
		if [ -d mongodb-2.2 -a $CLEANUP = 1 ]; then
			rm -Rf mongodb-2.2
			rm -Rf mongo/data_
		fi

	else
		echo
		echo "No mongodb-2.2 v1 cartridge detected! Nothing to do."
		exit 1
	fi 
}


migrate_phpmyadmin() {

	if [ -d phpmyadmin-3.4 ]; then
		#remove old env vars
		echo
		echo "Cleaning up old env vars..."
		cd .env

		[ -f OPENSHIFT_PHPMYADMIN_IP ] && rm -f OPENSHIFT_PHPMYADMIN_IP
		[ -f OPENSHIFT_PHPMYADMIN_LOG_DIR ] && rm -f OPENSHIFT_PHPMYADMIN_LOG_DIR
		[ -f OPENSHIFT_PHPMYADMIN_PORT ] && rm -f OPENSHIFT_PHPMYADMIN_PORT

		cd -

		echo
		echo "Creating phpmyadmin v2 cartridge..."
		if [ ! -d ${OPENSHIFT_BASEDIR}/$APP_UUID/phpmyadmin ]; then
			oo-cartridge --with-container-uuid $APP_UUID --action add --with-cartridge-name phpmyadmin-3.4
		fi		


		#clean up old cartridge
		if [ -d phpmyadmin-3.4 -a -n $CLEANUP ]; then
			rm -Rf phpmyadmin-3.4
		fi
	else
		echo
		echo "No phpmyadmin-3.4 v1 cartridge detected! Nothing to do."
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
		-z)
			CLEANUP=1
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
	haproxy-1.4)
		migrate_common
		migrate_web haproxy-1.4
		;;
	php-5.3)
		migrate_common
		migrate_web php-5.3
		;;
	python-2.6)
		migrate_common
		migrate_web python-2.6
		;;
	python-2.7)
		migrate_common
		migrate_web python-2.7
		;;
	nodejs-0.10)
		migrate_common
		migrate_web nodejs-0.10
		;;		
	ruby-1.8)
		migrate_common
		migrate_web ruby-1.8
		;;
	ruby-1.9)
		migrate_common
		migrate_web ruby-1.9
		;;
	jbossews-1.0)
		migrate_common
		migrate_web jbossews-1.0
		;;
	jbossews-2.0)
		migrate_common
		migrate_web jbossews-2.0
		;;
	diy-0.1)
		migrate_common
		migrate_web diy-0.1
		;;
	cron-1.4)
		migrate_web cron-1.4
		;;						
	mysql-5.1)
		migrate_common
		migrate_mysql
		;;
	postgresql-8.4)
		migrate_common
		migrate_postgresql
		;;
	mongodb-2.2)
		migrate_common
		migrate_mongodb
		;;
	phpmyadmin-3.4)
		migrate_phpmyadmin
		;;
	*)
		echo "Invalid cartridge type."
		;;
esac