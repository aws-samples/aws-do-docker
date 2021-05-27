#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source .env

if [ "${DEBUG}" == "true" ]; then
	set -x
fi

if [ -z "$1" ]; then
	MODE=-d
else
	MODE=-it
fi 

function generate_compose_files
{
	echo "Generating compose files ..."
        if [ ! -d "${COMPOSE_APP_PATH}" ]; then
		mkdir -p "${COMPOSE_APP_PATH}"
	fi	
	CMD="BASE_PATH=$(pwd); cd ${COMPOSE_TEMPLATE_PATH}; for f in *.*; do cat \$f | envsubst > \${BASE_PATH}/\${COMPOSE_APP_PATH}/\$f; done; cd \${BASE_PATH}"
	if [ "${VERBOSE}" == "true" ]; then
		echo "${CMD}"
	fi
	if [ "${DRY_RUN}" == "false" ]; then
		eval "${CMD}"
	fi
}

function generate_lambda_files
{
	echo "Generating lambda files ..."
	export ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
	if [ ! -d "${LAMBDA_APP_PATH}" ]; then
		mkdir -p "${LAMBDA_APP_PATH}"
	fi
	CMD="BASE_PATH=$(pwd); cd ${LAMBDA_TEMPLATE_PATH}; for f in *.*; do cat \$f | envsubst > \${BASE_PATH}/\${LAMBDA_APP_PATH}/\$f; done; cd \${BASE_PATH}"
	if [ "${VERBOSE}" == "true" ]; then
		echo "${CMD}"
	fi
	if [ "${DRY_RUN}" == "false" ]; then
		eval "${CMD}"
	fi
}

function generate_kubernetes_manifests
{
	echo "Generating Kubernetes manifests ..."
	if [ ! -d "${KUBERNETES_APP_PATH}" ]; then
		mkdir -p "${KUBERNETES_APP_PATH}"
	fi
	CMD="BASE_PATH=$(pwd); cd ${KUBERNETES_TEMPLATE_PATH}; for f in *.yaml; do cat \$f | envsubst > \${BASE_PATH}/\${KUBERNETES_APP_PATH}/\$f; done; cd \${BASE_PATH}"
        if [ "${VERBOSE}" == "true" ]; then
                echo "${CMD}"
        fi
        if [ "${DRY_RUN}" == "false" ]; then
                eval "${CMD}"
        fi 
	
}

function prepare_ecs_roles
{
	LOG_GROUP=/aws/ecs/${ECS_CLUSTER}
	echo "Preparing LogGroup $LOG_GROUP ..."
	LOG_GROUPS=$(aws logs describe-log-groups | grep GroupName | grep ${LOG_GROUP})
	if [ "$LOG_GROUPS" == "" ]; then
		echo "Creating log group ${LOG_GROUP} ..." 
		RESULT=$(aws logs create-log-group --region ${REGION} --log-group-name ${LOG_GROUP})
	fi
	export LOG_GROUP_ARN=$(aws logs describe-log-groups --query "logGroups[?logGroupName==\`${LOG_GROUP}\`].arn" --output text)
	generate_compose_files
	echo "Preparing ecsInstanceRole ..."
	role=$(aws iam list-roles --query 'Roles[?RoleName==`ecsInstanceRole`].RoleName' --output text)
	if [ "${role}" == "" ]; then
		RESULT=$(aws iam create-role --role-name ecsInstanceRole --assume-role-policy-document file://${ECS_TRUST_FILE})
		RESULT=$(aws iam attach-role-policy --role-name ecsInstanceRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role)
	fi
        echo "Preparing ecsTaskRole  ..."
	role=$(aws iam list-roles --query 'Roles[?RoleName==`ecsTaskRole`].RoleName' --output text)
	if [ "${role}" == "" ]; then
		RESULT=$(aws iam create-role --role-name ecsTaskRole --assume-role-policy-document file://${ECS_TRUST_FILE})
		RESULT=$(aws iam put-role-policy --role-name ecsTaskRole --policy-name ecsExecPolicy --policy-document file://${ECS_EXEC_POLICY_FILE})
	fi
	role_arn=$(aws iam list-roles --query 'Roles[?RoleName==`ecsTaskRole`].Arn' --output text)
	export ECS_TASK_ROLE_ARN="${role_arn}"
        echo "Preparing ecsTaskExecutionRole  ..."
	role=$(aws iam list-roles --query 'Roles[?RoleName==`ecsTaskExecutionRole`].RoleName' --output text)
	if [ "${role}" == "" ]; then
		RESULT=$(aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document file://${ECS_TRUST_FILE})
	fi
	policy=$(aws iam list-attached-role-policies --role-name ecsTaskExecutionRole --query 'AttachedPolicies[?PolicyName==`AmazonECSTaskExecutionRolePolicy`].PolicyName' --output text)
	if [ "${policy}" == "" ]; then
		RESULT=$(aws iam attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy)
	fi
	role_arn=$(aws iam list-roles --query 'Roles[?RoleName==`ecsTaskExecutionRole`].Arn' --output text)
	export ECS_EXEC_ROLE_ARN="${role_arn}"
}

function prepare_lambda_role
{
	echo "Preparing AWSLambdaFunctionRole ..."
	role=$(aws iam list-roles --query "Roles[?RoleName==\`AWSLambdaFunctionRole\`].RoleName" --output text)
	if [ "${role}" == "" ]; then
		RESULT=$(aws iam create-role --role-name AWSLambdaFunctionRole --assume-role-policy-document file://${LAMBDA_TRUST_FILE})
	fi
	policy=$(aws iam list-attached-role-policies --role-name AWSLambdaFunctionRole --query 'AttachedPolicies[?PolicyName==`AWSLambdaBasicExecutionRole`].PolicyName' --output text)
	if [ "${policy}" == "" ]; then
		RESULT=$(aws iam attach-role-policy --role-name AWSLambdaFunctionRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole)
	fi
	role_arn=$(aws iam list-roles --query "Roles[?RoleName==\`AWSLambdaFunctionRole\`].Arn" --output text)
	export LAMBDA_ROLE_ARN="${role_arn}"
}

function prepare_ecs_cluster
{
	ECS_CLUSTERS=$(aws ecs list-clusters | grep -w ${ECS_CLUSTER})
        if [ "${ECS_MANAGE_CLUSTER}" == "true" ]; then
		echo "Preparing ECS Cluster ${ECS_CLUSTER} ..."
		${ECS_CLI} configure --region ${REGION} --cluster ${ECS_CLUSTER}
		if [ "${ECS_CLUSTERS}" == "" ]; then
			echo "Creating ECS cluster ${ECS_CLUSTER} ..."
			${ECS_CLI} up --force --capability-iam --cidr ${ECS_SG_CIDR}
		else
			echo "ECS cluster ${ECS_CLUSTER} already exists"
		fi
	else
		if [ "${ECS_CLUSTERS}" == "" ]; then
			echo "ECS cluster ${ECS_CLUSTER} not found. Please set ECS_MANAGE_CLUSTER to true and execute run.sh to create the cluster, or create cluster manually first"
			exit 1
		else
			echo "ECS cluster ${ECS_CLUSTER} found"
		fi
	fi
	CONTAINER_ARN=$(aws ecs list-container-instances --cluster ${ECS_CLUSTER} --query 'containerInstanceArns[0]' --output text)
	while [ "$CONTAINER_ARN" == "None" ]; do
		echo "Waiting for container startup ..."
		sleep 10
		export CONTAINER_ARN=$(aws ecs list-container-instances --cluster ${ECS_CLUSTER} --query 'containerInstanceArns[0]' --output text)
	done
	echo "CONTAINER_ARN=$CONTAINER_ARN"
	if [ ! "${CONTAINER_ARN}" == "" ]; then
		export VPC_ID=$(aws ecs describe-container-instances --cluster default --container-instances ${CONTAINER_ARN} --query 'containerInstances[*].attributes[?name==`ecs.vpc-id`].value' --output text)
		echo "VPC_ID=${VPC_ID}"
		export SUBNET_ID=$(aws ecs describe-container-instances --cluster default --container-instances ${CONTAINER_ARN} --query 'containerInstances[*].attributes[?name==`ecs.subnet-id`].value' --output text)
		echo "SUBNET_ID=$SUBNET_ID"
		export SG_ID=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=${VPC_ID} --query 'SecurityGroups[?Description==`ECS Allowed Ports`].GroupId' --output text)
		echo "SG_ID=${SG_ID}"

	else
		echo "WARN: Could not find SUBNET_ID for cluster ${ECS_CLUSTER}. Please specify subnet manually in to/compose/template/ecs-params.yaml"
	fi
}

function prepare_batch_compute_environment
{
	echo "Preparing Batch compute environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} ..."
	BATCH_COMPUTE_ENVIRONMENT_NAMES=$(aws batch describe-compute-environments --query 'computeEnvironments[*].computeEnvironmentName' --output text)
	echo ${BATCH_COMPUTE_ENVIRONMENT_NAMES} | grep -w -q ${BATCH_COMPUTE_ENVIRONMENT_NAME}
	if [ "$?" == "0" ]; then
		echo "Compute environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} exists"
		STATE=$(aws batch describe-compute-environments --compute-environments ${BATCH_COMPUTE_ENVIRONMENT_NAME} --query 'computeEnvironments[*].state' --output text)
		if [ ! "${STATE}" == "ENABLED" ]; then
			echo "Enabling compute environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} ..."
			CMD="aws batch update-compute-environment --compute-environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} --state ENABLED"
			RESULT=$(eval "${CMD}")
		fi
	else
		if [ "${BATCH_MANAGE_COMPUTE_ENVIRONMENT}" == "true" ]; then
			echo "Creating compute environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} ..."
			CMD="aws batch create-compute-environment --compute-environment-name ${BATCH_COMPUTE_ENVIRONMENT_NAME} --type MANAGED --compute-resources ${BATCH_COMPUTE_RESOURCES}"
			RESULT=$(eval "${CMD}")
			# Wait for compute environment to get created
			STATUS=$(aws batch describe-compute-environments --compute-environments ${BATCH_COMPUTE_ENVIRONMENT_NAME} --query 'computeEnvironments[*].status' --output text)
                        while [ ! "${STATUS}" == "VALID" ]; do
                        	echo "Waiting for ${BATCH_COMPUTE_ENVIRONMENT_NAME} status to become VALID ..."      
                        	sleep 2
                                STATUS=$(aws batch describe-compute-environments --compute-environments ${BATCH_COMPUTE_ENVIRONMENT_NAME} --query 'computeEnvironments[*].status' --output text)
			done
		else
			echo "Compute environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} not found!"
			exit 1
		fi
	fi
}

function prepare_batch_queue
{
	echo "Preparing job queue ${BATCH_JOB_QUEUE_NAME} ..."
	BATCH_JOB_QUEUE_NAMES=$(aws batch describe-job-queues --query 'jobQueues[*].jobQueueName' --output text)
	echo ${BATCH_JOB_QUEUE_NAMES} | grep -w -q ${BATCH_JOB_QUEUE_NAME}
	if [ "$?" == "0" ]; then
		echo "Job queue ${BATCH_JOB_QUEUE_NAME} exists"
	else
		if [ "${BATCH_MANAGE_COMPUTE_ENVIRONMENT}" == "true" ]; then
			echo "Creating job queue ${BATCH_JOB_QUEUE_NAME} ..."
			CMD="aws batch create-job-queue --job-queue-name ${BATCH_JOB_QUEUE_NAME} --priority 1 --compute-environment-order order=0,computeEnvironment=${BATCH_COMPUTE_ENVIRONMENT_NAME}"
			RESULT=$(eval "${CMD}")
			# Wait for job queue to become valid
			STATUS=$(aws batch describe-job-queues --job-queues ${BATCH_JOB_QUEUE_NAME} --query 'jobQueues[*].status' --output text)
			while [ ! "${STATUS}" == "VALID" ]; do
				echo "Waiting for ${BATCH_JOB_QUEUE_NAME} status to become VALID ..."      
				sleep 2
				STATUS=$(aws batch describe-job-queues --job-queues ${BATCH_JOB_QUEUE_NAME} --query 'jobQueues[*].status' --output text)
			done
		else
			echo "Job queue ${BATCH_JOB_QUEUE_NAME} not found!"
			exit 1
		fi
	fi
}

function register_batch_job_definition
{
	if [ "$1" == "" ]; then
		BATCH_JOB_COMMAND="${BATCH_COMMAND_DEFAULT}"
	else
		BATCH_JOB_COMMAND="$@"
	fi
	echo "Registering job definition ${BATCH_JOB_DEFINITION_NAME} ..."
	echo "BATCH_JOB_COMMAND=${BATCH_JOB_COMMAND}"
	if [ "${BATCH_COMPUTE_ENVIRONMENT_TYPE}" == "EC2" ]; then
		export BATCH_CONTAINER_PROPERTIES="image=${REGISTRY}${IMAGE}${TAG},vcpus=${BATCH_JOB_VCPUS},memory=${BATCH_JOB_MEMORY},jobRoleArn=${ECS_TASK_ROLE_ARN},executionRoleArn=${ECS_EXEC_ROLE_ARN},environment=\"${BATCH_JOB_ENV_VARS}\",command=${BATCH_JOB_COMMAND}"
	else
		export BATCH_CONTAINER_PROPERTIES="image=${REGISTRY}${IMAGE}${TAG},resourceRequirements=\"[{type=VCPU,value=${BATCH_JOB_VCPUS}},{type=MEMORY,value=${BATCH_JOB_MEMORY}}]\",jobRoleArn=${ECS_TASK_ROLE_ARN},executionRoleArn=${ECS_EXEC_ROLE_ARN},environment=\"${BATCH_JOB_ENV_VARS}\",command=${BATCH_JOB_COMMAND}"
	fi
	CMD="aws batch register-job-definition --type container --job-definition-name ${BATCH_JOB_DEFINITION_NAME} --platform-capabilities ${BATCH_COMPUTE_ENVIRONMENT_TYPE} --container-properties ${BATCH_CONTAINER_PROPERTIES}"
        if [ "${VERBOSE}" == "true" ]; then
        	echo "${CMD}"
        fi
        if [ "${DRY_RUN}" == "false" ]; then
        	RESULT=$(eval "${CMD}")
        fi
}

echo ""
echo "Running container ${CONTAINER} on ${TO} ..."

case "${TO}" in
	"compose")
		generate_compose_files
		CMD="${DOCKER_COMPOSE} -f ${COMPOSE_FILE} up -d"
		;;
	"swarm")
		generate_compose_files
		CMD="docker stack deploy -c ${COMPOSE_FILE} ${SWARM_STACK_NAME}"
		;;
	"ecs")
		prepare_ecs_roles
		prepare_ecs_cluster
		generate_compose_files
		COMPOSE_FILE=${ECS_COMPOSE_FILE}
		CMD="${ECS_CLI} compose --ecs-params ${ECS_PARAMS_FILE} --file ${ECS_COMPOSE_FILE} create --launch-type ${ECS_LAUNCH_TYPE}"
		if [ "${VERBOSE}" == "true" ]; then
			echo "${CMD}"
		fi

		if [ "${DRY_RUN}" == "false" ]; then
			TASK_DEFINITION_RESULT=$(eval "${CMD}")
			echo ""
		fi
		CMD="aws ecs run-task --cluster ${ECS_CLUSTER} --task-definition compose --enable-execute-command --launch-type ${ECS_LAUNCH_TYPE}"
	        if [ "${ECS_LAUNCH_TYPE}" == "FARGATE" ]; then
			CMD="$CMD --network-configuration \"awsvpcConfiguration={subnets=[${SUBNET_ID}],securityGroups=[${SG_ID}],assignPublicIp=${ECS_ASSIGN_PUBLIC_IP}}\""
		fi
		;;
	"kubernetes")
		generate_kubernetes_manifests
		CMD="${KUBECTL} -n ${NAMESPACE} apply -f ${KUBERNETES_APP_PATH}"
		;;
	"lambdalocal")
		CMD="docker run ${RUN_OPTS} ${CONTAINER_NAME} ${MODE} ${NETWORK} -p ${PORT_EXTERNAL}:8080 ${REGISTRY}${IMAGE}${TAG} $@"
		;;
	"lambda")
		generate_lambda_files
		prepare_lambda_role
		sleep 5 # wait for lambda role to finish creating
		CMD="aws lambda create-function --region ${REGION} --function-name ${LAMBDA_FUNCTION_NAME} --package-type Image --code ImageUri=${REGISTRY}${IMAGE}${TAG} --role ${LAMBDA_ROLE_ARN}"
		;;
	"batchlocal")
		if [ "$1" == "" ]; then
			BATCH_COMMAND=${BATCH_COMMAND_DEFAULT}
		else
			BATCH_COMMAND="$@"
		fi
		CMD="docker container run ${RUN_OPTS} ${CONTAINER_NAME} -d ${NETWORK} ${VOL_MAP} ${REGISTRY}${IMAGE}${TAG} ${BATCH_COMMAND}"
		;;
	"batch")
		prepare_ecs_roles
		prepare_batch_compute_environment
		prepare_batch_queue
		register_batch_job_definition "$@"
		CMD="aws batch submit-job --job-name ${BATCH_JOB_NAME} --job-queue ${BATCH_JOB_QUEUE_NAME} --job-definition ${BATCH_JOB_DEFINITION_NAME}"
		;;
	*)
		checkTO "${TO}"
		CMD="docker container run ${RUN_OPTS} ${CONTAINER_NAME} ${MODE} ${NETWORK} ${PORT_MAP} ${VOL_MAP} ${REGISTRY}${IMAGE}${TAG} $@"
		;;
esac

if [ "${VERBOSE}" == "true" ]; then
	echo "${CMD}"
fi

if [ "${DRY_RUN}" == "false" ]; then
	RESULT=$(eval "${CMD}")
	echo ""
fi

if [ "${DEBUG}" == "true" ]; then
	set +x
fi
