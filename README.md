# Camel Rest Mock Service

Camel Rest Service using Tomcat embeded server within Spring Boot (based on FIS 2.0 by Red Hat) to mock real services to be used on load tests scenarios.

## Maven configuration

[Red Hat repository](https://access.redhat.com/documentation/en-us/red_hat_jboss_fuse/6.3/html/fuse_integration_services_2.0_for_openshift/get-started-dev#get-started-configure-maven) **must** be set to run this installation.

## Lab Architecture

For this lab, the load tests were performed on a RHEL 7.4 virtual machine with 6GB of RAM and 2 vcores.

```
+-----------+                  +------------------------+
|           |                  |                        |
|           |                  |Camel Spring Boot (8081)|
|           |                  +------------------------+
|           |
|           |                  +------------------------+
|           |                  |                        |
|           |                  |Camel Spring Boot (8181)|
|           |                  +------------------------+
|           |
|           |                  +------------------------+
|           |   ProxyPass      |                        |
|           | +--------------> |Camel Spring Boot (8281)|
| JBCS 2.4  |                  +------------------------+
|    Web    |
|  Server   |                  +------------------------+
|           |                  |                        |
|           |                  |Camel Spring Boot (8381)|
|           |                  +------------------------+
|           |
|           |                  +------------------------+
|           |                  |                        |
|           |                  |Camel Spring Boot (8481)|
|           |                  +------------------------+
|           |
|           |                  +------------------------+
|           |                  |                        |
|           |                  |Camel Spring Boot (8581)|
+-----------+                  +------------------------+
```

## Apache server configuration

We're going to expose the service through a Apache Web Server (JBCS from Red Hat `sudo​ ​yum​ ​group​ ​install​ ​jbcs​-​httpd24`):

In file the `/opt/rh/jbcs-httpd24/root/etc/httpd/conf.d/camel/mockservice.conf`:

```conf
# camel service endpoint
<Location /camel>
        ProxyPass http://localhost:8081
        ProxyPassReverse http://localhost:8081
        ProxyPassReverseCookiePath / /camel
</Location>
# spring boot actuator
<Location /camel/mgmnt>
        ProxyPass http://localhost:8083
        ProxyPassReverse http://localhost:8083
        ProxyPassReverseCookiePath / /camel/mgmnt
</Location>
```

## Open Firewall ports

The following ports should be opened on service machine to allow JMX remote connection and service connection:

```shell
firewall-cmd --zone=public --add-port=12349/tcp --permanent
firewall-cmd --zone=public --add-port=12348/tcp --permanent
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --reload
```

## Tools

- [VisualVM](https://visualvm.github.io/) for JVM monitoring
- [Apache Benchmark Tool](http://httpd.apache.org/docs/current/programs/ab.html) - `yum install httpd-tools` - for load tests
- [Apache JMeter](http://jmeter.apache.org/)

## Load Test

## Apache Tunning

Refs:

1. [Sizing MaxClients](https://httpd.apache.org/docs/trunk/misc/perf-scaling.html#sizing-maxClients)

### MPM Event Bug

One of the justifications to use worker is a bug on `event`, as stated on [this KCS article from Red Hat](https://access.redhat.com/solutions/3035211): `AH00485: scoreboard is full, not at MaxRequestWorkers`. 

The jbcs-httpd version used on this lab is `2.2.23` (waiting for the fix):

```log
Server version: Apache/2.4.23 (Red Hat)
Server built:   Nov  6 2017 12:21:08
Server's Module Magic Number: 20120211:61
Server loaded:  APR 1.5.2, APR-UTIL 1.5.4
Compiled using: APR 1.5.2, APR-UTIL 1.5.4
Architecture:   64-bit
Server MPM:     event
  threaded:     yes (fixed thread count)
    forked:     yes (variable process count)
Server compiled with....
 -D APR_HAS_SENDFILE
 -D APR_HAS_MMAP
 -D APR_HAVE_IPV6 (IPv4-mapped addresses enabled)
 -D APR_USE_SYSVSEM_SERIALIZE
 -D APR_USE_PTHREAD_SERIALIZE
 -D SINGLE_LISTEN_UNSERIALIZED_ACCEPT
 -D APR_HAS_OTHER_CHILD
 -D AP_HAVE_RELIABLE_PIPED_LOGS
 -D DYNAMIC_MODULE_LIMIT=256
 -D HTTPD_ROOT="/opt/rh/jbcs-httpd24/root/etc/httpd"
 -D SUEXEC_BIN="/opt/rh/jbcs-httpd24/root/usr/sbin/suexec"
 -D DEFAULT_PIDLOG="/run/httpd/httpd.pid"
 -D DEFAULT_SCOREBOARD="logs/apache_runtime_status"
 -D DEFAULT_ERRORLOG="logs/error_log"
 -D AP_TYPES_CONFIG_FILE="conf/mime.types"
 -D SERVER_CONFIG_FILE="conf/httpd.conf"
```

## Tomcat Tuning

## JVM Tuning

## Logback Tuning

## Apache JMeter

### Generating reports

1. Configure the `user.properties` on JMeter home according to the [dashboard documentation](http://jmeter.apache.org/usermanual/generating-dashboard.html).
2. Save the CSV result file on the `Aggregate Report` tab (`$PROJECT_HOME/jmeter/results.csv`).
3. Generate the report after performing the load test by running `jmeter -g jmeter/results.csv -o jmeter/results-output`.