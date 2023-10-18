#!/bin/sh

TMPFILE=/tmp/.EoCInfo
## check eth0 iface whether if on a bridge
if [ -n "$(wanctl -t all|grep 'INTERNET_B_VID_ ')" ]; then
	iface=br-lan
elif [ -n "$(wanctl -t all|grep 'OTHER_B_VID_ ')" ]; then
	iface=br1
else
	iface=eth0
fi
# Get Slave&MasterMac
int6k -i $iface -m -r > $TMPFILE 2>&1
SlaveMac=$(cat $TMPFILE|grep Found|awk '{print $2}' |head -n 1)
MasterMac=$(cat $TMPFILE|grep CCO_DA|awk '{print $3}' |head -n 1)
TEI=$(cat $TMPFILE|grep "network->TEI"|awk '{print $3}' |head -n 1)
Uplink=$(cat $TMPFILE|grep AvgPHYDR_TX|awk '{print $3}'|head -n 1)
Downlink=$(cat $TMPFILE|grep AvgPHYDR_RX|awk '{print $3}'|head -n 1)

SlaveIsAR7400=$(cat $TMPFILE|grep AR7400|awk '{print $3}' |head -n 1)
if [ "$MasterMac" != "" ]; then
	int6k -i $iface -r $MasterMac > $TMPFILE 2>&1
	MasterIsAR7400=$(cat $TMPFILE|grep AR7400|awk '{print $3}')
fi

# Get SNR,ATN,BPC(ModulationBit?)
if [ "$SlaveIsAR7400" == "AR7400" -a "$MasterIsAR7400" == "AR7400" ] ; then
	amptone -i $iface -qs $SlaveMac $MasterMac > $TMPFILE
else
	int6ktone -i $iface -qs $SlaveMac $MasterMac > $TMPFILE
fi
DownSNR=$(cat $TMPFILE|grep SNR|grep -v inf|awk '{print ($3+$2)/2}')
DownATN=$(cat $TMPFILE|grep AGC|grep -v inf|awk '{print $2}')
DownBPC=$(cat $TMPFILE|grep BPC|grep -v inf|awk '{print ($3+$2)/2}')

if [ "$SlaveIsAR7400" == "AR7400" -a "$MasterIsAR7400" == "AR7400" ] ; then
	amptone -i $iface -qs $MasterMac $SlaveMac > $TMPFILE
else
	int6ktone -i $iface -qs $MasterMac $SlaveMac > $TMPFILE
fi
UpSNR=$(cat $TMPFILE|grep SNR|grep -v inf|awk '{print ($3+$2)/2}')
UpATN=$(cat $TMPFILE|grep AGC|grep -v inf|awk '{print $2}')
UpBPC=$(cat $TMPFILE|grep BPC|grep -v inf|awk '{print ($3+$2)/2}')

cat > $TMPFILE << EOF
EocSlaveMac=$SlaveMac
EocMasterMac=$MasterMac
EocTEI=$TEI
EocUplink=$Uplink
EocDownlink=$Downlink
EocUpSNR=$UpSNR
EocDownSNR=$DownSNR
EocUpModulationBit=$UpBPC
EocDownModulationBit=$DownBPC
EocUpLineAttenuation=$UpATN
EocDownLineAttenuation=$DownATN
EOF

