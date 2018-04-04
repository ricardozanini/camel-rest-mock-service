# Camel Rest Mock Service

A Camel Rest Service using Tomcat embedded server within Spring Boot (based on FIS 2.0 by Red Hat) to mock real services to be used on load tests scenarios.

## Lab Architecture

For this lab, the load tests were performed on a RHEL 7.4 virtual machine with 6GB of RAM and 2 vcores.

There's a Apache Web Server 2.4 acting as a proxy to by pass the HTTP requests to the Camel route exposed as a REST service. The route was created in a Spring Boot application with Tomcat embedded. The diagram bellow illustrates this architecture.

```
+-----------+                  +------------------------+
|           |   ProxyPass      |                        |
|           | +--------------> |Camel Spring Boot (8081)|
|           |                  +------------------------+
|           |
|           |                  +------------------------+
|           |   ProxyPass      |                        |
|           | +--------------> |Camel Spring Boot (8181)|
|           |                  +------------------------+
|           |
|           |                  +------------------------+
|           |   ProxyPass      |                        |
|           | +--------------> |Camel Spring Boot (8281)|
| JBCS 2.4  |                  +------------------------+
|    Web    |
|  Server   |                  +------------------------+
|           |   ProxyPass      |                        |
|           | +--------------> |Camel Spring Boot (8381)|
|           |                  +------------------------+
|           |
|           |                  +------------------------+
|           |   ProxyPass      |                        |
|           | +--------------> |Camel Spring Boot (8481)|
|           |                  +------------------------+
|           |
|           |                  +------------------------+
|           |   ProxyPass      |                        |
|           | +--------------> |Camel Spring Boot (8581)|
+-----------+                  +------------------------+
```

The responsibility of the Apache Web Server is to handle TLS connections and to proxy requests to Tomcat servers. It's also acting as a _gatekeeper_ to only allow a pre determined connections to the Tomcat servers. This way we can deny connections to the client on the web server side, avoiding unnecessary load to the Tomcat servers.

This strategy allow us to have the following metrics on our APM tool:

1. **Number of connection errors**. If this number increases, it's means that we need to scale up our servers.
2. **Number of simultaneous requests**. After the load tests we'll have a baseline number of simultaneous requests that we can handle. We can monitor this metric to help us understand the requests volume in the environment and justify a cluster increase.

## Maven configuration

[Red Hat repository](https://access.redhat.com/documentation/en-us/red_hat_jboss_fuse/6.3/html/fuse_integration_services_2.0_for_openshift/get-started-dev#get-started-configure-maven) **must** be set on target machine to run this service.

## Apache server configuration

### Installation

First, the Apache Web Server 2.4 must be installed with: `sudo​ ​yum​ ​group​ ​install​ ​jbcs​-​httpd24`. This package should be enabled via `subscription-manager`:

1. Register your VM with `subscription-manager register --username=<user> --password=<pass>`
2. Attach a pool with JBCS Core Services: `subscription-manager attach --pool=<poolid>`
3. Enable the package: `subscription-manager repos --enable=jb-coreservices-1-for-rhel-7-server-rpms`

### Location Configuration

To leave the services configuration apart from defaults, add a file in the path `/opt/rh/jbcs-httpd24/root/etc/httpd/conf.d/` named `camelservice.conf` with the following contents:

```conf
ExtendedStatus On

<VirtualHost *:80>
        IncludeOptional conf.d/camel/*.conf
</VirtualHost>
```

Then, in file the `/opt/rh/jbcs-httpd24/root/etc/httpd/conf.d/camel/mockservice.conf`, set up the reverse proxy for the Camel services on the embeded Tomcat. For each Tomcat server, a new `Location` must be set.

```conf
# camel service endpoint
<Location /0/camel>
        ProxyPass http://localhost:8081
        ProxyPassReverse http://localhost:8081
        ProxyPassReverseCookiePath / /0/camel
</Location>

# server status
<Location /server-status>
        SetHandler server-status
</Location>
```

This configuration also enables the [Apache status page](https://httpd.apache.org/docs/2.4/mod/mod_status.html) to use it as a monitoring resource during the load tests execution.

**Tip:** The startup script (`bin/startup.sh`) prints the `Location` configuration.

## Open Firewall ports

The following ports should be opened on the service machine to allow JMX remote connection and service connection:

```shell
firewall-cmd --zone=public --add-port=12349/tcp --permanent
firewall-cmd --zone=public --add-port=12348/tcp --permanent
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --reload
```

**Tip:** The startup script prints the `firewall-cmd` command for each server.

## Tools

- [VisualVM](https://visualvm.github.io/) for JVM monitoring
- [Apache Benchmark Tool](http://httpd.apache.org/docs/current/programs/ab.html) - `yum install httpd-tools` - for load tests
- [Apache JMeter](http://jmeter.apache.org/)

## Load Test

The load test was performed using Apache JMeter. The project can be found in `jmeter/load_test.jmx`. The aim of this test is to maintain a given number of requests during a long period of time. This way we can observe the service behavior under high load and take the necessary actions to meet the desired SLA.

## Service SLA

The first thing to do is set a desired SLA for the service. For this example we used 400 simultaneous requests to the service with a response time of 1.5 seconds. The idea is to observe the service behavior during the load tests:

1. If the SLA is too optimistic, the request number could be decreased while tuning the infra-structure. 
2. If we still have more room to increase, just make it bigger.

There's no secret. A load test process is configure the environment, run tests, observe their behavior and do it all again until the expected goal is met.

## Apache Tuning

Take the SLA requirements and try to tune the [MPM](https://httpd.apache.org/docs/2.4/mpm.html) accordingly. It isn't very nice to [open a lot of connections](https://httpd.apache.org/docs/trunk/misc/perf-scaling.html#sizing-maxClients) on the Apache Web Server side if the JEE server can't handle it.

This is a _test and retry_ task. Try working on the load tests scenarios to have a number of simultaneous requests that the application can handle in a desired response time. This number should be the `MaxRequestWorkers` MPM `worker` configuration:

```
<IfModule mpm_worker_module>
        ThreadLimit         40
        ServerLimit         10
        StartServers        5
        MinSpareThreads     5
        MaxSpareThreads     20
        MaxRequestWorkers   400
        ThreadsPerChild     10
        MaxRequestsPerChild 0
</IfModule>
```

In this example we're setting the maximum requests to 400.

### MPM Configuration

Change the default MPM from **`prefork`** to **`worker`**. The `worker` [MPM gives better performance](https://stackoverflow.com/questions/13883646/apache-prefork-vs-worker-mpm) and it's a more suitable for a scenario using Apache Web Server acting as a proxy.

To change to `worker`, just remove the comment on line `LoadModule mpm_worker_module modules/mod_mpm_worker.so` in file `/opt/rh/jbcs-httpd24/root/etc/httpd/conf.modules.d/00-mpm.conf`. Don't forget to comment the `mod_mpm_prefork.so` MPM. 

There's a [Red Hat article](https://access.redhat.com/solutions/2063063) detailing how to switch the MPM used in Apache Web Server.

### MPM Event Bug

One of the justifications to use `worker` instead of `event` is a bug on it, as stated on [this KCS article from Red Hat](https://access.redhat.com/solutions/3035211): `AH00485: scoreboard is full, not at MaxRequestWorkers`. 

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

Tuning Tomcat is a matter of configure the `max-connections`, `timeouts`, `threads` and `accept count`. For this lab, the following parameters were set:

```yaml
server:
  connection-timeout: 10000
  compression:
    enabled: false
  tomcat:
    max-connections: 400
    max-threads: 200
    min-spare-threads: 150
    accept-count: 100
```

It's a matter of test and observe, thought. Check [this article](https://javamaster.wordpress.com/2013/03/13/apache-tomcat-tuning-guide/) written by Terry Cho regarding Tomcat tuning. It's a little bit old, but has valuable information about this topic.

Pay attention on the `max-threads` number. This parameter is to limit the thread number that the Tomcat will create to handle requests. If this number is to high to the number of connections that it's handling, you are spending valuable machine resources. The trick is to test with a lower number and observe the requests metrics until you come up with the number for your requirement.

## JVM Tuning

I have some rules of thumb regarding JVM tuning:

1. Set both `-Xmx` and `-Xms` to the same value
2. Configure GC logs [accordingly](https://dzone.com/articles/understanding-garbage-collection-log)
3. Always set `-XX:+HeapDumpOnOutOfMemoryError` and `-XX:HeapDumpPath` so if anytime the server faces an `OutOfMemoryError` at least you [have resources for troubleshooting](https://docs.oracle.com/javase/8/docs/technotes/guides/troubleshoot/prepapp002.html)

Take a look at the nice article [Java VM Options You Should Always Use in Production](http://blog.sokolenko.me/2014/11/javavm-options-production.html) published by Anatoliy Sokolenko. There's a bunch of tips regarding JVM tune. Also, Red Hat has a [nice tool](https://access.redhat.com/labs/jvmconfig/) to help set JVM settings (available to subscribers).

There isn't a magic number for JVM heap size. You must run load tests and observe your metrics to configure it correctly.

## Logback Tuning

One thing that most people forget about is to configure the server log module:

1. Low the server log verbosity to `INFO` (or `WARN`) unless you have a very good reason to not do so.
2. Prefer using [async log](https://blog.takipi.com/how-to-instantly-improve-your-java-logging-with-7-logback-tweaks/) to avoid stopping application threads to flush into disk prior to continue its execution.

This lab uses Spring Boot and so Logback to perform logging. To turn on async logging in Logback is [pretty straight forward](https://logback.qos.ch/manual/appenders.html#AsyncAppender). Just be aware to not discard log messages if it isn't desired to, like application's Splunk or Data Dog logs. This behavior can be achieved by setting `discardingThreshold` to 0 and `neverBlock` to 0.

## Apache JMeter

This is the tool chosen to perform our load test. It's pretty straight forward and can be configured easily. Check the project in `jmeter/load_test.jmx` and configure the parameters accordingly to your necessity.

### Generating reports

1. Configure the `user.properties` on JMeter home according to the [dashboard documentation](http://jmeter.apache.org/usermanual/generating-dashboard.html).
2. Save the CSV result file on the `Aggregate Report` tab (`$PROJECT_HOME/jmeter/results.csv`).
3. Generate the report after performing the load test by running `jmeter -g jmeter/results.csv -o jmeter/results-output`.