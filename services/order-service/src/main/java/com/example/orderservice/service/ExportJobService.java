package com.example.orderservice.service;

import java.time.Instant;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.orderservice.entity.ExportJobEntity;
import com.example.orderservice.entity.ExportJobStatus;
import com.example.orderservice.exception.ExportJobNotFoundException;
import com.example.orderservice.repository.ExportJobRepository;

@Service
public class ExportJobService {

    private final ExportJobRepository exportJobRepository;

    public ExportJobService(ExportJobRepository exportJobRepository) {
        this.exportJobRepository = exportJobRepository;
    }

    @Transactional
    public ExportJobEntity createJob(String status) {
        ExportJobEntity job = new ExportJobEntity(
            UUID.randomUUID().toString(),
            status
        );
        return exportJobRepository.save(job);
    }

    @Transactional(readOnly = true)
    public ExportJobEntity getJob(String jobId) {
        return findJobOrThrow(jobId);
    }

    @Transactional
    public ExportJobEntity markRunning(String jobId) {
        ExportJobEntity job = findJobOrThrow(jobId);
        job.setStatus(ExportJobStatus.RUNNING);
        job.setStartedAt(Instant.now());
        return exportJobRepository.save(job);
    }

    @Transactional
    public ExportJobEntity markCompleted(String jobId, String filePath) {
        ExportJobEntity job = findJobOrThrow(jobId);
        job.setStatus(ExportJobStatus.COMPLETED);
        job.setFilePath(filePath);
        job.setCompletedAt(Instant.now());
        return exportJobRepository.save(job);
    }

    @Transactional
    public ExportJobEntity markFailed(String jobId, String errorMessage) {
        ExportJobEntity job = findJobOrThrow(jobId);
        job.setStatus(ExportJobStatus.FAILED);
        job.setErrorMessage(errorMessage);
        job.setCompletedAt(Instant.now());
        return exportJobRepository.save(job);
    }

    private ExportJobEntity findJobOrThrow(String jobId) {
        return exportJobRepository.findById(jobId)
            .orElseThrow(() -> new ExportJobNotFoundException(jobId));
    }
}
