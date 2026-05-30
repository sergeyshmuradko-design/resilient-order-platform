package com.example.orderservice.service;

import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;

import com.example.orderservice.entity.ExportJobEntity;
import com.example.orderservice.entity.OrderEntity;
import com.example.orderservice.repository.OrderRepository;

import io.github.resilience4j.bulkhead.annotation.Bulkhead;

@Component
public class ExportJobWorker {

    private final OrderRepository orderRepository;
    private final ExportJobService exportJobService;
    private static final Logger log = LoggerFactory.getLogger(ExportJobWorker.class);
    private static final int PAGE_SIZE = 100;

    public ExportJobWorker(
            ExportJobService exportJobService,
            OrderRepository orderRepository
    ) {
        this.exportJobService = exportJobService;
        this.orderRepository = orderRepository;
    }

    @Bulkhead(name = "exportJobBulkhead", fallbackMethod = "exportBulkheadFallback")
    public void executeExport(String jobId) throws IOException {
        ExportJobEntity job = exportJobService.markRunning(jobId);
        Path exportDir = Path.of("exports");
        Files.createDirectories(exportDir);
        Path exportPath = exportDir.resolve("orders-" + jobId + ".csv");
        try (BufferedWriter writer = Files.newBufferedWriter(exportPath)) {
            writer.write("orderId,customerId,productId,quantity,amount,orderStatus,paymentStatus,createdAt");
            writer.newLine();

            int pageNumber = 0;
            Page<OrderEntity> page;

            do {
                page = orderRepository.findByOrderStatus(job.getStatusFilter(), PageRequest.of(pageNumber, PAGE_SIZE));

                for (OrderEntity order : page.getContent()) {
                    writer.write(toCsvLine(order));
                    writer.newLine();
                }

                writer.flush();
                pageNumber++;
            } while (page.hasNext());
        }

        exportJobService.markCompleted(jobId, exportPath.toString());
        log.info("Export completed. jobId={}, filePath={}", jobId, exportPath);
    }

    private String toCsvLine(OrderEntity order) {
        return "%s,%s,%s,%d,%.2f,%s,%s,%s".formatted(
                order.getOrderId(),
                order.getCustomerId(),
                order.getProductId(),
                order.getQuantity(),
                order.getAmount(),
                order.getOrderStatus(),
                order.getPaymentStatus(),
                order.getCreatedAt());
    }

    public void exportBulkheadFallback(String jobId, Throwable ex) {
        exportJobService.markFailed(jobId, "Too many export jobs are running. Please try again later.");
    }
}
