package com.example.orderservice.exception;

public class ExportJobNotFoundException extends RuntimeException {

    public ExportJobNotFoundException(String jobId) {
        super("Export job not found: " + jobId);
    }
}
