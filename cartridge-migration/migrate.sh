#!/bin/bash

set -ex

#Php-5.3 v1 cartridges upgrade.

APP_UUID=$1
APP_NAMESPACE=$2
APP_NAME=$3
OPENSHIFT_BASEDIR=/var/lib/openshift


if [ -d ${OPENSHIFT_BASEDIR}/$APP_UUID/php-5.3 ] && [ ! -d ${OPENSHIFT_BASEDIR}/$APP_UUID/php ]; then
	oo-cartridge --with-container-uuid $APP_UUID --action add --with-cartridge-name php-5.3
fi

cd /var/lib/openshift/$APP_UUID


pushd .env

#remove old env vars
rm -f USER_VARS
rm -f OPENSHIFT_INTERNAL_IP
rm -f OPENSHIFT_INTERNAL_PORT
rm -f OPENSHIFT_PHP_LOG_DIR

#convert vars for new model
for i in `grep -l ^export *`; do source $i; eval echo -n \$$i > $i; done

#create missing env vars
echo -n  $APPNAMESPACE > OPENSHIFT_NAMESPACE
chcon -u system_u -r object_r -t openshift_var_lib_t *

popd

#fix git hooks
echo "gear prereceive" > /var/lib/openshift/$APP_UUID/git/${APP_NAME}.git/hooks/pre-receive
echo "gear postreceive" > /var/lib/openshift/$APP_UUID/git/${APP_NAME}.git/hooks/post-receive


#clean up old php cartridge
if [ -d php-5.3 ]; then
	rm -Rf php-5.3
fi








