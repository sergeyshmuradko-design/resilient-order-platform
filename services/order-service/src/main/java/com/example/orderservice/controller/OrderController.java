package com.example.orderservice.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.*;

import com.example.orderservice.dto.CreateOrderRequest;
import com.example.orderservice.dto.OrderCreatedMessage;
import com.example.orderservice.dto.OrderResponse;
import com.example.orderservice.dto.OrderSearchResponse;
import com.example.orderservice.dto.PaymentResponse;
import com.example.orderservice.entity.OrderEntity;
import com.example.orderservice.repository.OrderRepository;
import com.example.orderservice.service.OrderExportService;
import com.example.orderservice.service.OrderPersistenceService;
import com.example.orderservice.service.OrderQueryService;
import com.example.orderservice.service.ResilientPaymentService;

import java.io.PrintWriter;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;


@RestController
@RequestMapping("/orders")
public class OrderController {

    private static final Logger log =
        LoggerFactory.getLogger(OrderController.class);

    private final ResilientPaymentService paymentService;
    private final OrderRepository orderRepository;
    private final OrderPersistenceService orderPersistenceService;
    private final OrderExportService orderExportService;
    private final OrderQueryService orderQueryService;
    // private final OrderEventPublisher orderEventPublisher;

    public OrderController(
        ResilientPaymentService paymentService,
        OrderRepository orderRepository,
        OrderPersistenceService orderPersistenceService,
        OrderExportService orderExportService,
        OrderQueryService orderQueryService
    ) {
        this.paymentService = paymentService;
        this.orderRepository = orderRepository;
        this.orderPersistenceService = orderPersistenceService;
        this.orderExportService = orderExportService;
        this.orderQueryService = orderQueryService;
        // this.orderEventPublisher = orderEventPublisher;
    }

    @GetMapping("/export/stream")
    public StreamingResponseBody exportStream(@RequestParam String status) {
        log.info("Starting streaming export. status={}", status);
        return outputStream -> {
            PrintWriter writer = new PrintWriter(outputStream);
            orderExportService.writeOrdersByStatus(status, writer);
            writer.flush();
        };
    }

    @GetMapping("/export/bad")
    public List<OrderEntity> exportBad(@RequestParam String status) {
        log.info("Starting bad export. status={}", status);
        List<OrderEntity> orders = orderRepository.findByOrderStatus(status);
        log.info("Loaded {} orders into memory", orders.size());
        return orders;
    }

    @GetMapping
    public OrderSearchResponse findOrders(
        @RequestParam String customerId,
        @RequestParam String status,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size
    ) {
        log.info("Searching orders. customerId={}, status={}, page={}. size={}", customerId, status, page, size);
        int safeSize = Math.min(size, 100);
        //return orderRepository.findByCustomerIdAndOrderStatus(customerId, status, PageRequest.of(page, safeSize));
        return orderQueryService.findOrders(customerId, status, page, safeSize);
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

        OrderCreatedMessage message = new OrderCreatedMessage(
            UUID.randomUUID().toString(),
            orderId,
            request.customerId(),
            request.productId(),
            request.quantity(),
            amount,
            createdAt
        );

        orderPersistenceService.saveOrder(orderEntity, message);
        //orderPersistenceService.saveOrderWithArtificialDelay(orderEntity);
        //orderPersistenceService.saveOrderWithDelay(orderEntity, message);
        // orderEventPublisher.publishOrderCreated(
        //     new OrderCreatedMessage(
        //         UUID.randomUUID().toString(),
        //         orderId,
        //         request.customerId(),
        //         request.productId(),
        //         request.quantity(),
        //         amount,
        //         createdAt
        //     )
        // );

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