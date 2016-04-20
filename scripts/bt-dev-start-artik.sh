#!/bin/sh

# Script for registering Broadcom UART BT device
BT_UART_DEVICE=/dev/ttySAC3
BT_CHIP_TYPE=bcm2035
BCM_TOOL=/usr/bin/brcm_patchram_plus

BT_PLATFORM_DEFAULT_HCI_NAME="TIZEN-Mobile"
UART_SPEED=3000000
TIMEOUT=24

#set default firmware
BCM_FIRMWARE=BT_FW_BCM4358A1_001.002.005.0032.0066.hcd

REVISION_NUM=`grep Revision /proc/cpuinfo | awk "{print \\$3}"`
REVISION_HIGH=`echo $REVISION_NUM| cut -c1-2`
REVISION_LOW=`echo $REVISION_NUM| cut -c3-`

HARDWARE=`grep Hardware /proc/cpuinfo | awk "{print \\$3}"`

check_hw_dt()
{
	HARDWARE=`cat /proc/device-tree/model | awk "{print \\$2}"`

	case $HARDWARE in

		"ARTIK10")
			BT_UART_DEVICE=/dev/ttySAC2
			BCM_TOOL=/usr/bin/brcm_patchram_plus
			BCM_FIRMWARE=BCM4354_003.001.012.0353.0745_Samsung_Artik_ORC.hcd
			;;

		"ARTIK5")
			BT_UART_DEVICE=/dev/ttySAC0
			BCM_TOOL=/usr/bin/brcm_patchram_plus
			BCM_FIRMWARE=BCM4354_003.001.012.0353.0745_Samsung_Artik_ORC.hcd
			;;
	esac
}

parse_bd_addr()
{
	for x in $(cat /proc/cmdline); do
		case $x in
			bd_addr=*)
				BD_ADDR=${x#bd_addr=}
				;;
		esac
	done
}

check_hw_dt
if [ -z "${HARDWARE##ARTIK*}" ]; then
	parse_bd_addr
fi

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
/usr/sbin/rfkill unblock bluetooth

echo "Check for Bluetooth device status"
if (/usr/bin/hciconfig | grep hci); then
	echo "Bluetooth device is UP"
	/usr/bin/hciconfig hci0 up
else
	echo "Bluetooth device is DOWN"
	echo "Registering Bluetooth device"
	echo "change auth of brodcom tool"
	chmod 755 $BCM_TOOL

	# In tizenW hardware first time bcmtool download may not success, hence we need to try more times
	MAXBCMTOOLTRY=5
	flag=0
	for (( c=1; c<=$MAXBCMTOOLTRY; c++))
	do
		echo "******* Bcmtool download attempt $c ********"

	$BCM_TOOL $BT_UART_DEVICE --patchram /usr/etc/bluetooth/$BCM_FIRMWARE --no2bytes --baudrate $UART_SPEED --use_baudrate_for_download $BT_UART_DEVICE --bd_addr ${BD_ADDR} > /dev/null 2>&1 &
		bcmtool_pid=$!
		#Check next timeout seconds for bcmtool success
		for (( i=1; i<=$TIMEOUT; i++))
		do
			/bin/sleep 0.1
			kill -0 $bcmtool_pid
			bcmtool_alive=$?

			if [ $i -eq $TIMEOUT ]
			then
				echo "time expired happen $i"
				kill -TERM $bcmtool_pid
				break
#				${RFKILL} block bluetooth
#				exit 1
			fi

			if [ $bcmtool_alive -eq 0 ]
			then
				echo "Continue....$i"
				continue
			else
				echo "Break.......$i"
				flag=1
				break
			fi
		done

		if [ $flag -eq 1 ]
		then
			echo "Break bcmtool download loop on $c attempt"
			break
		else
			/bin/sleep 1
			echo "sleep done"
		fi


		if [ $c -eq $MAXBCMTOOLTRY ]
		then
			echo "***** No Chance to activate, count=$c ******"
			${RFKILL} block bluetooth
			exit 1
		fi

	done

	echo "Try for hciattach"

	# Attaching Broadcom device
	if (/usr/bin/hciattach $BT_UART_DEVICE -s $UART_SPEED $BT_CHIP_TYPE $UART_SPEED flow); then
		sleep 0.1
		/usr/bin/hciconfig hci0 up
		/usr/bin/hciconfig hci0 name $BT_PLATFORM_DEFAULT_HCI_NAME
		/usr/bin/hciconfig hci0 sspmode 1
		echo "HCIATTACH success"
	else
		echo "HCIATTACH failed"
		/usr/sbin/rfkill block bluetooth
	fi
fi
