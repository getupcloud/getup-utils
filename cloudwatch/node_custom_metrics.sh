#!/bin/bash

INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id`

source /etc/profile

/opt/cloudwatch/bin/mon-put-data -u Count --metric-name ActiveGears --namespace "Openshift" \
    --value `scl enable ruby193 "facter gears_active_count"` -d InstanceId=$INSTANCE_ID
