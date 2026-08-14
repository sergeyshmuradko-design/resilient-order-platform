{{/*
Common labels follow the Kubernetes recommended app.kubernetes.io convention.
They make it easy to select resources by component, by concrete app name, or by
the larger platform they belong to.
*/}}
{{- define "resilient-orders.labels" -}}
app.kubernetes.io/part-of: {{ .Values.labels.partOf | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end -}}

{{- define "resilient-orders.componentLabels" -}}
app.kubernetes.io/name: {{ .name | quote }}
app.kubernetes.io/component: {{ .component | quote }}
app.kubernetes.io/part-of: {{ .root.Values.labels.partOf | quote }}
app.kubernetes.io/managed-by: {{ .root.Release.Service | quote }}
helm.sh/chart: {{ printf "%s-%s" .root.Chart.Name .root.Chart.Version | quote }}
{{- end -}}

