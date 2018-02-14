# Camel Rest Mock Service

Camel Rest Service using Tomcat embeded server within Spring Boot (based on FIS 2.0 by Red Hat) to mock real services to be used on load tests scenarios.

## Maven configuration

[Red Hat repository](https://access.redhat.com/documentation/en-us/red_hat_jboss_fuse/6.3/html/fuse_integration_services_2.0_for_openshift/get-started-dev#get-started-configure-maven) **must** be set to run this installation.

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

## Tomcat Tuning

