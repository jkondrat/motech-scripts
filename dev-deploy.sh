#!/bin/bash
MVN="mvn clean install -Dmaven.test.skip=true"
MOTECH_CONFIG=$HOME/.motech
CATALINA_HOME=$HOME/apache-tomcat

MOTECH_TRUNK=$HOME/motech
MOTECH_CHECKOUT=true
MOTECH_BRANCH=master

MOTECH_MODULES=$HOME/modules
MOTECH_MODULE_LIST=( csd message-campaign ivr sms )
MODULES_CHECKOUT=false
MODULES_BRANCH=dev/csd

REBUILD_MODULES=true

IMPL=$HOME/ebodac
IMPL_ENABLED=false

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
    checkoutPlatform
	mysql -u root -ppassword motechquartz < $MOTECH_TRUNK/modules/scheduler/sql/mysql_quartz_schema_v2.1.sql
}

function resetMdsDb {
	mysql -u root -ppassword -e 'drop database if exists motech_data_services; create database motech_data_services'
}

function checkoutPlatform {
    if [ "$MOTECH_CHECKOUT" = true ] ; then
    	cd $MOTECH_TRUNK
        git fetch
        git stash
        git checkout $MOTECH_BRANCH
        git rebase origin/$MOTECH_BRANCH
    fi
}

function rebuildPlatform {
    rm -rf $MOTECH_CONFIG
	checkoutPlatform   
	cd $MOTECH_TRUNK
	$MVN
}

function deployPlatform {
    rm -rf $CATALINA_HOME/webapps/motech-platform-server.war
    rm -rf $CATALINA_HOME/webapps/motech-platform-server
    cp $MOTECH_TRUNK/platform/server/target/motech-platform-server.war $CATALINA_HOME/webapps
}

function checkoutModules {
    cd $MOTECH_MODULES
    git fetch
    git stash
    git checkout $MODULES_BRANCH
    git rebase origin/$MODULES_BRANCH
}

function rebuildModules {
    if [ "$MODULES_CHECKOUT" = true ] ; then
        checkoutModules
    fi
    for module in "${MOTECH_MODULE_LIST[@]}"
    do
        cd $MOTECH_MODULES/"${module}"
        $MVN
    done
}

function rebuildImpl {
    if [ "$IMPL_ENABLED" = true ] ; then
    	cd $IMPL
    	$MVN
    fi
}

cd $HOME
if [ "$1" == "rebuild" ]; then
    stopTomcat
    if [ "$REBUILD_MODULES" = true ] ; then
        rebuildModules
    fi
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
