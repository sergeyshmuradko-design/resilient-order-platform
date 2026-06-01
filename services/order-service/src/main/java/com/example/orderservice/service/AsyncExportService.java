package com.example.orderservice.service;

import java.util.concurrent.Executor;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.example.orderservice.entity.ExportJobEntity;

@Service
public class AsyncExportService {

    private static final Logger log = LoggerFactory.getLogger(AsyncExportService.class);

    private final ExportJobService exportJobService;
    private final ExportJobWorker exportJobWorker;
    private final Executor exportTaskExecutor;

    public AsyncExportService(
        ExportJobService exportJobService,
        ExportJobWorker exportJobWorker,
        Executor exportTaskExecutor
    ) {
        this.exportJobService = exportJobService;
        this.exportJobWorker = exportJobWorker;
        this.exportTaskExecutor = exportTaskExecutor;
    }

    public ExportJobEntity startExport(String orderStatus) {
        ExportJobEntity job = exportJobService.createJob(orderStatus);
        exportTaskExecutor.execute(() -> runExport(job.getJobId()));
        return job;
    }

    public ExportJobEntity getJob(String jobId) {
        return exportJobService.getJob(jobId);
    }

    private void runExport(String jobId) {
        try {
            exportJobWorker.executeExport(jobId);
        } catch (Exception e) {
            log.error("Export failed. jobId={}", jobId, e);
            exportJobService.markFailed(jobId, e.getMessage());
        }
    }
}
