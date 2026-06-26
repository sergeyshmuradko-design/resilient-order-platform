package com.example.notificationservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.notificationservice.entity.ProcessedMessageEntity;

public interface ProcessedMessageRepository extends JpaRepository<ProcessedMessageEntity, String> {
}
