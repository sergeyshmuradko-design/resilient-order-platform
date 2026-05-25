package com.example.orderservice;

import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/orders")
public class OrderController {

    private final ResilientPaymentService paymentService;

    public OrderController(ResilientPaymentService paymentService) {
        this.paymentService = paymentService;
    }

    @PostMapping
    public OrderResponse createOrder(@RequestBody CreateOrderRequest request) {
        String orderId = UUID.randomUUID().toString();
        double amount = request.quantity() * 100.0;

        String paymentStatus;

        PaymentResponse paymentResponse =
            paymentService.authorizePayment(orderId, amount);
        paymentStatus = paymentResponse.status();

        return new OrderResponse(
            orderId,
            request.customerId(),
            request.productId(),
            request.quantity(),
            amount,
            "CREATED",
            paymentStatus,
            Instant.now()
        );
    }
}