package com.example.orderservice.controller;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.orderservice.dto.ExportJobResponse;
import com.example.orderservice.entity.ExportJobEntity;
import com.example.orderservice.entity.ExportJobStatus;
import com.example.orderservice.exception.ExportJobNotReadyException;
import com.example.orderservice.service.AsyncExportService;

import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;


@RestController
@RequestMapping("/exports")
public class ExportController {

    private final AsyncExportService asyncExportService;

    public ExportController(AsyncExportService asyncExportService) {
        this.asyncExportService = asyncExportService;
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping
    public ResponseEntity<ExportJobResponse> startExport(@RequestParam String orderStatus) {
        ExportJobEntity job = asyncExportService.startExport(orderStatus);
        return ResponseEntity.accepted().body(ExportJobResponse.from(job));
    }

    @PreAuthorize("hasAnyRole('ADMIN', 'USER')")
    @GetMapping("/{jobId}")
    public ResponseEntity<ExportJobResponse> getJob(@PathVariable String jobId) {
        ExportJobEntity job = asyncExportService.getJob(jobId);
        return ResponseEntity.ok().body(ExportJobResponse.from(job));
    }

    @PreAuthorize("hasAnyRole('ADMIN', 'USER')")
    @GetMapping("/{jobId}/download")
    public ResponseEntity<Resource> download(@PathVariable String jobId) {
        ExportJobEntity job = asyncExportService.getJob(jobId);

        if (job.getStatus() != ExportJobStatus.COMPLETED) {
            throw new ExportJobNotReadyException(jobId);
        }

        Resource resource = new FileSystemResource(job.getFilePath());
        return ResponseEntity.ok()
            .header("Content-Disposition", "attachment; filename=\"orders-" + jobId + ".csv\"")
            .body(resource);
    }

}
