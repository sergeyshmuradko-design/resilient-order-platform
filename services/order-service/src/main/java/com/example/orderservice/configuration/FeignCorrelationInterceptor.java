package com.example.orderservice.configuration;

import org.slf4j.MDC;
import org.springframework.stereotype.Component;

import com.example.orderservice.service.CorrelationConstants;

import feign.RequestInterceptor;
import feign.RequestTemplate;

@Component
public class FeignCorrelationInterceptor implements RequestInterceptor {

    @Override
    public void apply(RequestTemplate template) {
        String correlationId = MDC.get(CorrelationConstants.CORRELATION_ID_MDC_KEY);
        if (correlationId != null && !correlationId.isBlank()) {
            template.header(CorrelationConstants.CORRELATION_ID_HEADER, correlationId);
        }
    }
}
