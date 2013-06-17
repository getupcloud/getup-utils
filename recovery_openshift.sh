#!/bin/bash


#Script used to recreate user and group based on /var/lib/openshift directory.
#More information regarding node recovery: https://access.redhat.com/site/documentation/en-US/OpenShift_Enterprise/1/html/Administration_Guide/sect-OpenShift_Enterprise-Administration_Guide-Recovering_Failed_Node_Hosts.html


set -x

OPENSHIFT_MOUNTPOINT="/var/lib/openshift"
GEAR_GECOS="OpenShift guest"
GEAR_SHELL="/usr/bin/oo-trap-user"
GEAR_SKEL_DIR="/etc/openshift/skel"

if [ -d $OPENSHIFT_MOUNTPOINT ]; then
	echo "OPENSHIFT_MOUNTPOINT is invalid..."
	exit 1
fi

cd $OPENSHIFT_MOUNTPOINT

for i in `ls`
 do
	uid=$(stat -c "%g" $i)
	name=$(stat -c "%n" $i)
	if [ $uid -ne 0 ]; then
		useradd -u $uid -d ${OPENSHIFT_MOUNTPOINT}/${name} -s $GEAR_SHELL -c '$GEAR_GECOS' -M $name
	fi
done
