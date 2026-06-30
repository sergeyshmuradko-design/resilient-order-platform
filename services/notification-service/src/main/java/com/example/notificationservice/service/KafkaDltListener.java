// package com.example.notificationservice.service;

// import java.nio.charset.StandardCharsets;

// import org.apache.kafka.clients.consumer.ConsumerRecord;
// import org.apache.kafka.common.header.Header;
// import org.slf4j.Logger;
// import org.slf4j.LoggerFactory;
// import org.springframework.kafka.annotation.KafkaListener;
// import org.springframework.stereotype.Component;

// import jakarta.annotation.PostConstruct;

// @Component
// public class KafkaDltListener {

//     private static final Logger log = LoggerFactory.getLogger(KafkaDltListener.class);

//     @KafkaListener(
//         topics = "order.created.events.DLT",
//         groupId = "notification-dlt-monitor",
//         containerFactory = "dltKafkaListenerContainerFactory"
//     )
//     public void handleDltMessage(ConsumerRecord<String, byte[]> record) {
//         String payload = record.value() == null
//             ? null
//             : new String(record.value(), StandardCharsets.UTF_8);

//         log.error(
//             "Kafka DLT message received. topic={}, partition={}, offset={}, key={}, payload={}",
//             record.topic(),
//             record.partition(),
//             record.offset(),
//             record.key(),
//             payload
//         );

//         for (Header header : record.headers()) {
//             log.error(
//                 "Kafka DLT header. key={}, value={}",
//                 header.key(),
//                 header.value() == null ? null : new String(header.value(), StandardCharsets.UTF_8)
//             );
//         }
//     }

//     @PostConstruct
//     public void init() {
//         log.info("KafkaDltListener initialized");
//     }
// }
