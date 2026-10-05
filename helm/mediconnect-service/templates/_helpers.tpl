{{- define "svc.labels" -}}
app.kubernetes.io/name: {{ .Values.name }}
app.kubernetes.io/part-of: mediconnect
{{- end -}}
