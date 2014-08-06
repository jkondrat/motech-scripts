#!/bin/bash
MVN="mvn clean install -Dmaven.test.skip=true"
MOTECH_CONFIG=$HOME/.motech
#CATALINA_HOME=$HOME/apache-tomcat-7.0.22

MOTECH_TRUNK=$HOME/motech/motech
MOTECH_BRANCH=origin/0.24.X
MOTECH_BRANCH_OLD=tags/motech-0.22

MOTECH_COMMUNICATIONS=$HOME/motech/motech-communications
MOTECH_MODULES=$HOME/motech/modules
MODULES_BRANCH=origin/0.24.X

IMPL=$HOME/motech/whp-mTraining
IMPL_BRANCH=origin/phase2

function stopTomcat {
    $CATALINA_HOME/bin/catalina.sh jpda stop
    sleep 2
	kill -9 $(ps aux | grep '[t]omcat' | awk '{print $2}')
}

function startTomcat {
	echo "" > $CATALINA_HOME/logs/catalina.out
    $CATALINA_HOME/bin/catalina.sh jpda start
	tail -f $CATALINA_HOME/logs/catalina.out
}

function restartTomcat {
    stopTomcat
    startTomcat
}

function createQuartzDb {
    mysql -u root -ppassword -e 'drop database if exists motechquartz; create database motechquartz'
    checkoutPlatform $1
	if [ "$1" == $MOTECH_BRANCH_OLD ]; then
		mysql -u root -ppassword motechquartz < $MOTECH_TRUNK/modules/scheduler/scheduler/sql/create_db_schema_quartz_v2.1.sql
	else 
		mysql -u root -ppassword motechquartz < $MOTECH_TRUNK/modules/scheduler/sql/create_db_schema_quartz_v2.1.sql
	fi
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

function modifyPlatformPom {
	cd $MOTECH_TRUNK
	awk 'NR==164{$0="				<dependencies>\n\
				<!-- override the default dependency -->\n\
				<dependency>\n\
					<groupId>org.datanucleus</groupId>\n\
					<artifactId>datanucleus-core</artifactId>\n\
					<version>3.2.11</version>\n\
				</dependency>\n\
			</dependencies>\n"$0}1' modules/mds/pom.xml > res.txt
	mv res.txt modules/mds/pom.xml
}

function rebuildPlatform {
    rm -rf $MOTECH_CONFIG
	checkoutPlatform $1
	if [ "$1" == $MOTECH_BRANCH_OLD ]; then
		modifyPlatformPom
	fi
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

function rebuildCommunications {
	cd $MOTECH_COMMUNICATIONS
	$MVN
}

function modifyImplPom {
	cd $IMPL
	awk 'NR==175{$0="            <version>3.2.10</version>"}1' mtraining/pom.xml | \
	awk 'NR==164{$0="        <dependency>\n\
            <groupId>javax.time</groupId>\n\
            <artifactId>org.motechproject.javax.time</artifactId>\n\
            <version>0.6.3-${external.dependency.release.tag}</version>\n\
        </dependency>\n"$0}1' > res.txt
	mv res.txt mtraining/pom.xml
}

function rebuildImpl {
	cd $IMPL
	if [ "$1" == $MOTECH_BRANCH_OLD ]; then
		git reset --hard 57cc9ce87527f0996d88aa589941864689da4378
		modifyImplPom
	elif [ "$1" == $MOTECH_BRANCH ]; then
        git fetch
		git rebase $IMPL_BRANCH
	fi
	$MVN
}

cd $HOME
if [ "$1" == "mtraining" ]; then
    stopTomcat
    rebuildModules
    rebuildImpl
    startTomcat
elif [ "$1" == "impl" ]; then
    stopTomcat
    rebuildImpl
    startTomcat
elif [ "$1" == "mod" ]; then
    stopTomcat
    rebuildModules
    startTomcat
elif [ "$1" == "resetdb" ]; then
	stopTomcat
    createQuartzDb
    resetMdsDb
elif [ "$1" == "restart" ]; then
    restartTomcat
elif [ "$1" == "stop" ]; then
    stopTomcat
elif [ "$1" == "old" ]; then	
	# TODO old version:
	# Create database named "whp" in Postgres
    stopTomcat
    createQuartzDb $MOTECH_BRANCH_OLD
    rebuildPlatform $MOTECH_BRANCH_OLD
    rebuildCommunications
    rebuildImpl $MOTECH_BRANCH_OLD
    deployPlatform
    startTomcat
else
    stopTomcat
    createQuartzDb $MOTECH_BRANCH
    resetMdsDb
    rebuildPlatform $MOTECH_BRANCH
    rebuildModules
    rebuildImpl $MOTECH_BRANCH
    deployPlatform
    startTomcat
fi
