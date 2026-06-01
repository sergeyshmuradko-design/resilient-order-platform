package com.example.orderservice.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.QueryHints;
import org.springframework.data.repository.query.Param;

import com.example.orderservice.entity.OrderEntity;

import jakarta.persistence.QueryHint;

import java.util.List;
import java.util.stream.Stream;

public interface OrderRepository extends JpaRepository<OrderEntity, String> {

    List<OrderEntity> findByOrderStatus(String orderStatus);

    @QueryHints(@QueryHint(name = "org.hibernate.fetchSize", value = "100"))
    @Query("select o from OrderEntity o where o.orderStatus = :status")
    Stream<OrderEntity> streamByOrderStatus(@Param("status") String status);

    Page<OrderEntity> findByCustomerIdAndOrderStatus(String customerId, String orderStatus, Pageable pageable);

    Page<OrderEntity> findByOrderStatus(String orderStatus, Pageable pageable);
}
