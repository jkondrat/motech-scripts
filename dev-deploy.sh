#!/bin/bash
MVN="mvn clean install -Dmaven.test.skip=true"
MOTECH_CONFIG=$HOME/.motech
CATALINA_HOME=$HOME/tomcat

MOTECH_TRUNK=$HOME/motech/
MOTECH_BRANCH=tags/motech-0.24

MOTECH_MODULES=$HOME/modules
MODULES_BRANCH=dev/whp

IMPL=$HOME/whp-mTraining
IMPL_BRANCH=origin/master

function stopTomcat {
    $CATALINA_HOME/bin/catalina.sh jpda stop
    sleep 1
	kill -9 $(ps aux | grep '[t]omcat' | awk '{print $2}')
}

function startTomcat {
	echo "" > $CATALINA_HOME/logs/catalina.out
    $CATALINA_HOME/bin/catalina.sh jpda start
	tail -f $CATALINA_HOME/logs/catalina.out
}

function resetMdsDb {
	mysql -u root -ppassword -e 'drop database if exists motech_data_services; create database motech_data_services'
}

function checkoutPlatform {
	cd $MOTECH_TRUNK
    git fetch
	git reset --hard
    git checkout $1
}

function rebuildPlatform {
    rm -rf $MOTECH_CONFIG
	checkoutPlatform $1
	cd $MOTECH_TRUNK
	$MVN
}

function deployPlatform {
    rm -rf $CATALINA_HOME/webapps/motech-platform-server.war
    rm -rf $CATALINA_HOME/webapps/motech-platform-server
    cp $MOTECH_TRUNK/platform/server/target/motech-platform-server.war $CATALINA_HOME/webapps
}

function rebuildModules {
	cd $MOTECH_MODULES/mtraining/
    git fetch
	git checkout $MODULES_BRANCH
	$MVN
}

function rebuildImpl {
	cd $IMPL
    git fetch
	git rebase $IMPL_BRANCH
	$MVN
}

cd $HOME
if [ "$1" == "impl" ]; then
    stopTomcat
    rebuildImpl
    startTomcat
elif [ "$1" == "mtraining" ]; then
    stopTomcat
    rebuildModules
    rebuildImpl
    startTomcat
elif [ "$1" == "resetdb" ]; then
	stopTomcat
    resetMdsDb
elif [ "$1" == "restart" ]; then
    stopTomcat
    startTomcat
elif [ "$1" == "stop" ]; then
    stopTomcat
elif [ "$1" == "deploy" ]; then
    stopTomcat
    resetMdsDb
    rebuildPlatform
    rebuildModules
    rebuildImpl
    deployPlatform
    startTomcat
else
    echo ''
fi
