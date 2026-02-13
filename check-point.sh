#!/bin/bash
source /etc/environment

RED=`tput setaf 1`
GREEN=`tput setaf 2`
VIOLET=`tput setaf 5`
RESET=`tput sgr0`

echo "=============================="
echo "CHECK POINT VERSION:3"
echo "HOME:${HOME}"
echo "MD5 CHECK..."
md5sum $0
echo "=============================="

if [ $# == 0 ]; then
	echo "${RED}STAGE NUMBER MISSED${RESET}"
	exit 1
fi

show_progress()
{
	echo "${VIOLET}$1${RESET}"
}

check_cmd()
{
	(bash -c "$1" 2>/dev/null) && echo "${GREEN}OK${RESET}" || echo "${RED}KO${RESET}"
}

STAGE_NB=$1

check_cmd_exact_from()
{
	if [ $STAGE_NB -lt $2 ] ; then
		(bash -c "$1" 2>/dev/null) && echo "${RED}KO${RESET}" || echo "${GREEN}OK${RESET}"
	else
		(bash -c "$1" 2>/dev/null) && echo "${GREEN}OK${RESET}" || echo "${RED}KO${RESET}"
	fi	
}

check_cmd_from()
{
	if [ ! $STAGE_NB -lt $2 ] ; then
		(bash -c "$1" 2>/dev/null) && echo "${GREEN}OK${RESET}" || echo "${RED}KO${RESET}"
	else
		echo "${GREEN}OK${RESET}"
	fi	
}

check_cmd_before()
{
	if [ $STAGE_NB -lt $2 ] ; then
		(bash -c "$1" 2>/dev/null) && echo "${RED}KO${RESET}" || echo "${GREEN}OK${RESET}"
	else
		echo "${GREEN}OK${RESET}"
	fi	
}

check_cmd_env_exact_from()
{
	if [ $STAGE_NB -lt $2 ] ; then
		test ! -z "$1" && echo "${RED}KO${RESET}" || echo "${GREEN}OK${RESET}"
	else
		test ! -z "$1" && echo "${GREEN}OK${RESET}" || echo "${RED}KO${RESET}"
	fi	
}


# STAGE 1
CURRENT_STAGE=1

show_progress "SCRIPT chap1/p3..."
check_cmd_exact_from "./chap1/p3" $CURRENT_STAGE

# STAGE 2
CURRENT_STAGE=2

show_progress "JAVA..."
check_cmd_exact_from "java -version" $CURRENT_STAGE

show_progress "JAVA_HOME..."
check_cmd_env_exact_from "$JAVA_HOME" $CURRENT_STAGE

show_progress "MAVEN..."
check_cmd_exact_from "mvn -version" $CURRENT_STAGE

show_progress "M2_HOME..."
check_cmd_env_exact_from "$M2_HOME" $CURRENT_STAGE

show_progress "GIT..."
check_cmd_from "git --version" $CURRENT_STAGE

show_progress "JENKINS..."
check_cmd_exact_from "jenkins --version" $CURRENT_STAGE

# STAGE 3
CURRENT_STAGE=3

show_progress "DOCKER..."
check_cmd_exact_from "docker --version" $CURRENT_STAGE

show_progress "DOCKER FILE..."
check_cmd_exact_from "test -f ./chap3/Dockerfile" $CURRENT_STAGE

show_progress "DOCKER IMAGE..."
check_cmd_exact_from "docker image ls|grep alpine" $CURRENT_STAGE

# STAGE 4
CURRENT_STAGE=4

show_progress "TIMESHEET PROJECT..."
check_cmd_exact_from "test -d timesheet-project" $CURRENT_STAGE

show_progress "GIT INIT..."
check_cmd_exact_from "test -d timesheet-project/.git" $CURRENT_STAGE

show_progress "MYSQL..."
check_cmd_exact_from "docker image ls|grep mysql" $CURRENT_STAGE

show_progress "TIMESHEET IMAGE..."
check_cmd_exact_from "docker image ls|grep timesheet" $CURRENT_STAGE

show_progress "DOCKER COMPOSE..."
check_cmd_exact_from "test -f timesheet-project/Docker-compose.yml" $CURRENT_STAGE

show_progress "MINIKUBE..."
check_cmd_exact_from "minikube version" $CURRENT_STAGE

show_progress "KUBECTL..."
check_cmd "! test -f kubectl"
check_cmd_exact_from "kubectl version --client" $CURRENT_STAGE

# STAGE 5
CURRENT_STAGE=5

show_progress "YAML FILES..."
check_cmd_exact_from "test -f chap4/mysql-pvc.yml" $CURRENT_STAGE
check_cmd_exact_from "test -f chap4/mysql-deployment.yml" $CURRENT_STAGE
check_cmd_exact_from "test -f chap4/mysql-service.yml" $CURRENT_STAGE
check_cmd_exact_from "test -f chap4/timesheet-config.yml" $CURRENT_STAGE
check_cmd_exact_from "test -f chap4/timesheet-secret.yml" $CURRENT_STAGE
check_cmd_exact_from "test -f chap4/timesheet-deployment.yml" $CURRENT_STAGE
check_cmd_exact_from "test -f chap4/timesheet-service.yml" $CURRENT_STAGE

show_progress "CONFIG MAP..."
check_cmd_exact_from "kubectl get configMaps -n chap4|grep timesheet-config" $CURRENT_STAGE

show_progress "CONFIG MAP..."
check_cmd_exact_from "kubectl get secret -n chap4|grep timesheet-secret" $CURRENT_STAGE

show_progress "PODS..."
check_cmd_exact_from "kubectl get pods -n chap4|grep mysql-dep" $CURRENT_STAGE
check_cmd_exact_from "kubectl get pods -n chap4|grep timesheet-dep" $CURRENT_STAGE

# STAGE 6
CURRENT_STAGE=6

show_progress "SONARQUBE IMAGE..."
check_cmd_exact_from "docker image ls|grep sonarqube" $CURRENT_STAGE

show_progress "SONARQUBE CONTAINER..."
check_cmd_exact_from "docker container ls -a|grep sonarqube" $CURRENT_STAGE

show_progress "SONARQUBE SCRIPTS..."
check_cmd_exact_from "test -f sonarqube-up.sh" $CURRENT_STAGE
check_cmd_exact_from "test -f sonarqube-down.sh" $CURRENT_STAGE

# STAGE 7
CURRENT_STAGE=7

show_progress "PROMETHEUS IMAGE..."
check_cmd_exact_from "docker image ls|grep prometheus" $CURRENT_STAGE

show_progress "GRAFANA IMAGE..."
check_cmd_exact_from "docker image ls|grep grafana" $CURRENT_STAGE