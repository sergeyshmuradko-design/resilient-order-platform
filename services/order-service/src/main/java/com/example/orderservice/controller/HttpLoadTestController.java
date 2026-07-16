package com.example.orderservice.controller;

import org.springframework.context.annotation.Profile;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Profile("load-test")
public class HttpLoadTestController {

    /**
     * Safe endpoint for local HTTP load testing.
     *
     * It does not modify business data or call external systems.
     * The optional delay lets us observe latency percentiles.
     */
    @GetMapping("/internal/load-test/http")
    public LoadTestResponse testHttp(
            @RequestParam(defaultValue = "0") long delayMilliseconds
    ) throws InterruptedException {

        if (delayMilliseconds < 0 || delayMilliseconds > 5_000) {
            throw new IllegalArgumentException(
                    "delayMilliseconds must be between 0 and 5000"
            );
        }

        if (delayMilliseconds > 0) {
            Thread.sleep(delayMilliseconds);
        }

        return new LoadTestResponse("OK", delayMilliseconds);
    }

    public record LoadTestResponse(
            String status,
            long delayMilliseconds
    ) {
    }
}
