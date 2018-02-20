#!/bin/sh

DIRNAME=`dirname $0`
PROGNAME=`basename $0`
DEFAULT_SERVERS=1
DEFAULT_MEM=512
DEFAULT_META=$(( $DEFAULT_MEM / 8 ))
DEFAULT_S_PORT=8081
DEFAULT_M_PORT=8083
DEFAULT_JMX_PORT=12348

SERVERS=$DEFAULT_SERVERS
MEM=$DEFAULT_MEM
META=$DEFAULT_META

die() {
    warn "$*"
    exit 1
}

calcMem() {
    if [ "x$1" = "x" ] || [ $1 = $DEFAULT_MEM ]; then
        MEM=$DEFAULT_MEM
        META=$DEFAULT_META
    else
        MEM=$1
        META=$(( $MEM / 8 ))
    fi

    echo "============================================="
    echo "JVM Max size is $MEM"
    echo "Max Metaspace sice is $META"
    echo "============================================="
}

setServersNum() {
    if [ "x$1" = "x" ]; then
        SERVERS=$DEFAULT_SERVERS
    else
        SERVERS=$1
    fi
    echo "Servers instances set to $SERVERS"
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
    
    SERVICE_HOME=`cd "$DIRNAME/../target"; pwd`
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
    echo "Starting services at $SERVICE_HOME"
    
    # clean up old logs
    rm -rf "$SERVICE_HOME/log"
    mkdir "$SERVICE_HOME/log"

    # vars
    JMX_PORT=$DEFAULT_JMX_PORT
    RMI_PORT=$(( JMX_PORT + 1 ))
    SERVER_PORT=$DEFAULT_S_PORT
    MGMN_PORT=$DEFAULT_M_PORT

    for ((S=0; S<$SERVERS; S++))
    do
        # https://stackoverflow.com/questions/29412072/how-to-access-spring-boot-jmx-remotely
        JMX_OPTS="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.rmi.port=${RMI_PORT} -Dcom.sun.management.jmxremote.port=${JMX_PORT} -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
        GC_OPTS="-XX:+PrintGCApplicationStoppedTime -XX:+PrintGCTimeStamps -XX:+PrintGCDetails -Xloggc:$SERVICE_HOME/log/gc.${S}.log -verbose:gc -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$SERVICE_HOME/log/"
        JVM_OPTS="-server -Xmx${MEM}M -Xms${MEM}M -XX:+AggressiveOpts -XX:MetaspaceSize=${META}M -XX:MaxMetaspaceSize=${META}M -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=70 -XX:+ScavengeBeforeFullGC -XX:+CMSScavengeBeforeRemark"
        
        touch "$SERVICE_HOME/log/gc.$S.log"

        # go!
        $JAVA -DLOG_DIR=$SERVICE_HOME -Dserver.port=$SERVER_PORT -Dmanagement.port=$MGMN_PORT $JVM_OPTS  $GC_OPTS $JMX_OPTS -jar $SERVICE_JAR --logging.config=file:$START_HOME/async-logback.xml --spring.config.location=file:$START_HOME/application.yml &

        echo ">> Started server on port $SERVER_PORT, management port on $MGMN_PORT and JMX remote port on $JMX_PORT"
        echo ">> Open ports for JMX monitoring:"
        echo ">> firewall-cmd --zone=public --add-port=$JMX_PORT/tcp --permanent"
        echo ">> firewall-cmd --zone=public --add-port=$RMI_PORT/tcp --permanent"
        echo ">> firewall-cmd --reload"
        echo ">>"
        echo ">> Add this Location to your httpd server"
        echo "<Location /camel/${S}>"
        echo "  ProxyPass http://localhost:${SERVER_PORT}"
        echo "  ProxyPassReverse http://localhost:${SERVER_PORT}"
        echo "  ProxyPassReverseCookiePath / /camel/${S}"
        echo "</Location>"

        JMX_PORT=$((JMX_PORT+2))
        RMI_PORT=$((RMI_PORT+2))
        SERVER_PORT=$((SERVER_PORT+100))
        MGMN_PORT=$((MGMN_PORT+100))
    done 
    
}

init() {
    # locate the service home
    locateHome
    locateStartHome
    calcMem $1
    setServersNum $2
    # locate java
    locateJava
    # start the service
    startService
}

# $1 = memory, $2 server instances
init $1 $2

