package com.example.orderservice.controller;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Profile("load-test")
public class DatabaseLoadTestController {

    private final JdbcTemplate jdbcTemplate;

    public DatabaseLoadTestController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping("/internal/load-test/database")
    public String holdDatabaseConnection(
            @RequestParam(defaultValue = "1000") long milliseconds
    ) {
        if (milliseconds < 0 || milliseconds > 10_000) {
            throw new IllegalArgumentException(
                    "milliseconds must be between 0 and 10000"
            );
        }

        double seconds = milliseconds / 1000.0;

        jdbcTemplate.queryForObject(
                "select pg_sleep(?)",
                Object.class,
                seconds
        );

        return "Database connection held for " + milliseconds + " ms";
    }
}
