package com.example.orderservice;

import java.net.http.HttpClient;
import java.time.Duration;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
@ConditionalOnProperty(
    name = "app.payment-client.type",
    havingValue = "restclient"
)
public class RestClientPaymentGateway implements PaymentGateway {

    private final RestClient restClient;

    public RestClientPaymentGateway(
        @Value("${services.payment.base-url}") String paymentBaseUrl,
        @Value("${services.payment.connect-timeout-ms:1000}") long connectTimeoutMs,
        @Value("${services.payment.read-timeout-ms:2000}") long readTimeoutMs
    ) {
        HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofMillis(connectTimeoutMs))
            .build();

        JdkClientHttpRequestFactory requestFactory =
            new JdkClientHttpRequestFactory(httpClient);
        requestFactory.setReadTimeout(Duration.ofMillis(readTimeoutMs));

        this.restClient = RestClient.builder()
            .baseUrl(paymentBaseUrl)
            .requestFactory(requestFactory)
            .build();
    }

    public PaymentResponse authorizePayment(String orderId, double amount) {
        return restClient.post()
            .uri("/payments/authorize")
            .body(new PaymentRequest(orderId, amount))
            .retrieve()
            .body(PaymentResponse.class);
    }
}
