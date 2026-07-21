-- Таблица идемпотентности: хранит уже обработанные message_id.
CREATE TABLE processed_messages (
    message_id varchar(255) NOT NULL,
    processed_at timestamp(6) with time zone,
    CONSTRAINT processed_messages_pkey PRIMARY KEY (message_id)
);

-- Inbox хранит входящие сообщения и статус их обработки notification-service.
CREATE TABLE inbox_messages (
    message_id varchar(255) NOT NULL,
    error_message text,
    payload text NOT NULL,
    processed_at timestamp(6) with time zone,
    received_at timestamp(6) with time zone,
    status varchar(255),
    CONSTRAINT inbox_messages_pkey PRIMARY KEY (message_id),
    CONSTRAINT inbox_messages_status_check
        CHECK (status IN ('RECEIVED', 'PROCESSED', 'FAILED'))
);
