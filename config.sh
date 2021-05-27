#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

. ./.env 

if [ "${DEBUG}" == "true" ]; then
	set -x
fi

function usage
{
	echo ""
	echo "Usage: $0 [setting] [value]"
	echo ""
	echo "   $0 --help        - display usage information"
	echo "   $0 -i            - edit selected settings interactively"
	echo "   $0               - edit configuration file"
	echo "   $0 setting       - edit specified setting interactively"
	echo "   $0 setting value - set the specified setting to the provided value"
	echo ""
}

if [ "$1" == "--help" ]; then
	usage
	CMD=""
elif [ "$1" == "-i" ]; then
	./config.sh TO
	./config.sh BASE_IMAGE_PATH
	./config.sh REGISTRY
	./config.sh IMAGE_NAME
	./config.sh VERSION
elif [ "$1" == "" ]; then
	CMD="${CMD_EDIT} .env"
else
	if [ "$2" == "" ]; then
		# Interactive
		echo ""
		cat ./.env | grep "^export $1=" -B 10
		echo ""
		CURRENT_VALUE=$(printenv $1)
		echo "Set $1 [ ${CURRENT_VALUE} ] to: " 
		read NEW_VALUE
		if [ "${NEW_VALUE}" == "" ]; then
			NEW_VALUE="${CURRENT_VALUE}"
		fi
	else
		# Set value to $2
		NEW_VALUE="$2"
	fi
	CMD="cp -f ./.env ./.env.bak; cat ./.env | sed \"s#^export $1=.*#export $1=${NEW_VALUE}#\" | tee ./.env > /dev/null; echo ''; echo New value:; cat ./.env | grep \"^export $1=\""
fi


if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
fi

if [ "${DRY_RUN}" == "false" ]; then
	eval "${CMD}"
	echo ""
fi

if [ "${DEBUG}" == "true" ]; then
	set +x
fi

