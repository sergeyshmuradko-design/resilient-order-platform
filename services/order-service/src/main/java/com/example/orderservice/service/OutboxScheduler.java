package com.example.orderservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;

@Component
@ConditionalOnProperty(
    name = "app.outbox.publisher.enabled",
    havingValue = "true",
    matchIfMissing = true
)
public class OutboxScheduler {

    private static final Logger log =
        LoggerFactory.getLogger(OutboxScheduler.class);

    private final OutboxPublisher outboxPublisher;

    public OutboxScheduler(OutboxPublisher outboxPublisher) {
        this.outboxPublisher = outboxPublisher;
    }

    @Scheduled(fixedDelayString = "${app.outbox.publisher.fixed-delay-ms:5000}")
    @SchedulerLock(
        name = "outboxPublisher",
        lockAtMostFor = "PT1M",
        lockAtLeastFor = "PT1S"
    )
    public void publishOutboxEvents() {
        log.info("Running outbox publisher scheduler");
        outboxPublisher.publishNewEvents();
    }
}
