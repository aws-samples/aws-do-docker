#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

# Job startup script
echo "Container-Root/job/startup.sh executed"

# Start job
cd /job

LIMIT=3
if [ ! "${ITERATION_LIMIT}" == "" ]; then
	LIMIT=${ITERATION_LIMIT}
fi

i=0
while [ $i -lt $LIMIT ]; do
	echo "Iteration $i: $(date)"
	sleep 5
	i=$((i+1))
done

