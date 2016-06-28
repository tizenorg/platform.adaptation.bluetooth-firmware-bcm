#!/bin/sh
PATH=/bin:/usr/bin:/sbin:/usr/sbin

GREP="/bin/grep"
MKNOD="/bin/mknod"
AWK="/usr/bin/awk"
RFKILL="/usr/sbin/rfkill"
CP="/bin/cp"

#
# Script for registering Broadcom UART BT device
#
BT_UART_DEVICE=/dev/ttySAC0
BT_CHIP_TYPE=bcm2035
BCM_TOOL=/usr/bin/bcmtool_4343w

BCM_TOOL_DBG_LOG=/var/lib/bluetooth/bcmtool_log

# If you want to enable bcmtool debug log, please uncomment below #
#ENABLE_BCMTOOL_DEBUG="-DEBUG"

HCI_CONFIG=/usr/bin/hciconfig
HCI_ATTACH=/usr/bin/hciattach

BT_ADDR=/csa/bluetooth/.bd_addr
BCM_WIFI_CID=/opt/etc/.cid.info

SYSLOG_PATH=/var/log/messages

UART_SPEED=3000000

#Firmware Loading timeout:  Unit * 100ms
# Example : 34 is 3.4 sec
TIMEOUT=34

HARDWARE=`grep Hardware /proc/cpuinfo | awk "{print \\$3}"`
REVISION=`grep Revision /proc/cpuinfo | awk "{print \\$3}"`
BCM_PACKAGING_TYPE=`cat ${BCM_WIFI_CID}`

BCM_FIRMWARE="BCM4343A1_001.002.009.0035.0096_ORC_Orbis_WC1-S.hcd"

if [ "$HARDWARE" == "WC1-S" ] && ( [ "$REVISION" == "0000" ] || [ "$REVISION" == "0001" ] )
then
	BCM_FIRMWARE="BCM4334W0_001.002.003.0014.0017_Ponte_Solo_Semco_B58_13.5dBm.hcd"
else
	if [ "${BCM_PACKAGING_TYPE}" == "semco" ] || [ "${BCM_PACKAGING_TYPE}" == "samsung" ] ; then
		BCM_FIRMWARE="BCM4343A1_001.002.009.0035.0096_ORC_Orbis_WC1-S.hcd"
		echo "Package type is semco"
	elif [ "${BCM_PACKAGING_TYPE}" == "murata" ] ; then
		BCM_FIRMWARE="BCM4343A1_001.002.009.0022.0050_Murata_Type-1FR.hcd"
		echo "Package type is murata"
	else
		echo "Package type is not detected(${BCM_PACKAGING_TYPE})"
	fi
fi

BCM_CHIP_NAME="BCM4343W"

echo "Check for Bluetooth device status"
if (${HCI_CONFIG} | grep hci); then
	echo "Bluetooth device is UP"
	${HCI_CONFIG} hci0 up
	exit 1
fi

${RFKILL} unblock bluetooth

echo "BCM_FIRMWARE: $BCM_FIRMWARE, HARDWARE: $HARDWARE, REVISION: $REVISION"

# Set BT address: This will internally check for the file presence
/usr/bin/setbd

#if the setbd return non 0, which means incorrect bd address file, then exit
if [ $? -ne 0 ]
then
	exit 1
fi

echo "Registering Bluetooth device"

$BCM_TOOL $BT_UART_DEVICE -TYPE=${BCM_CHIP_NAME} $ENABLE_BCMTOOL_DEBUG \
	-FILE=/usr/etc/bluetooth/$BCM_FIRMWARE -BAUD=$UART_SPEED \
	-ADDR=$BT_ADDR >$BCM_TOOL_DBG_LOG  2>&1 &
bcmtool_pid=$!

#Check next timeout seconds for bcmtool success
for (( i=1; i<=$TIMEOUT; i++))
do
        sleep 0.1
        kill -0 $bcmtool_pid
        bcmtool_alive=$?

        if [ $i -eq $TIMEOUT ]
        then
                echo "time expired happen $i"
                kill -TERM $bcmtool_pid
                /usr/sbin/rfkill block bluetooth
                ${CP} $SYSLOG_PATH /var/lib/bluetooth/
                exit 1
        fi

        if [ $bcmtool_alive -eq 0 ]
        then
                echo "Continue....$i"
                continue
        else
                echo "Break.......$i"
                break
        fi
done

# Attaching Broadcom device
if (${HCI_ATTACH} $BT_UART_DEVICE -s $UART_SPEED $BT_CHIP_TYPE $UART_SPEED flow); then
	/bin/sleep 0.1
	echo "HCIATTACH success"
else
	echo "HCIATTACH failed"
	${RFKILL} block bluetooth
	${CP} $SYSLOG_PATH /var/lib/bluetooth/
fi
