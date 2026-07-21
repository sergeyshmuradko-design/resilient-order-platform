-- Основная таблица заказов order-service.
CREATE TABLE orders (
    order_id varchar(255) NOT NULL,
    amount double precision NOT NULL,
    created_at timestamp(6) with time zone,
    customer_id varchar(255),
    order_status varchar(255),
    payment_status varchar(255),
    product_id varchar(255),
    quantity integer NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT orders_pkey PRIMARY KEY (order_id)
);

CREATE INDEX idx_orders_customer_status
    ON orders (customer_id, order_status);

-- Outbox хранит события, которые должны быть надёжно опубликованы во внешние брокеры.
CREATE TABLE outbox_events (
    event_id varchar(255) NOT NULL,
    aggregate_id varchar(255),
    aggregate_type varchar(255),
    created_at timestamp(6) with time zone,
    event_type varchar(255),
    last_error text,
    next_retry_at timestamp(6) with time zone,
    payload text,
    published_at timestamp(6) with time zone,
    retry_count integer NOT NULL,
    status varchar(255),
    CONSTRAINT outbox_events_pkey PRIMARY KEY (event_id),
    CONSTRAINT outbox_events_status_check
        CHECK (status IN ('NEW', 'PROCESSING', 'PUBLISHED', 'RETURNED', 'FAILED'))
);

-- Асинхронные задания на экспорт заказов.
CREATE TABLE export_jobs (
    job_id varchar(255) NOT NULL,
    completed_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone,
    error_message varchar(255),
    file_path varchar(255),
    started_at timestamp(6) with time zone,
    status varchar(255),
    status_filter varchar(255),
    CONSTRAINT export_jobs_pkey PRIMARY KEY (job_id),
    CONSTRAINT export_jobs_status_check
        CHECK (status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED'))
);

-- ShedLock координирует scheduled jobs, чтобы несколько инстансов не выполняли одну задачу одновременно.
CREATE TABLE shedlock (
    name varchar(64) NOT NULL,
    lock_until timestamp(3) NOT NULL,
    locked_at timestamp(3) NOT NULL,
    locked_by varchar(255) NOT NULL,
    CONSTRAINT shedlock_pkey PRIMARY KEY (name)
);
