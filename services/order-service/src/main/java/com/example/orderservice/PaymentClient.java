package com.example.orderservice;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;

@Component
@FeignClient(
    name = "payment-service",
    url = "${services.payment.base-url}"
)
public interface PaymentClient {

    @PostMapping("/payments/authorize")
    public PaymentResponse authorizePayment(@RequestBody PaymentRequest request);
}