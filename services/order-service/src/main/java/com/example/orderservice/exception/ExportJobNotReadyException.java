package com.example.orderservice.exception;

public class ExportJobNotReadyException extends RuntimeException {

    public ExportJobNotReadyException(String jobId) {
        super("Export job is not completed yet: " + jobId);
    }
}
