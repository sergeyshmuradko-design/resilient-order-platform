package com.example.orderservice.configuration;

import java.io.IOException;
import java.util.UUID;

import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.example.orderservice.service.CorrelationConstants;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class CorrelationIdFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(
        HttpServletRequest request,
        HttpServletResponse response,
        FilterChain filterChain) throws ServletException, IOException {

            String correlationId = request.getHeader(CorrelationConstants.CORRELATION_ID_HEADER);

            if (correlationId == null || correlationId.isBlank()) {
                correlationId = UUID.randomUUID().toString();
            }

            try {
                MDC.put(CorrelationConstants.CORRELATION_ID_MDC_KEY, correlationId);
                response.setHeader(CorrelationConstants.CORRELATION_ID_HEADER, correlationId);
                filterChain.doFilter(request, response);
            } finally {
                MDC.remove(CorrelationConstants.CORRELATION_ID_MDC_KEY);
            }
    }
}
