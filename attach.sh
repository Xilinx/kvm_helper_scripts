#!/bin/bash
############################################################################
# © Copyright 2021 Xilinx, Inc.  All rights reserved.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
############################################################################

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

if [ $# -lt 2 ]; then
	echo "Usage: $0 [-u] [-t] <OS name> <pcie slot>"
	echo "           -u: only map user function"
	echo "           -t: keep temp files"
	echo "For example: $0 centos7.5 af"
	echo
	echo "OS list:"
	virsh list --all
	echo
	echo "========================================================"
	echo
	# starting from 2021.2, the api for the xrt utilities changed
	XRT_VERSION=$(cat /opt/xilinx/xrt/version.json | python3 -c "import sys, json; print(json.load(sys.stdin)['BUILD_BRANCH'])")
	XRT_LEGACY=1
	if [ $(version "$XRT_VERSION") -ge $(version "2021.1") ]; then XRT_LEGACY=0; fi
	#echo "XRT_VERSION: $XRT_VERSION; LEGACY: $XRT_LEGACY"
	echo "Xilinx devices:"
	if [ -f /opt/xilinx/xrt/bin/xbmgmt ]; then
		if [ $XRT_LEGACY == "1" ]; then
			/opt/xilinx/xrt/bin/xbmgmt scan
		else
			/opt/xilinx/xrt/bin/xbmgmt examine | sed -e '0,/Devices present/d' -e '/^$/d'
		fi
	else
		lspci -d 10ee:
	fi
	echo
	echo
	echo "========================================================"
	echo
	for dev in $(virsh list --all --name); do
		devices=$(virsh dumpxml $dev | grep '<hostdev' -A 5 | grep "function='0x1'" | grep -v "type" | tr -s ' ' | cut -d' ' -f4 | cut -d= -f2 | awk '{print substr($0,4,2);}')
		if [[ ! -z "$devices" ]]; then
			echo "Attached host devices in $dev:"
			echo $devices
			echo
		fi
	done
	exit -1
fi

KEEP_TEMP=0
MAP_MGMT=1
if [ "$1" = "-u" ]; then
	MAP_MGMT=0
	shift
fi
if [ "$1" = "-t" ]; then
	KEEP_TEMP=1
	shift
fi


export OS=$1
export DEV=$2

#not sure what to pick for SLOT/BUS on guest.
#Testing shows that on q35 systems, SLOT 0x00 works, with BUS number the unique device number of the pci on the host
#On i440fx we need to use bus 0x00, and we use a unique slot which is the device number on the host
SLOT=$2
GUESTBUS="00"
if $(virsh dumpxml $OS | grep q35 &> /dev/null); then
	SLOT="00"
	GUESTBUS=$2
fi
export SLOT
export GUESTBUS

CMD=$(basename $0)
COMMAND=${CMD%.sh}

if [ $MAP_MGMT -eq 1 ]; then
	envsubst < pass-mgmt.xml_base > pass-mgmt-$DEV-$OS.xml
	virsh $COMMAND-device $OS --file pass-mgmt-$DEV-$OS.xml --config
fi

envsubst < pass-user.xml_base > pass-user-$DEV-$OS.xml
virsh $COMMAND-device $OS --file pass-user-$DEV-$OS.xml --config

if [ $KEEP_TEMP -eq 0 ]; then
   rm -f pass-mgmt-$DEV-$OS.xml pass-user-$DEV-$OS.xml
fi

