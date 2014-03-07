#!/bin/bash
cat /var/lib/openshift/.httpd.d/routes.json.rpmsave	> /var/lib/openshift/.httpd.d/routes.json
cat /var/lib/openshift/.httpd.d/nodes.txt.rpmsave > /var/lib/openshift/.httpd.d/nodes.txt
cat /var/lib/openshift/.httpd.d/nodes.db.rpmsave > /var/lib/openshift/.httpd.d/nodes.db
cat /var/lib/openshift/.httpd.d/geardb.json.rpmsave > /var/lib/openshift/.httpd.d/geardb.json
cat /var/lib/openshift/.httpd.d/aliases.txt.rpmsave > /var/lib/openshift/.httpd.d/aliases.txt
cat /var/lib/openshift/.httpd.d/aliases.db.rpmsave 	> /var/lib/openshift/.httpd.d/aliases.db
cat /etc/httpd/conf.d/openshift_route.include.rpmsave > /etc/httpd/conf.d/openshift_route.include