package com.example.orderservice.configuration;

import java.util.HashMap;
import java.util.Map;

import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.boot.autoconfigure.kafka.KafkaProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.ProducerFactory;

import com.example.orderservice.avro.OrderCreatedEvent;

import io.confluent.kafka.serializers.KafkaAvroSerializer;

@Configuration
public class KafkaAvroProducerConfig {

    @Bean
    public ProducerFactory<String, OrderCreatedEvent> avroOrderCreatedProducerFactory(
        KafkaProperties kafkaProperties
    ) {
        Map<String, Object> props = new HashMap<>(kafkaProperties.buildProducerProperties());

        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class);

        return new DefaultKafkaProducerFactory<>(props);
    }

    @Bean
    public KafkaTemplate<String, OrderCreatedEvent> avroOrderCreatedKafkaTemplate(
        ProducerFactory<String, OrderCreatedEvent> avroOrderCreatedProducerFactory
    ) {
        return new KafkaTemplate<>(avroOrderCreatedProducerFactory);
    }
}
