package com.example.orderservice;

import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/orders")
public class OrderController {

    private final PaymentClient paymentClient;

    public OrderController(PaymentClient paymentClient) {
        this.paymentClient = paymentClient;
    }

    @PostMapping
    public OrderResponse createOrder(@RequestBody CreateOrderRequest request) {
        String orderId = UUID.randomUUID().toString();
        double amount = request.quantity() * 100.0;

        PaymentResponse paymentResponse =
            paymentClient.authorizePayment(orderId, amount);

        return new OrderResponse(
            orderId,
            request.customerId(),
            request.productId(),
            request.quantity(),
            amount,
            "CREATED",
            paymentResponse.status(),
            Instant.now()
        );
    }
}