package com.example.orderservice.service;

import java.io.PrintWriter;
import java.util.stream.Stream;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.orderservice.entity.OrderEntity;
import com.example.orderservice.repository.OrderRepository;

@Service
public class OrderExportService {
    
    private final OrderRepository orderRepository;

    public OrderExportService(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    public Stream<OrderEntity> streamOrdersByStatus(String status) {
        return orderRepository.streamByOrderStatus(status);
    }

    @Transactional(readOnly = true)
    public void writeOrdersByStatus(String status, PrintWriter writer) {
        writer.println("orderId,customerId,productId,quantity,amount,orderStatus,paymentStatus,createdAt");
        try (Stream<OrderEntity> orders = orderRepository.streamByOrderStatus(status)) {
            orders.forEach(order -> writer.printf(
                "%s,%s,%s,%d,%.2f,%s,%s,%s%n",
                order.getOrderId(),
                order.getCustomerId(),
                order.getProductId(),
                order.getQuantity(),
                order.getAmount(),
                order.getOrderStatus(),
                order.getPaymentStatus(),
                order.getCreatedAt()
            ));
        }
    }
}
