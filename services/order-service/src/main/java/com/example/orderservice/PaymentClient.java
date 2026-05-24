package com.example.orderservice;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
public class PaymentClient {

    private final RestClient restClient;

    public PaymentClient(@Value("${services.payment.base-url}") String paymentBaseUrl) {
        this.restClient = RestClient.builder()
            .baseUrl(paymentBaseUrl)
            .build();
    }

    public PaymentResponse authorizePayment(String orderId, double amount) {
        return restClient.post()
            .uri("/payments/authorize")
            .body(new PaymentRequest(orderId, amount))
            .retrieve()
            .body(PaymentResponse.class);
    }
}