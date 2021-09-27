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

if [ $# -lt 1 ]; then
	echo "Specify the guest to modify"
	exit -1
fi

GUEST=$1

# update vgamem to 32MB to allow full screen on our widescreen displays
virsh dumpxml $GUEST > $GUEST.xml

if [ $? -ne 0 ]; then
	echo "$GUEST not found"
	virsh list --all
	rm -f $GUEST.xml
	exit -1
fi

sed -i "s/vgamem='[0-9]*'/vgamem='32768'/" $GUEST.xml
virsh define $GUEST.xml
rm -f $GUEST.xml


