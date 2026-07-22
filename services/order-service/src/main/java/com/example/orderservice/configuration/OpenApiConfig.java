package com.example.orderservice.configuration;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;

@Configuration
public class OpenApiConfig {

    //private static final String BASIC_AUTH = "basicAuth";
    private static final String BEARER_AUTH = "bearerAuth";

    @Bean
    public OpenAPI openAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("Resilient Order Platform API")
                .version("1.0")
                .description("Spring Boot microservices practice API")
            )
            .components(new Components()
                // .addSecuritySchemes(BASIC_AUTH, new SecurityScheme()
                //     .type(SecurityScheme.Type.HTTP)
                //     .scheme("basic")
                // )
                .addSecuritySchemes(BEARER_AUTH, new SecurityScheme()
                    .type(SecurityScheme.Type.HTTP)
                    .scheme("bearer")
                    .bearerFormat("JWT")
                )
            )
            //.addSecurityItem(new SecurityRequirement().addList(BASIC_AUTH))
            .addSecurityItem(new SecurityRequirement().addList(BEARER_AUTH));
    }
}
