package com.example.performance;

import io.gatling.javaapi.core.Simulation;

import static io.gatling.javaapi.core.CoreDsl.*;
import static io.gatling.javaapi.http.HttpDsl.*;

/**
 * Baseline HTTP performance test for order-service.
 *
 * Purpose:
 * 1. Generate controlled traffic against a safe diagnostic endpoint.
 * 2. Validate response time and error-rate requirements.
 * 3. Correlate client-side Gatling results with server-side
 *    Prometheus and Grafana metrics.
 *
 * This simulation must run only against an environment where
 * the Spring profile "load-test" is enabled.
 */
public class OrderServiceHttpSimulation extends Simulation {

    /*
     * Environment variables are preferable to hard-coded addresses
     * and credentials because the same simulation can later run:
     *
     * - from Codespaces;
     * - from CI/CD;
     * - from a Docker container;
     * - from a Kubernetes Job.
     */
    private static final String BASE_URL =
            readEnvironment("BASE_URL", "http://localhost:8081");

    private static final String TOKEN =
            requireEnvironment("TOKEN");

    /*
     * The endpoint waits for this duration.
     * This makes expected latency predictable and lets us verify p95.
     */
    private static final int DELAY_MILLISECONDS =
            Integer.parseInt(readEnvironment("DELAY_MS", "200"));

    /*
     * Open workload target.
     *
     * With an open model, Gatling starts users at the requested rate
     * independently of how long previous requests take.
     * This is appropriate when we want to control incoming traffic.
     */
    private static final double TARGET_USERS_PER_SECOND =
            Double.parseDouble(readEnvironment("TARGET_RPS", "25"));

    private final io.gatling.javaapi.http.HttpProtocolBuilder httpProtocol =
            http
                    /*
                     * Common base URL for all requests in this simulation.
                     */
                    .baseUrl(BASE_URL)

                    /*
                     * The controller returns JSON.
                     */
                    .acceptHeader("application/json")

                    /*
                     * Every request uses the JWT supplied externally.
                     * The token is not committed to Git.
                     */
                    .authorizationHeader("Bearer " + TOKEN)

                    /*
                     * A recognizable User-Agent helps distinguish Gatling
                     * requests in access logs and traces.
                     */
                    .userAgentHeader("resilient-orders-gatling");

    private final io.gatling.javaapi.core.ScenarioBuilder scenario =
            scenario("Order service baseline HTTP load")

                    /*
                     * One virtual user performs one request in this first test.
                     * More complex business chains will be added later.
                     */
                    .exec(
                            http("GET load-test endpoint")
                                    .get("/internal/load-test/http")

                                    /*
                                     * Gatling serializes this as:
                                     * ?delayMilliseconds=200
                                     */
                                    .queryParam(
                                            "delayMilliseconds",
                                            DELAY_MILLISECONDS
                                    )

                                    /*
                                     * Functional checks are evaluated for
                                     * every response.
                                     */
                                    .check(
                                            status().is(200),
                                            jsonPath("$.status").is("OK"),
                                            jsonPath("$.delayMilliseconds")
                                                    .is(String.valueOf(
                                                            DELAY_MILLISECONDS
                                                    ))
                                    )
                    );

    {
        setUp(
                scenario.injectOpen(
                        /*
                         * Warm-up:
                         * gradually increase arrival rate from 1 user/sec
                         * to the configured target over 30 seconds.
                         *
                         * Gradual ramp-up avoids confusing JVM warm-up,
                         * connection initialization and a true sudden spike.
                         */
                        rampUsersPerSec(1)
                                .to(TARGET_USERS_PER_SECOND)
                                .during(30),

                        /*
                         * Steady-state phase:
                         * keep the target arrival rate for one minute.
                         */
                        constantUsersPerSec(TARGET_USERS_PER_SECOND)
                                .during(60)
                )
        )
                .protocols(httpProtocol)

                /*
                 * Assertions turn performance expectations into
                 * automatic pass/fail criteria.
                 *
                 * A failed assertion causes the Gatling Gradle task
                 * to fail, which will later be useful in CI/CD.
                 */
                .assertions(
                        /*
                         * Less than 1% of requests may fail.
                         */
                        global()
                                .failedRequests()
                                .percent()
                                .lt(1.0),

                        /*
                         * Gatling's default percentile3 corresponds to p95.
                         * The endpoint waits 200 ms, so 400 ms provides
                         * reasonable local-environment overhead.
                         */
                        global()
                                .responseTime()
                                .percentile3()
                                .lt(400),

                        /*
                         * No individual request should exceed two seconds
                         * in this baseline scenario.
                         */
                        global()
                                .responseTime()
                                .max()
                                .lt(2_000)
                );
    }

    private static String readEnvironment(
            String name,
            String defaultValue
    ) {
        String value = System.getenv(name);

        if (value == null || value.isBlank()) {
            return defaultValue;
        }

        return value;
    }

    private static String requireEnvironment(String name) {
        String value = System.getenv(name);

        if (value == null || value.isBlank()) {
            throw new IllegalStateException(
                    "Required environment variable is missing: " + name
            );
        }

        return value;
    }
}