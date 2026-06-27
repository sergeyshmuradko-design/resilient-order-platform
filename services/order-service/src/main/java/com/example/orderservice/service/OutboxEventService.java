package com.example.orderservice.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.orderservice.entity.OutboxEventStatus;
import com.example.orderservice.repository.OutboxEventRepository;

@Service
public class OutboxEventService {
    
    private final OutboxEventRepository repository;

	public OutboxEventService(OutboxEventRepository repository) {
		this.repository = repository;
	}

    @Transactional
    public void markPublished(String eventId) {
        repository.findById(eventId).ifPresent(event ->{
            if (event.getStatus() == OutboxEventStatus.PROCESSING) {
                event.markPublished();
            }
        });
    }

    @Transactional
    public void markReturned(String eventId, String reason) {
        repository.findById(eventId).ifPresent(event ->{
            if (event.getStatus() == OutboxEventStatus.PROCESSING ||
                event.getStatus() == OutboxEventStatus.PUBLISHED) {
                event.markReturned(reason);
            }
        });
    }

    @Transactional
    public void markPublishFailed(String eventId, String reason) {
        repository.findById(eventId).ifPresent(event ->{
            if (event.getStatus() == OutboxEventStatus.PROCESSING ||
                event.getStatus() == OutboxEventStatus.PUBLISHED) {
                event.markFailed(reason);
            }
        });
    }
}
