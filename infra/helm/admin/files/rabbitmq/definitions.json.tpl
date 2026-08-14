{
  "users": [
{{- range $index, $user := .Values.rabbitmqTopology.users }}
    {{- if $index }},{{ end }}
    {
      "name": {{ printf "{{ .%s }}" $user.usernameSecretKey | quote }},
      "password": {{ printf "{{ .%s }}" $user.passwordSecretKey | quote }},
      "tags": {{ $user.tags | quote }}
    }
{{- end }}
  ],
  "vhosts": [
{{- range $index, $vhost := .Values.rabbitmqTopology.vhosts }}
    {{- if $index }},{{ end }}
    {
      "name": {{ $vhost.name | quote }}
    }
{{- end }}
  ],
  "permissions": [
{{- range $index, $permission := .Values.rabbitmqTopology.permissions }}
    {{- if $index }},{{ end }}
    {
      "user": {{ printf "{{ .%s }}" $permission.userSecretKey | quote }},
      "vhost": {{ $permission.vhost | quote }},
      "configure": {{ $permission.configure | quote }},
      "write": {{ $permission.write | quote }},
      "read": {{ $permission.read | quote }}
    }
{{- end }}
  ],
  "exchanges": [
{{- range $index, $exchange := .Values.rabbitmqTopology.exchanges }}
    {{- if $index }},{{ end }}
    {
      "name": {{ $exchange.name | quote }},
      "vhost": {{ $exchange.vhost | quote }},
      "type": {{ $exchange.type | quote }},
      "durable": {{ $exchange.durable }},
      "auto_delete": {{ $exchange.autoDelete }},
      "internal": {{ $exchange.internal }},
      "arguments": {{ $exchange.arguments | default dict | toJson }}
    }
{{- end }}
  ],
  "queues": [
{{- range $index, $queue := .Values.rabbitmqTopology.queues }}
    {{- if $index }},{{ end }}
    {
      "name": {{ $queue.name | quote }},
      "vhost": {{ $queue.vhost | quote }},
      "durable": {{ $queue.durable }},
      "auto_delete": {{ $queue.autoDelete }},
      "arguments": {{ $queue.arguments | default dict | toJson }}
    }
{{- end }}
  ],
  "bindings": [
{{- range $index, $binding := .Values.rabbitmqTopology.bindings }}
    {{- if $index }},{{ end }}
    {
      "source": {{ $binding.source | quote }},
      "vhost": {{ $binding.vhost | quote }},
      "destination": {{ $binding.destination | quote }},
      "destination_type": {{ $binding.destinationType | quote }},
      "routing_key": {{ $binding.routingKey | quote }},
      "arguments": {{ $binding.arguments | default dict | toJson }}
    }
{{- end }}
  ],
  "policies": {{ .Values.rabbitmqTopology.policies | default list | toJson }}
}
