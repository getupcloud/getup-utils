Custom Metrics for CloudWatch
=============================

The following scripts collect OpenShift statistics and feed AWS CloudWatch metrics.

It was tested only on Openshift Origin Release 1 under RHEL 6.4.

Instalation
---

First you will need an up and running [Openshift Origin installation](http://openshift.github.io/origin/file.install_origin_using_puppet.html).

Install [CloudWatch Command Line Tool](http://aws.amazon.com/developertools/2534) on each of your nodes and broker instances.

Copy the scripts to your cron:

```bash
$ install cloudwatch/*{sh,rb} /etc/cron.daily/
```

Available scripts
---

broker_custom_metrics.rb
----

Retrieve statistcs using oo-stats module. It is intended to run on a broker instance.

The following metrics should appear on CloudWatch under namespace **Openshift**:

* Applications: Total applications running on OpenShift Cluster
* Gears: Total gears running on Openshift Cluster

node_custom_metrics.sh
----

Retrieve statics via PuppetLabs Facter. It is intended to run on a node instance.

The following metrics should appear on CloudWatch under namespace **Openshift**:

* Active Gears: Total of gears running on node
