#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source .env

if [ "${DEBUG}" == "true" ]; then
        set -x
fi

echo ""
echo "Executing command in container ${CONTAINER} on ${TO} ..."

case "${TO}" in
        "compose")
		if [ "${COMPOSE_CONTEXT_TYPE}" == "moby" ]; then
			CONTAINER_INDEX=$1
			if [ "$CONTAINER_INDEX" == "" ]; then
				CONTAINER_INDEX=1
			fi
			CMD="docker exec -it ${COMPOSE_PROJECT_NAME}_${CONTAINER}_${CONTAINER_INDEX} sh -c 'if [ -e /bin/bash ]; then /bin/bash; else sh; fi'"
		elif [ "${COMPOSE_CONTEXT_TYPE}" == "ecs" ]; then
			echo ""
			echo "Exec into container running on ECS is not supported"
			echo ""
		else
			echo ""
			echo "Unrecognized COMPOSE_CONTEXT_TYPE ${COMPOSE_CONTEXT_TYPE}"
			echo "Supported context types are moby | ecs"
		fi
		;;
	"swarm")
		SERVICE_INDEX=$1
		if [ "$SERVICE_INDEX" == "" ]; then
			SERVICE_INDEX=1
		fi
		TASK_ID=${SWARM_STACK_NAME}_${SWARM_SERVICE_NAME}.${SERVICE_INDEX}
		CONTAINER_ID=$(docker ps | grep ${TASK_ID} | cut -d ' ' -f 1)
		if [ "${CONTAINER_ID}" == "" ]; then
			CONTAINER_HOST=$(docker service ps ${SWARM_STACK_NAME}_${SWARM_SERVICE_NAME} -f desired-state=running --format="{{.Node}} {{.Name }} {{.ID}}" | grep ${TASK_ID} | cut -d ' ' -f 1)
			echo ""
			if [ "${CONTAINER_HOST}" == "" ]; then
				echo "Could not find running task ${TASK_ID}"
			else
				echo "Cannot connect to service task ${TASK_ID}"
				echo "Only connections to tasks running on the local host are supported"
				echo "You may connect to the node running this task ($CONTAINER_HOST) and use docker exec locally"
				echo " or configure remote docker daemon access." 
			fi
			echo ""
			CMD=""
		else
			CMD="docker exec -it ${CONTAINER_ID} sh -c 'if [ -e /bin/bash ]; then /bin/bash; else sh; fi'"
		fi
		;;
	"ecs")
		CONTAINER_INDEX=1
		if [ ! "$1" == "" ]; then
			CONTAINER_INDEX=$1
		fi
		TASK_ID=$(./status.sh | grep RUNNING | head -n ${CONTAINER_INDEX} | tail -n 1 | cut -d '/' -f 2)
		CMD="aws ecs execute-command --region ${REGION} --cluster ${ECS_CLUSTER} --command /bin/bash --task ${TASK_ID} --container ${CONTAINER} --interactive"
		;;
	"kubernetes")
                CONTAINER_INDEX=$1
                if [ "$CONTAINER_INDEX" == "" ]; then
                        CONTAINER_INDEX=1
                fi
		CMD="unset DEBUG; ${KUBECTL} -n ${NAMESPACE} exec -it $( ${KUBECTL} -n ${NAMESPACE} get pod | grep ${APP_NAME} | head -n ${CONTAINER_INDEX} | tail -n 1 | cut -d ' ' -f 1 ) -- sh -c 'if [ -e /bin/bash ]; then /bin/bash; else sh; fi'"
		;;
	"lambda")
		LAMBDA_PAYLOAD=""
		if [ ! "$1" == "" ]; then
			LAMBDA_PAYLOAD="--payload '$1'"
		fi
		CMD="aws lambda invoke --function-name ${LAMBDA_FUNCTION_NAME} ${LAMBDA_PAYLOAD} /tmp/${LAMBDA_FUNCTION_NAME}.out; cat /tmp/${LAMBDA_FUNCTION_NAME}.out" 
		;;
	"batch")
		echo ""
		echo "exec operation is not supported for target orchestrator batch"
		;;
	*)
		checkTO "${TO}"
		if [ "$1" == "" ]; then
			CMD="sh -c 'if [ -e /bin/bash ]; then /bin/bash; else sh; fi'"
		else
			CMD="$@"
		fi
		CMD="docker container exec -it ${CONTAINER} $CMD"
		;;
esac

if [ "${VERBOSE}" == "true" ]; then
        echo "${CMD}"
fi

if [ "${DRY_RUN}" == "false" ]; then
        eval "${CMD}"
fi

if [ "${DEBUG}" == "true" ]; then
        set +x
fi

