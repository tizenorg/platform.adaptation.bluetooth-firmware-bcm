#!/bin/sh

# Script for registering Broadcom UART BT device
BT_UART_DEVICE=/dev/ttySAC3
BT_CHIP_TYPE=bcm2035
#BCM_TOOL=/usr/bin/bcmtool_4330b1
BCM_TOOL=/usr/bin/bcmtool_4358a1

BT_PLATFORM_DEFAULT_HCI_NAME="TIZEN-Mobile"
UART_SPEED=3000000

#set default firmware
#BCM_FIRMWARE=BT_FW_BCM4330B1_002.001.003.0221.0265.hcd
BCM_FIRMWARE=BT_FW_BCM4358A1_001.002.005.0032.0066.hcd

REVISION_NUM=`grep Revision /proc/cpuinfo | awk "{print \\$3}"`
REVISION_HIGH=`echo $REVISION_NUM| cut -c1-2`
REVISION_LOW=`echo $REVISION_NUM| cut -c3-`

HARDWARE=`grep Hardware /proc/cpuinfo | awk "{print \\$3}"`

if [ ! -e "$BT_UART_DEVICE" ]
then
	mknod $BT_UART_DEVICE c 204 64
fi

if [ ! -e /opt/etc/.bd_addr ]
then
	# Set BT address
	/usr/bin/setbd
fi

# Trun-on Bluetooth Chip
rfkill unblock bluetooth

echo "Check for Bluetooth device status"
if (/usr/bin/hciconfig | grep hci); then
	echo "Bluetooth device is UP"
	/usr/bin/hciconfig hci0 up
else
	echo "Bluetooth device is DOWN"
	echo "Registering Bluetooth device"

	$BCM_TOOL $BT_UART_DEVICE -FILE=/usr/etc/bluetooth/$BCM_FIRMWARE -BAUD=$UART_SPEED -ADDR=/opt/etc/.bd_addr -SETSCO=0,0,0,0,0,0,0,3,3,0 -LP > /dev/null 2>&1

	# Attaching Broadcom device
	if (/usr/bin/hciattach $BT_UART_DEVICE -s $UART_SPEED $BT_CHIP_TYPE $UART_SPEED flow); then
		sleep 0.1
		/usr/bin/hciconfig hci0 up
		/usr/bin/hciconfig hci0 name $BT_PLATFORM_DEFAULT_HCI_NAME
		/usr/bin/hciconfig hci0 sspmode 1
		echo "HCIATTACH success"
	else
		echo "HCIATTACH failed"
		rfkill block bluetooth
	fi
fi
