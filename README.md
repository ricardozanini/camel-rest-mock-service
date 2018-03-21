# Camel Rest Mock Service

Camel Rest Service using Tomcat embeded server within Spring Boot (based on FIS 2.0 by Red Hat) to mock real services to be used on load tests scenarios.

## Maven configuration

[Red Hat repository](https://access.redhat.com/documentation/en-us/red_hat_jboss_fuse/6.3/html/fuse_integration_services_2.0_for_openshift/get-started-dev#get-started-configure-maven) **must** be set to run this installation.

## Lab Architecture

For this lab, the load tests were performed on a RHEL 7.4 virtual machine with 6GB of RAM and 2 vcores.

There's a Apache Web Server 2.4 acting as a proxy to by pass the HTTP requests to the Camel route exposed as a REST service. The route was created in a Spring Boot within a Tomcat embeded. The diagram bellow illustrates this architecture.

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

The responsibility of the Apache Web Server is to handle TLS connection and to proxy requests to Tomcat servers, acting as a _gatekeeper_.

## Baseline

The first thing to do is set a desired baseline for the service. For this example let's use 2000 simultaneous requests to the service with a response time of 1.5 seconds.

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

## Apache Tunning

Take the SLA requirements and try to tune the [MPM](https://httpd.apache.org/docs/2.4/mpm.html) accordinly. It isn't very nice [open a lot of connections](https://httpd.apache.org/docs/trunk/misc/perf-scaling.html#sizing-maxClients) on the Apache Web Server side if the JEE server can't handle it.

This is a _test and retry_ task. Try working on the load tests scenarios to have a number of simultaneous requests that the application can handle in a desired response time. This number should be the `MaxRequestWorkers` MPM `worker` configuration:

```
<IfModule mpm_worker_module>
        ThreadLimit         100
        ServerLimit         20
        StartServers        20
        MinSpareThreads     50
        MaxSpareThreads     100
        MaxRequestWorkers   2000
        ThreadsPerChild     100
        MaxRequestsPerChild 0
</IfModule>
```

In this example we're setting the maximum requests to 2000.

### MPM Configuration

Change the default MPM from **`prefork`** to **`worker`**. The `worker` [MPM gives better performance](https://stackoverflow.com/questions/13883646/apache-prefork-vs-worker-mpm) and it's a more suitable for a scenario using Apache Web Server to act as a proxy.

To change to `worker`, just uncomment line `LoadModule mpm_worker_module modules/mod_mpm_worker.so` on file `/opt/rh/jbcs-httpd24/root/etc/httpd/conf.modules.d/00-mpm.conf`. Don't forget to comment the `mod_mpm_prefork.so` MPM.

### MPM Event Bug

One of the justifications to use `worker` is a bug on `event`, as stated on [this KCS article from Red Hat](https://access.redhat.com/solutions/3035211): `AH00485: scoreboard is full, not at MaxRequestWorkers`. 

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