package com.example.orderservice;

public interface PaymentGateway {
    public PaymentResponse authorizePayment(String orderId, double amount);    
}
