package com.example.orderservice;

import org.springframework.web.bind.annotation.*;

import com.example.orderservice.entity.OrderEntity;
import com.example.orderservice.repository.OrderRepository;
import com.example.orderservice.service.OrderPersistenceService;

import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/orders")
public class OrderController {

    private final ResilientPaymentService paymentService;
    private final OrderRepository orderRepository;
    private final OrderPersistenceService orderPersistenceService;

    public OrderController(
        ResilientPaymentService paymentService,
        OrderRepository orderRepository,
        OrderPersistenceService orderPersistenceService
    ) {
        this.paymentService = paymentService;
        this.orderRepository = orderRepository;
        this.orderPersistenceService = orderPersistenceService;
    }

    @PostMapping
    public OrderResponse createOrder(@RequestBody CreateOrderRequest request) {
        String orderId = UUID.randomUUID().toString();
        double amount = request.quantity() * 100.0;

        String paymentStatus;

        PaymentResponse paymentResponse =
            paymentService.authorizePayment(orderId, amount);
        paymentStatus = paymentResponse.status();

        Instant createdAt = Instant.now();

        OrderEntity orderEntity = new OrderEntity(
            orderId,
            request.customerId(),
            request.productId(),
            request.quantity(),
            amount,
            "CREATED",
            paymentStatus,
            createdAt);

        //orderRepository.save(orderEntity);
        orderPersistenceService.saveOrderWithArtificialDelay(orderEntity);

        return new OrderResponse(
            orderId,
            request.customerId(),
            request.productId(),
            request.quantity(),
            amount,
            "CREATED",
            paymentStatus,
            createdAt
        );
    }
}