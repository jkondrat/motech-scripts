#!/bin/bash
MVN="mvn clean install -Dmaven.test.skip=true"
MOTECH_CONFIG=$HOME/.motech
CATALINA_HOME=$HOME/apache-tomcat

MOTECH_TRUNK=$HOME/motech
MOTECH_BRANCH=0.25.X

MOTECH_MODULES=$HOME/modules/message-campaign
MODULES_BRANCH=0.25.X

IMPL=$HOME/nyvrs
IMPL_BRANCH=master

function stopTomcat {
    $CATALINA_HOME/bin/catalina.sh jpda stop
	kill -9 $(ps aux | grep '[t]omcat' | awk '{print $2}')
}

function startTomcat {
    $CATALINA_HOME/bin/catalina.sh jpda start
	tail -f $CATALINA_HOME/logs/catalina.out
}

function resetQuartzDb {
	mysql -u root -ppassword -e 'drop database if exists motechquartz; create database motechquartz'
	checkoutPlatform $1
	mysql -u root -ppassword motechquartz < $MOTECH_TRUNK/modules/scheduler/sql/mysql_quartz_schema_v2.1.sql
}

function resetMdsDb {
	mysql -u root -ppassword -e 'drop database if exists motech_data_services; create database motech_data_services'
}

function checkoutPlatform {
	cd $MOTECH_TRUNK
    git fetch
	git reset --hard
    git checkout $MOTECH_BRANCH
    git rebase origin/$MOTECH_BRANCH
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
	cd $MOTECH_MODULES
    git fetch
    git reset --hard
	git checkout $MODULES_BRANCH
    git rebase origin/$MODULES_BRANCH
	$MVN
}

function rebuildImpl {
	cd $IMPL
 #    git fetch
 #    git rebase origin/$IMPL_BRANCH
	$MVN
}

cd $HOME
if [ "$1" == "rebuild" ]; then
    stopTomcat
    rebuildImpl
    startTomcat
elif [ "$1" == "resetdb" ]; then
	stopTomcat
    resetQuartzDb
    resetMdsDb
elif [ "$1" == "restart" ]; then
    stopTomcat
    startTomcat
elif [ "$1" == "stop" ]; then
    stopTomcat
elif [ "$1" == "install" ]; then
    stopTomcat
    resetQuartzDb
    resetMdsDb
    rebuildPlatform
    rebuildModules
    rebuildImpl
    deployPlatform
    startTomcat
fi
