#!/bin/bash


GEAR_BASE_DIR=/var/lib/openshift

for i in ${GEAR_BASE_DIR}/*; do

	pushd $i

	owner=`ls -l | grep app-root | awk '{print $4}'`

	mkdir app-deployments
	mkdir app-root/runtime/dependencies
	mkdir app-root/runtime/build-dependencies

	chown $owner.$owner -R app-root/runtime/dependencies
	chown $owner.$owner -R app-root/runtime/build-dependencies
	chown $owner.$owner -R app-deployments


	chmod 0755 -R app-deployments 

	pushd app-root/

	
	ln -s runtime/dependencies dependencies
	ln -s runtime/build-dependencies build-dependencies


	popd
done



