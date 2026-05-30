package com.example.orderservice.service;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import com.example.orderservice.dto.PaymentRequest;
import com.example.orderservice.dto.PaymentResponse;

@Component
@ConditionalOnProperty(
    name = "app.payment-client.type",
    havingValue = "feign",
    matchIfMissing = true
)
public class FeignPaymentGateway implements PaymentGateway {

    private final PaymentClient paymentClient;

    public FeignPaymentGateway(PaymentClient paymentClient) {
        this.paymentClient = paymentClient;
    }

    @Override
    public PaymentResponse authorizePayment(String orderId, double amount) {
        return paymentClient.authorizePayment(new PaymentRequest(orderId, amount));
    }
}