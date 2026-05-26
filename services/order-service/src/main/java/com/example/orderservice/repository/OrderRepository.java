package com.example.orderservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.orderservice.entity.OrderEntity;

public interface OrderRepository extends JpaRepository<OrderEntity, String> {

}
