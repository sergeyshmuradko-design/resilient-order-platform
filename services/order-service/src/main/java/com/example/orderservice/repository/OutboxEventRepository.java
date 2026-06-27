package com.example.orderservice.repository;

import java.time.Instant;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.orderservice.entity.OutboxEventEntity;
import com.example.orderservice.entity.OutboxEventStatus;

public interface OutboxEventRepository extends JpaRepository<OutboxEventEntity, String> {

    public List<OutboxEventEntity> findTop20ByStatusAndNextRetryAtLessThanEqualOrderByCreatedAtAsc(OutboxEventStatus status, Instant now);
}
