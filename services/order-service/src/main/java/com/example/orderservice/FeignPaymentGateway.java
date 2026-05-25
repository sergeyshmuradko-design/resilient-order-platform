package com.example.orderservice;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

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