package com.example.orderservice.service;

public final class CorrelationConstants {
    public static final String CORRELATION_ID_HEADER = "X-Correlation-Id";
    public static final String CORRELATION_ID_MDC_KEY = "correlationId";

    private CorrelationConstants() {}
}
