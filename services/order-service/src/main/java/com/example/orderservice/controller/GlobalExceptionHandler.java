package com.example.orderservice.controller;

import java.time.Instant;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.example.orderservice.dto.ErrorResponse;
import com.example.orderservice.exception.ExportJobNotFoundException;
import com.example.orderservice.exception.ExportJobNotReadyException;

import jakarta.servlet.http.HttpServletRequest;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log =
        LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ExportJobNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleExportJobNotFound(
        ExportJobNotFoundException ex,
        HttpServletRequest request
    ) {
        return buildErrorResponse(
            HttpStatus.NOT_FOUND,
            "NOT_FOUND",
            ex.getMessage(),
            request.getRequestURI()
        );
    }

    @ExceptionHandler(ExportJobNotReadyException.class)
    public ResponseEntity<ErrorResponse> handleExportJobNotReady(
        ExportJobNotReadyException ex,
        HttpServletRequest request
    ) {
        return buildErrorResponse(
            HttpStatus.CONFLICT,
            "EXPORT_JOB_NOT_READY",
            ex.getMessage(),
            request.getRequestURI()
        );
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleUnexpectedException(
        Exception ex,
        HttpServletRequest request
    ) {
        log.error("Unexpected server error. path={}", request.getRequestURI(), ex);
        return buildErrorResponse(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "INTERNAL_SERVER_ERROR",
            "Unexpected server error",
            request.getRequestURI()
        );
    }

    private ResponseEntity<ErrorResponse> buildErrorResponse(
        HttpStatus status,
        String error,
        String message,
        String path
    ) {
        return ResponseEntity
            .status(status)
            .body(new ErrorResponse(
                Instant.now(),
                status.value(),
                error,
                message,
                path
            ));
    }
}
