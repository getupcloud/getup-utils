#!/bin/bash


GEAR_BASE_DIR=/var/lib/openshift


for i in ${GEAR_BASE_DIR}/*; do

	pushd $i
	if [ -d "haproxy" ]; then

	namespace=$(<.env/OPENSHIFT_NAMESPACE)
	gear_uuid=$(<.env/OPENSHIFT_GEAR_UUID)
	dns=$(<.env/OPENSHIFT_GEAR_DNS)
	proxy_port=$(<.env/OPENSHIFT_*_PROXY_PORT)
	hostname=`hostname`

	owner=`ls -l | grep app-root | awk '{print $4}'`
	mkdir gear-registry
		
	cat > gear-registry/gear-registry.json <<-EOF
	{
	"web": {
		"${gear_uuid}": {
			"namespace":"${namespace}",
			"dns":"${dns}",
			"proxy_hostname": "${hostname}",
			"proxy_port": "${proxy_port}"
		}
	},
        "proxy": {
                "${gear_uuid}": {
                        "namespace":"${namespace}",
                        "dns":"${dns}",
                        "proxy_hostname": "${hostname}",
                        "proxy_port": "0"
                }
        }}
	EOF
	cp gear-registry/gear-registry.json gear-registry/gear-registry.json.bak
	touch gear-registry/gear-registry.lock

	chmod 644 gear-registry/*
	chgrp $owner gear-registry/*
	chown $owner.$owner gear-registry/gear-registry.lock
	fi
	popd
done