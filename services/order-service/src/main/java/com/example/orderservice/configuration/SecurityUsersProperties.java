package com.example.orderservice.configuration;

import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "security")
public record SecurityUsersProperties(List<LocalUser> localUsers) {

    public SecurityUsersProperties {
        if (localUsers == null || localUsers.isEmpty()) {
            throw new IllegalArgumentException("At least one local security user must be configured");
        }
    }

    public record LocalUser(String username, String password, List<String> roles) {

        public LocalUser {
            if (username == null || username.isBlank()) {
                throw new IllegalArgumentException("Local security user username must not be blank");
            }
            if (password == null || password.isBlank()) {
                throw new IllegalArgumentException("Local security user password must not be blank");
            }
            if (roles == null || roles.isEmpty()) {
                throw new IllegalArgumentException("Local security user roles must not be empty");
            }
        }
    }
}
