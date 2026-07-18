package com.example.orderservice.service;

import java.time.Duration;

public interface RateLimiter {
    void checkLimit(String key, int maxRequests, Duration window);
}
