package com.example.orderservice.service;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import com.example.orderservice.dto.OrderSearchResponse;
import com.example.orderservice.dto.OrderSummaryResponse;
import com.example.orderservice.dto.PageResponse;
import com.example.orderservice.entity.OrderEntity;
import com.example.orderservice.repository.OrderRepository;

@Service
public class OrderQueryService {

    private static final Logger log = LoggerFactory.getLogger(OrderQueryService.class);

    private final OrderRepository orderRepository;

    public OrderQueryService(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    @Cacheable(
        value = "ordersByCustomerStatus",
        key = "#customerId + ':' + #status + ':' + #page + ':' + #size"
    )
    public OrderSearchResponse findOrders(String customerId, String status, int page, int size) {
        log.info("CACHE MISS: loading orders from database. customerId={}, status={}, page={}, size={}",
            customerId, status, page, size);

        Page<OrderEntity> result =
            orderRepository.findByCustomerIdAndOrderStatus(customerId, status, PageRequest.of(page, size));

        return new OrderSearchResponse(
            convertToDto(result.getContent()),
            result.getNumber(),
            result.getSize(),
            result.getTotalElements(),
            result.getTotalPages(),
            result.isFirst(),
            result.isLast()
        );
    }

    private List<OrderSummaryResponse> convertToDto(List<OrderEntity> entities) {
        return entities.stream().map(OrderSummaryResponse::from).toList();
    }
}
