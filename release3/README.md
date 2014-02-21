# Openshift Origin Release 3 upgrade tool

These scripts itend to migrate  Openshift Origin Release 2
Origin Releases doesn't have upgrade support, so you have to run scripts to convert the mongo datastore document.


- Create a full backup of your system
- Upgrade the packages using yum
- Run the scripts on the order below:

 On broker:
 ./fix_domains.rb
 ./fix_applications.rb

 On node:
 ./fix_deployments.sh
 ./fix_gear_registry.sh
 ./migrate_port_proxy.sh
 

 Back on broker:
 oo-admin-upgrade upgrade-node --version=3


 The last script will update each running gear to the latest version.

Know Issues

 Mysql cartridges has two bugs:
 - InnoDB Engine couldn't startup due my.cnf changes, just delete /var/lib/openshift/GEAR_UUID/mysq/data/ib_logfile0 , /var/lib/openshift/GEAR_UUID/mysq/data/ib_logfile1 and restart the gear.

 - Scaled applications couldn't connect to mysql due grant permission. Since port proxy is handled by iptables we need change the host.
  SSH into the gear and run:
  echo "GRANT ALL ON *.* TO '$OPENSHIFT_MYSQL_DB_USERNAME'@'%' IDENTIFIED BY '$OPENSHIFT_MYSQL_DB_PASSWORD' WITH GRANT OPTION" | /usr/bin/mysql -h $OPENSHIFT_MYSQL_DB_HOST -P $OPENSHIFT_MYSQL_DB_PORT -u $OPENSHIFT_MYSQL_DB_USERNAME --password="$OPENSHIFT_MYSQL_DB_PASSWORD" --skip-column-names


