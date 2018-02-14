#!/bin/sh

DIRNAME=`dirname $0`
PROGNAME=`basename $0`

die() {
    warn "$*"
    exit 1
}


locateJava() {
    # Setup the Java Virtual Machine
    if [ "x$JAVA_HOME" != "x" ]; then
        if [ ! -d "$JAVA_HOME" ]; then
            die "JAVA_HOME is not valid: $JAVA_HOME"
        fi
        JAVA="$JAVA_HOME/bin/java"
    else
        warn "JAVA_HOME not set; results may vary"
        JAVA=`type java`
        JAVA=`expr "$JAVA" : '.* \(/.*\)$'`
        if [ "x$JAVA" = "x" ]; then
            die "java command not found"
        fi
    fi
}


locateHome() {
    # In POSIX shells, CDPATH may cause cd to write to stdout
    (unset CDPATH) >/dev/null 2>&1 && unset CDPATH
    
    SERVICE_HOME=`cd "$DIRNAME/../../target"; pwd`
    if [ ! -d "$SERVICE_HOME" ]; then
        die "SERVICE_HOME is not valid: $SERVICE_HOME"
    fi
}

locateStartHome() {
    START_HOME=`cd "$DIRNAME"; pwd`
    if [ ! -d "$START_HOME" ]; then
        die "START_HOME is not valid: $START_HOME"
    fi
}

startService() {
    cd $SERVICE_HOME
    SERVICE_JAR=`ls *.jar`
    # external properties https://docs.spring.io/spring-boot/docs/current/reference/html/boot-features-external-config.html
    echo "Starting service at $SERVICE_HOME"
    
    # https://stackoverflow.com/questions/29412072/how-to-access-spring-boot-jmx-remotely
    JMX_OPTS="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=12348 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.rmi.port=12349"
    GC_OPTS="-XX:+PrintGCTimeStamps -XX:+PrintGCDetails -Xloggc:$SERVICE_HOME/log/gc.log -verbose:gc"

    rm -rf "$SERVICE_HOME/log/*"

    # go!
    $JAVA -DLOG_DIR=$SERVICE_HOME $GC_OPTS $JMX_OPTS -jar $SERVICE_JAR --logging.config=file:$START_HOME/logback.xml --spring.config.location=file:$START_HOME/application.yml
}

init() {
    # locate the service home
    locateHome
    locateStartHome
    # locate java
    locateJava
    # start the service
    startService
}

init

