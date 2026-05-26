package com.example.orderservice;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

@Service
public class ResilientPaymentService {

    private static final Logger log = LoggerFactory.getLogger(ResilientPaymentService.class);

    private final PaymentGateway paymentGateway;

    public ResilientPaymentService(PaymentGateway paymentGateway) {
        this.paymentGateway = paymentGateway;
    }

    @Retry(name = "paymentServiceRetry")
    @CircuitBreaker(
        name = "paymentServiceCircuitBreaker",
        fallbackMethod = "fallbackAuthorizePayment"
    )
    public PaymentResponse authorizePayment(String orderId, double amount) {
        return paymentGateway.authorizePayment(orderId, amount);
    }

    public PaymentResponse fallbackAuthorizePayment(String orderId, double amount, Throwable ex) {
        log.warn("Payment authorization fallback executed. orderId={}, amount={}, reason={}", orderId, amount, ex.toString());
        return new PaymentResponse(null, orderId, "PAYMENT_PENDING", null);
    }
}
