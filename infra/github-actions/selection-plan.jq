# Resolve user choices to one final desired state. Argo owns deletion ordering.
def require($ok; $message): if $ok then . else error($message) end;
.current.selection as $current | .choices as $choices
| require(($choices | keys) == ($current | keys); "Input keys must match selection keys")
| require(all($choices[]; . == "keep" or . == "enable" or . == "disable"); "Invalid choice")
| require(all($current[]; type == "boolean"); "Selection must contain booleans")
| ($current | with_entries(.key as $key |
    .value = (if $choices[$key] == "keep" then .value else $choices[$key] == "enable" end))) as $target
| require(($target.enable_order_service | not) or
    ($target.enable_postgres and $target.enable_redis and $target.enable_rabbitmq_stack and $target.enable_strimzi and $target.enable_payment_service);
    "order-service requires postgres, redis, rabbitmq, strimzi and payment-service in the current profile")
| require(($target.enable_notification_service | not) or
    ($target.enable_postgres and $target.enable_rabbitmq_stack and $target.enable_strimzi);
    "notification-service requires postgres, rabbitmq and strimzi")
| {before:$current, requested:$choices, target:$target, changed:($current != $target)}
