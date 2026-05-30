package com.example.orderservice.service;

import java.time.Duration;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;

import com.example.orderservice.dto.PaymentRequest;
import com.example.orderservice.dto.PaymentResponse;

import reactor.netty.http.client.HttpClient;

@Component
@ConditionalOnProperty(
    name = "app.payment-client.type",
    havingValue = "webclient"
)
public class WebClientPaymentGateway implements PaymentGateway {

    private WebClient webClient;

    public WebClientPaymentGateway(
        @Value("${services.payment.base-url}") String paymentBaseUrl,
        @Value("${services.payment.connect-timeout-ms:1000}") long connectTimeoutMs,
        @Value("${services.payment.read-timeout-ms:2000}") long readTimeoutMs
    ) {
        HttpClient httpClient = HttpClient.create()
            .responseTimeout(Duration.ofMillis(readTimeoutMs));

        this.webClient = WebClient.builder()
            .baseUrl(paymentBaseUrl)
            .clientConnector(new ReactorClientHttpConnector(httpClient))
            .build();
    }

    @Override
    public PaymentResponse authorizePayment(String orderId, double amount) {
        return webClient.post()
            .uri("/payments/authorize")
            .bodyValue(new PaymentRequest(orderId, amount))
            .retrieve()
            .bodyToMono(PaymentResponse.class)
            .block();
    }
}
