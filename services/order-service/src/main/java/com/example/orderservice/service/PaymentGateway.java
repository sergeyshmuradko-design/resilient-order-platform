package com.example.orderservice.service;

import com.example.orderservice.dto.PaymentResponse;

public interface PaymentGateway {
    public PaymentResponse authorizePayment(String orderId, double amount);    
}
