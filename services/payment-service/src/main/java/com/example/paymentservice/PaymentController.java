package com.example.paymentservice;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/payments")
public class PaymentController {

    private static final Logger log = LoggerFactory.getLogger(PaymentController.class);

    @PostMapping("/authorize")
    public PaymentResponse authorize(@RequestBody PaymentRequest request) throws InterruptedException {
        if (request.amount() > 1000) {
            Thread.sleep(3000); // slow processing
        }

        log.info("Authorizing payment. orderId={}, amount={}", request.orderId(), request.amount());

        return new PaymentResponse(
            UUID.randomUUID().toString(),
            request.orderId(),
            "AUTHORIZED",
            Instant.now()
        );
    }
}