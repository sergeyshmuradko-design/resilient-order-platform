package com.example.orderservice.dto;

import java.util.List;

public record OrderSearchResponse(
    List<OrderSummaryResponse> content,
    int page,
    int size,
    long totalElements,
    int totalPages,
    boolean first,
    boolean last
) {
}
