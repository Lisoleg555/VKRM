#!/bin/bash
mkdir -p /var/tmp/one/connect_iperf/
iperf -c $1 -f M > /var/tmp/one/connect_iperf/$1.txt