#!/bin/bash
#
# For each dir on /var/lib/openshift, recreates missing users based on GID of the dir.
# This script is intended to be run on a node disaster recovery. It assumes you have a clean
# /etc/passwd where OpenShift users are missing (mostly because your node was destroyed and you
# are mouting /var/lib/openshift on an EBS under a new node).
#
# Please reffer to [OpenShift Enterprise - Administration_Guide](https://access.redhat.com/site/documentation/en-US/OpenShift_Enterprise/1/html/Administration_Guide/sect-OpenShift_Enterprise-Administration_Guide-Recovering_Failed_Node_Hosts.html)
# for more information regarding node recovery.
#

set -e

OPENSHIFT_MOUNTPOINT="/var/lib/openshift"
GEAR_GECOS="OpenShift guest"
GEAR_SHELL="/usr/bin/oo-trap-user"
GEAR_SKEL_DIR="/etc/openshift/skel"

function create_oo_user()
{
    echo -n Recreating Openshift user $2 with UID=$1
    /usr/sbin/useradd "$2" -u "$1" -d "$OPENSHIFT_MOUNTPOINT/$2" -s "$GEAR_SHELL" -c "$GEAR_GECOS" -M
    echo " -> OK"
}

cd $OPENSHIFT_MOUNTPOINT

for USER_NAME in *
do
    if [ -d "$USER_NAME" ]; then
        USER_ID=$(stat -c '%g' "$USER_NAME")
	if [ -n "$USER_ID" -a "$USER_ID" -ne 0 ]; then
	    /usr/bin/id "$USER_NAME" &>/dev/null || create_oo_user "$USER_ID" "$USER_NAME"
	fi
    fi
done
