Custom Metrics for CloudWatch
=============================

These scripts are used for AWS CloudWatch monitoring.

broker_custom_metrics:
Retrieve statistcs from oo-stats module and put data to cloudwatch:

Applications: Total applications running on OpenShift Cluster
Gears: Total gears running on Openshift Cluster

Instalation:

1-) We don't cover install and configuration of OpenShift Origin, you should take a look at: http://openshift.github.io/origin/file.install_origin_using_puppet.html
2-) With your Broker running, install CloudWatch Command Line Tool: http://aws.amazon.com/developertools/2534
3-) Copy the script to /etc/cron.daily/ and make it executable 


node_custom_metrics:
Retrieve statics via PuppetLabs Facter and put data to cloudwatch:
Active Gears: Total of gears running on node

Instalation:
1-) We don't cover install and configuration of OpenShift Origin, you should take a look at: http://openshift.github.io/origin/file.install_origin_using_puppet.html
2-) With your Node running, install CloudWatch Command Line Tool: http://aws.amazon.com/developertools/2534
3-) Copy the script to /etc/cron.daily/ and make it executable 



Atention!
These scripts was only tested on Openshift Origin Release 1 and RHEL 6.4.