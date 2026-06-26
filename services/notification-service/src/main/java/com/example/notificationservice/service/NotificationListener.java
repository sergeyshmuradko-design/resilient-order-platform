package com.example.notificationservice.service;

import java.io.IOException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import com.example.notificationservice.configuration.RabbitMqConfig;
import com.example.notificationservice.dto.OrderCreatedMessage;
import com.rabbitmq.client.Channel;

@Component
public class NotificationListener {

    private static final Logger log = LoggerFactory.getLogger(NotificationListener.class);

    private final IdempotentNotificationService idempotentNotificationService;

    public NotificationListener(IdempotentNotificationService idempotentNotificationService) {
		this.idempotentNotificationService = idempotentNotificationService;
	}

	@RabbitListener(queues = RabbitMqConfig.ORDER_CREATED_QUEUE)
    public void handleOrderCreated(
        OrderCreatedMessage message,
        Message rawMessage,
        Channel channel
    ) throws IOException {
        // log.info("Trying to send notification. order={}", message.orderId());

        // throw new RuntimeException("Notification provider is down");

        long deliveryTag = rawMessage.getMessageProperties().getDeliveryTag();
        boolean processed = idempotentNotificationService.tryProcess(message);

        try {
            log.info("Processing notification. orderId={}, customerId={}, deliveryTag={}",
            message.orderId(),
            message.customerId(),
            deliveryTag
        );

        if (processed) {
            log.info("Notification sent. messageId={}, orderId={}", message.messageId(), message.orderId());
        } else {
            log.info("Duplicate message ignored. messageId={}, orderId={}", message.messageId(), message.orderId());
        }

        // if (true) {
        //     throw new RuntimeException("TEST ERROR");
        // }
        channel.basicAck(deliveryTag, false);
        } catch (Exception ex) {
            log.error("Notification processing failed. orderId={}", message.orderId(), ex);
            channel.basicNack(deliveryTag, false, false);
            // deliveryTag = id доставки сообщения
            // multiple = false → только это сообщение
            // requeue = false → не возвращать в main queue
        }
        // log.info("Sending notification  for created order. orderId={}, customerId={}, productId={}",
        //     message.orderId(),
        //     message.customerId(),
        //     message.productId()
        // );
    }
}
