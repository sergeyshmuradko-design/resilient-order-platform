// package com.example.orderservice.service.rabbitmq;

// import org.slf4j.Logger;
// import org.slf4j.LoggerFactory;
// import org.springframework.amqp.rabbit.annotation.RabbitListener;
// import org.springframework.stereotype.Component;

// import com.example.orderservice.configuration.RabbitMqConfig;
// import com.example.orderservice.dto.OrderCreatedMessage;

// @Component
// public class NotificationListener {
    
//     private static final Logger log = LoggerFactory.getLogger(NotificationListener.class);

//     @RabbitListener(queues = RabbitMqConfig.ORDER_CREATED_QUEUE)
//     public void handleOrderCreated(OrderCreatedMessage message) {
//         log.info("Sending notification  for created order. orderId={}, customerId={}, productId={}",
//             message.orderId(),
//             message.customerId(),
//             message.productId()
//         );
//         throw new RuntimeException("Notification provider is down");
//     }
// }
