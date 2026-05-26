package com.example.orderservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.example.orderservice.entity.OrderEntity;
import com.example.orderservice.repository.OrderRepository;

import jakarta.transaction.Transactional;

@Service
public class OrderPersistenceService {

    private static final Logger log =
        LoggerFactory.getLogger(OrderPersistenceService.class);

    private final OrderRepository orderRepository;

    public OrderPersistenceService(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    @Transactional
    public void saveOrderWithArtificialDelay(OrderEntity orderEntity) {
        log.info("Saving order with artificial DB delay. orderId={}", orderEntity.getOrderId());
        orderRepository.save(orderEntity);

        try {
            Thread.sleep(10000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        log.info("Finished delayed DB transaction. orderId={}", orderEntity.getOrderId());
    }
}
