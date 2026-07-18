package com.example.orderservice.service;

import java.time.Duration;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(
    name = "app.rate-limit.type",
    havingValue = "noop"
)
public class NoopRateLimiterService implements RateLimiter {
    @Override
    public void checkLimit(String key, int maxRequests, Duration window) {
    }
}
