#!/bin/bash

migrate_all() {
    echo "Migrating all ports"
    sed -r -n -e 's/^listen ([0-9]+):([0-9.]+):([0-9]+)/\1 \2 \3/ p' /etc/openshift/port-proxy.cfg | {
        while read port daddr dport
        do
            echo $port $daddr:$dport
            oo-iptables-port-proxy addproxy $port $daddr:$dport
        done
    }
}

migrate_web() {
    echo "Migrating all ports except mysql/postgresql"
    sed -r -n -e 's/^listen ([0-9]+):([0-9.]+):([0-9]+)/\1 \2 \3/ p' /etc/openshift/port-proxy.cfg | {
        while read port daddr dport
        do
            echo $port $daddr:$dport
            if [ "$dport" == "3306" -o "$dport" == "5432" ]; then
                true
            else
                oo-iptables-port-proxy addproxy $port $daddr:$dport
            fi
        done
    }
}

migrate_dbs() {
    echo "Migrating mysql/postgresql ports"
    sed -r -n -e 's/^listen ([0-9]+):([0-9.]+):([0-9]+)/\1 \2 \3/ p' /etc/openshift/port-proxy.cfg | {
        while read port daddr dport
        do
            echo $port $daddr:$dport
            if [ "$dport" == "3306" -o "$dport" == "5432" ]; then
                oo-iptables-port-proxy addproxy $port $daddr:$dport
            fi
        done
    }
}

case "$1" in
    all)      migrate_all ;;
    db_only)  migrate_dbs ;;
    web_only) migrate_web ;;
    *) echo "Usage $0 [all|db_only|web_only]"
esac