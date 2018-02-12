package org.m88i.camel.mockservice;

import org.apache.camel.component.servlet.CamelHttpTransportServlet;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.servlet.ServletRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.ComponentScan;

@SpringBootApplication
@ComponentScan(basePackages = "org.m88i.camel.mockservice")
public class CamelRestApplication {

	public static void main(String[] args) {
		SpringApplication.run(CamelRestApplication.class, args);
	}

	@Bean
	ServletRegistrationBean servletRegistrationBean() {
		ServletRegistrationBean servlet = new ServletRegistrationBean(new CamelHttpTransportServlet(), "/r/api/v1/*");
		servlet.setName("CamelServlet");
		return servlet;
	}
}
