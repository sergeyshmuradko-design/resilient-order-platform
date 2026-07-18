package com.example.orderservice.service;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import com.example.orderservice.dto.PaymentResponse;

@Component
@ConditionalOnProperty(
    name = "app.payment-client.type",
    havingValue = "noop"
)
public class NoopPaymentGateway implements PaymentGateway {
    @Override
    public PaymentResponse authorizePayment(String orderId, double amount) {
        return new PaymentResponse(null, orderId, "PAYMENT_SKIPPED", null);
    }
}
