package com.example.notificationservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.notificationservice.entity.InboxMessageEntity;

public interface InboxMessageRepository extends JpaRepository<InboxMessageEntity, String> {
}
