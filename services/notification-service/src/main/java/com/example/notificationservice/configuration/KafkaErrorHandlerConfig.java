package com.example.notificationservice.configuration;

import org.apache.kafka.common.TopicPartition;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.KafkaOperations;
import org.springframework.kafka.listener.DeadLetterPublishingRecoverer;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.util.backoff.FixedBackOff;

@Configuration
public class KafkaErrorHandlerConfig {

    @Bean
    public DefaultErrorHandler kafkaErrorHandler(
        KafkaOperations<Object, Object> kafkaOperations
    ) {
        DeadLetterPublishingRecoverer recoverer =
            new DeadLetterPublishingRecoverer(
                kafkaOperations,
                (record, exception) -> new TopicPartition(
                    record.topic() + ".DLT",
                    record.partition()
                )
            );

        return new DefaultErrorHandler(
            recoverer, // если всё равно ошибка → отправить message в topic order.created.events.DLT
            new FixedBackOff(1000L, 2L) // 2 retry attempts с паузой 1 секунда
        );
    }
}
