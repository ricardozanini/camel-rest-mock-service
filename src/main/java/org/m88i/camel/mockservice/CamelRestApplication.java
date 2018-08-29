package org.m88i.camel.mockservice;

import org.apache.camel.component.servlet.CamelHttpTransportServlet;
import org.apache.catalina.connector.Connector;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.embedded.EmbeddedServletContainerFactory;
import org.springframework.boot.context.embedded.tomcat.TomcatEmbeddedServletContainerFactory;
import org.springframework.boot.web.servlet.ServletRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.ComponentScan;

@SpringBootApplication
@ComponentScan(basePackages = "org.m88i.camel.mockservice")
public class CamelRestApplication {
    
    private static final String PROTOCOL = "AJP/1.3";
    private static final String MAX_CONN_PROP = "maxConnections";
    private static final String ACCEPT_COUNT_PROP = "acceptCount";

    @Value("${server.tomcat.ajp-port}") // Defined on application.properties
    private Integer ajpPort;
    
    @Value("${server.tomcat.max-connections}") 
    private Integer maxConnections;
    
    @Value("${server.tomcat.accept-count}") 
    private Integer acceptCount;

    public static void main(String[] args) {
        SpringApplication.run(CamelRestApplication.class, args);
    }
    
    @Bean
    public EmbeddedServletContainerFactory servletContainer() {
        TomcatEmbeddedServletContainerFactory tomcat = new TomcatEmbeddedServletContainerFactory();
        Connector ajpConnector = new Connector(PROTOCOL);
        ajpConnector.setProtocol(PROTOCOL);
        ajpConnector.setPort(ajpPort);
        if(maxConnections != null) {
            ajpConnector.setProperty(MAX_CONN_PROP, maxConnections.toString());
        }
        if(acceptCount != null) {
            ajpConnector.setProperty(ACCEPT_COUNT_PROP, acceptCount.toString());
        }
        tomcat.addAdditionalTomcatConnectors(ajpConnector);
        return tomcat;
    }   

    @Bean
    ServletRegistrationBean servletRegistrationBean() {
        ServletRegistrationBean servlet = new ServletRegistrationBean(new CamelHttpTransportServlet(), "/r/api/v1/*");
        servlet.setName("CamelServlet");
        return servlet;
    }
}
