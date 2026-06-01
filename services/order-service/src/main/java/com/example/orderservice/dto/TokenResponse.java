package com.example.orderservice.dto;

public record TokenResponse(
    String accessToken,
    String tokenType,
    long expiresInSeconds
) {
}
