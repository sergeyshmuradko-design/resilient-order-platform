package com.example.orderservice.service;

import java.time.Duration;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import com.example.orderservice.exception.RateLimitExceededException;

@Service
@ConditionalOnProperty(
    name = "app.rate-limit.type",
    havingValue = "redis",
    matchIfMissing = true
)
public class RedisRateLimiterService implements RateLimiter {

    private final StringRedisTemplate redisTemplate;

    public RedisRateLimiterService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public void checkLimit(String key, int maxRequests, Duration window) {
        Long currentCount = redisTemplate.opsForValue().increment(key);

        if (currentCount != null && currentCount == 1) {
            redisTemplate.expire(key, window);
        }

        if (currentCount != null && currentCount > maxRequests) {
            throw new RateLimitExceededException("Too many requests. Please try again later.");
        }
    }
}
