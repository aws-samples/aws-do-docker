#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source .env

export MODE=-it

echo ""
echo "Testing container ${CONTAINER} on ${TO} ..."

case ${TO} in
	"lambda")
		echo "Testing lambda function ${LAMBDA_FUNCTION_NAME} ..."
		for t in $(ls ${LAMBDA_TEST_PATH}/test*.sh); do echo Running test $t; $t; done
		;;
	"compose")
		if [ "${COMPOSE_CONTEXT_TYPE}" == "moby" ]; then
                	CONTAINER_INDEX=$1
                	if [ "$CONTAINER_INDEX" == "" ]; then
                        	CONTAINER_INDEX=1
                	fi
			docker exec ${MODE} ${COMPOSE_PROJECT_NAME}_${CONTAINER}_${CONTAINER_INDEX} sh -c "for t in \$(ls /test*.sh); do echo Running test \$t; \$t; done;" 
		elif [ "${COMPOSE_CONTEXT_TYPE}" == "ecs" ]; then
			endpoint_host=$(./status.sh | grep ${CONTAINER} | grep Running | awk '{print $4}' | cut -d ':' -f 1)
			endpoint="http://${endpoint_host}:${PORT_EXTERNAL}"
			for t in $(ls ${COMPOSE_TEST_PATH}/test*.sh); do echo Running test $t; $t $endpoint; done
		else
			echo ""
			echo "Unrecognized COMPOSE_CONTEXT_TYPE ${COMPOSE_CONTEXT_TYPE}"
			echo "Supported context types: moby | ecs"
		fi
		;;
	"ecs")
		endpoint_host=$(./status.sh | grep ${CONTAINER} | grep RUNNING | awk '{print $3}' | cut -d ':' -f 1)
		endpoint="http://${endpoint_host}:${PORT_EXTERNAL}"
		for t in $(ls ${COMPOSE_TEST_PATH}/test*.sh); do echo Running test $t; $t $endpoint; done
		;;
	"kubernetes")
                CONTAINER_INDEX=$1
                if [ "$CONTAINER_INDEX" == "" ]; then
                        CONTAINER_INDEX=1
                fi
                unset DEBUG; ${KUBECTL} -n ${NAMESPACE} exec -it $( ${KUBECTL} -n ${NAMESPACE} get pod | grep ${APP_NAME} | head -n ${CONTAINER_INDEX} | tail -n 1 | cut -d ' ' -f 1 ) -- bash -c "for t in \$(ls /test*.sh); do echo Running test \$t; \$t; done"
		;;
	"batchlocal")
		BATCH_COMMAND="cd /job; for t in \$(ls test*.sh); do echo Running test \$t; ./\$t; done"
		echo "${BATCH_COMMAND}"
		docker container run ${RUN_OPTS} ${CONTAINER_NAME} -d ${NETWORK} ${VOL_MAP} ${REGISTRY}${IMAGE}${TAG} bash -c "${BATCH_COMMAND}"
		./logs.sh
		./stop.sh
		;;
	"batch")
		BATCH_COMMAND="cd /job; ./test1.sh; ./test2.sh"
		./run.sh "[\"/bin/bash\",\"-c\",\"${BATCH_COMMAND}\"]"
		;;
	*)
		docker exec ${MODE} ${CONTAINER} sh -c "for t in \$(ls /test*.sh); do echo Running test \$t; \$t; done;" 
		;;
esac


