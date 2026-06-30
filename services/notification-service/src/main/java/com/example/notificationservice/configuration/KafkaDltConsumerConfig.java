// package com.example.notificationservice.configuration;

// import java.util.HashMap;
// import java.util.Map;

// import org.apache.kafka.common.serialization.ByteArrayDeserializer;
// import org.apache.kafka.common.serialization.StringDeserializer;
// import org.springframework.boot.autoconfigure.kafka.KafkaProperties;
// import org.springframework.context.annotation.Bean;
// import org.springframework.context.annotation.Configuration;
// import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
// import org.springframework.kafka.core.ConsumerFactory;
// import org.springframework.kafka.core.DefaultKafkaConsumerFactory;

// @Configuration
// public class KafkaDltConsumerConfig {

//     @Bean
//     public ConsumerFactory<String, byte[]> dltConsumerFactory(KafkaProperties kafkaProperties) {
//         Map<String, Object> props = new HashMap<>(kafkaProperties.buildConsumerProperties());

//         props.put("key.deserializer", StringDeserializer.class);
//         props.put("value.deserializer", ByteArrayDeserializer.class);
//         props.put("group.id", "notification-dlt-monitor");

//         return new DefaultKafkaConsumerFactory<>(props);
//     }

//     @Bean
//     public ConcurrentKafkaListenerContainerFactory<String, byte[]> dltKafkaListenerContainerFactory(
//         ConsumerFactory<String, byte[]> dltConsumerFactory
//     ) {
//         ConcurrentKafkaListenerContainerFactory<String, byte[]> factory =
//             new ConcurrentKafkaListenerContainerFactory<>();

//         factory.setConsumerFactory(dltConsumerFactory);

//         return factory;
//     }
// }
