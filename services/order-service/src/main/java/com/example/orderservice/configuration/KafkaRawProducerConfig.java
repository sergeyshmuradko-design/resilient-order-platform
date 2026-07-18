package com.example.orderservice.configuration;

import java.util.HashMap;
import java.util.Map;

import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.autoconfigure.kafka.KafkaProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.ProducerFactory;
import org.springframework.kafka.support.serializer.JsonSerializer;

import com.example.orderservice.dto.OrderCreatedMessage;

@Configuration
@ConditionalOnProperty(
    name = "app.messaging.kafka.enabled",
    havingValue = "true",
    matchIfMissing = true
)
public class KafkaRawProducerConfig {

    @Bean
    public ProducerFactory<String, String> rawStringProducerFactory(KafkaProperties kafkaProperties) {
        Map<String, Object> props = new HashMap<>(kafkaProperties.buildProducerProperties());

        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);

        return new DefaultKafkaProducerFactory<>(props);
    }

    @Bean
    public KafkaTemplate<String, String> rawStringKafkaTemplate(ProducerFactory<String, String> rawStringProducerFactory) {
        return new KafkaTemplate<>(rawStringProducerFactory);
    }

    @Bean
    @Primary
    public ProducerFactory<String, OrderCreatedMessage> orderCreatedProducerFactory(KafkaProperties kafkaProperties) {
        Map<String, Object> props = new HashMap<>(kafkaProperties.buildProducerProperties());

        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JsonSerializer.class);
        props.put(JsonSerializer.ADD_TYPE_INFO_HEADERS, false);

        return new DefaultKafkaProducerFactory<>(props);
    }

    @Bean
    @Primary
    public KafkaTemplate<String, OrderCreatedMessage> orderCreatedKafkaTemplate(ProducerFactory<String, OrderCreatedMessage> orderCreatedProducerFactory) {
        KafkaTemplate<String, OrderCreatedMessage> template = new KafkaTemplate<>(orderCreatedProducerFactory);
        template.setObservationEnabled(true);
        return template;
    }
}
