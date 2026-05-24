package com.example.paymentservice;

import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/payments")
public class PaymentController {

    @PostMapping("/authorize")
    public PaymentResponse authorize(@RequestBody PaymentRequest request) throws InterruptedException {
        if (request.amount() > 1000) {
            Thread.sleep(3000); // slow processing
        }

        return new PaymentResponse(
            UUID.randomUUID().toString(),
            request.orderId(),
            "AUTHORIZED",
            Instant.now()
        );
    }
}