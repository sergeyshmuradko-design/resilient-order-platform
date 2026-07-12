package com.example.orderservice.controller;

import org.springframework.context.annotation.Profile;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;

@RestController
@Profile("load-test")
public class MemoryLoadTestController {

    @GetMapping("/internal/load-test/memory")
    public String createTemporaryMemoryPressure(
            @RequestParam(defaultValue = "100") int megabytes,
            @RequestParam(defaultValue = "3000") long holdMilliseconds
    ) throws InterruptedException {

        if (megabytes < 1 || megabytes > 300) {
            throw new IllegalArgumentException(
                    "megabytes must be between 1 and 300"
            );
        }

        if (holdMilliseconds < 0 || holdMilliseconds > 30_000) {
            throw new IllegalArgumentException(
                    "holdMilliseconds must be between 0 and 30000"
            );
        }

        List<byte[]> allocations = new ArrayList<>();

        for (int i = 0; i < megabytes; i++) {
            allocations.add(new byte[1024 * 1024]);
        }

        Thread.sleep(holdMilliseconds);

        return "Allocated approximately %d MB for %d ms"
                .formatted(megabytes, holdMilliseconds);
    }
}
