#!/bin/sh

#
# Script for setting Bluetooth Address
#

if [ -e /opt/etc/.bd_addr ]
then
	echo "Already .bd_addr exists"
	exit 0
fi

/usr/bin/setbd

echo "Set BT address successes"

