package com.example.orderservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.orderservice.entity.ExportJobEntity;

public interface ExportJobRepository extends JpaRepository<ExportJobEntity, String> {
    
}
