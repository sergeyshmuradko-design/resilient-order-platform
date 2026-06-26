package com.example.notificationservice.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.notificationservice.dto.OrderCreatedMessage;
import com.example.notificationservice.entity.ProcessedMessageEntity;
import com.example.notificationservice.repository.ProcessedMessageRepository;

@Service
public class IdempotentNotificationService {

    private final ProcessedMessageRepository processedMessageRepository;

	public IdempotentNotificationService(ProcessedMessageRepository processedMessageRepository) {
		this.processedMessageRepository = processedMessageRepository;
	}

    @Transactional
    public boolean tryProcess(OrderCreatedMessage message) {
        if (processedMessageRepository.existsById(message.messageId())) {
            return false;
        }

        processedMessageRepository.save(new ProcessedMessageEntity(message.messageId()));

        return true;
    }
}
