package com.example.orderservice.service;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;

import com.example.orderservice.dto.PaymentRequest;
import com.example.orderservice.dto.PaymentResponse;

@Component
@FeignClient(
    name = "payment-service",
    url = "${services.payment.base-url}"
)
public interface PaymentClient {

    @PostMapping("/payments/authorize")
    public PaymentResponse authorizePayment(@RequestBody PaymentRequest request);
}