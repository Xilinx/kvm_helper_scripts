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

_faas() 
{
    local cur prev hosts devices suggestions device_suggestions
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    hosts="$(virsh list --all --name)"
    devices="$(lspci -d 10ee: | grep \\.0 | awk '{print substr($0,0,2);}' | tr '\n' ' ' | head -c -1)"

    case $COMP_CWORD in
    1)
        COMPREPLY=( $(compgen -W "${hosts}" -- ${cur}) )
        return 0
        ;;
    2)
		if [ "${COMP_WORDS[0]}" == "./detach.sh" ]; then
			# only return attached devices
			devices=$(virsh dumpxml $prev | grep '<hostdev' -A 5 | grep "function='0x1'" | grep -v "type" | tr -s ' ' | cut -d' ' -f4 | cut -d= -f2 | awk '{print substr($0,4,2);}')
		fi
        suggestions=( $(compgen -W "${devices}" -- ${cur}) )
        ;;
    esac
	if [ "${#suggestions[@]}" == "1" ] || [ ! -f /opt/xilinx/xrt/bin/xbutil ] ; then
		COMPREPLY=("${suggestions[@]}")
	else
		# more than one suggestions resolved,
		# respond with the full device suggestions
		declare -a device_suggestions
		XRT_VERSION=$(cat /opt/xilinx/xrt/version.json | python3 -c "import sys, json; print(json.load(sys.stdin)['BUILD_BRANCH'])")
		XRT_LEGACY=1
		if [ $(version "$XRT_VERSION") -ge $(version "2021.1") ]; then XRT_LEGACY=0; fi
		#echo "XRT_VERSION: $XRT_VERSION; LEGACY: $XRT_LEGACY"
		XILINX_DEVICES=""
		if [ $XRT_LEGACY == "1" ]; then
			XILINX_DEVICES=$(/opt/xilinx/xrt/bin/xbmgmt scan)
		else
			XILINX_DEVICES=$(/opt/xilinx/xrt/bin/xbmgmt examine | sed -e '0,/Devices present/d' -e '/^$/d')
		fi
	
		for ((dev=0;dev<${#suggestions[@]};dev++)); do
			#device_suggestions="$device_suggestions\n$dev $(/opt/xilinx/xrt/bin/xbutil scan | grep ":$dev:")"
			device_suggestions+=("${suggestions[$dev]}-->$(echo "$XILINX_DEVICES" | grep ":${suggestions[$dev]}:" | xargs echo -n)")
		done
		COMPREPLY=("${device_suggestions[@]}")
	fi


}
complete -F _faas ./attach.sh
complete -F _faas ./detach.sh

