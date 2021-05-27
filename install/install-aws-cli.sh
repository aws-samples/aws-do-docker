#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

if [ -e .env ]; then
	. .env
elif [ -e ../.env ]; then
	pushd ..
	. .env
	popd
fi

if [ "$OPERATING_SYSTEM" == "Linux" ]; then
	echo "Installing aws-cli on Linux ..."
	pushd /tmp
	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
	unzip awscliv2.zip
	sudo ./aws/install
	rm -f awscliv2.zip
	rm -rf ./aws
	popd
	which aws
	aws --version
elif [ "$OPERATING_SYSTEM" == "MacOS" ]; then
	echo "Installing aws-cli on MacOS ..."
	curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
	sudo installer -pkg AWSCLIV2.pkg -target /
	which aws
	aws --version
else
	echo "Unrecognized OS $OPERATING_SYSTEM"
fi


