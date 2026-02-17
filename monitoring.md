# Monitoring System Overview

This document explains how the monitoring components in this repo fit together and how they help during an outage.

## Monitoring Stack Diagram

```mermaid
flowchart LR
    Apps[Applications + Services] -->|/metrics scrape| Prometheus[Prometheus]
    Exporters[Node/K8s + Dependency Exporters] -->|metrics scrape| Prometheus
    Blackbox[Blackbox Exporter] -->|probe metrics| Prometheus
    Jobs[Batch Jobs] -->|push metrics| Pushgateway[Pushgateway]
    Pushgateway -->|metrics scrape| Prometheus

    Prometheus -->|alert rules fire| Alertmanager[Alertmanager]
    Alertmanager -->|routed notifications| OnCall[On-call / Receivers]

    Prometheus -->|query metrics| Grafana[Grafana]
    Promtail[Promtail] -->|ship logs| Loki[Loki]
    Loki -->|query logs| Grafana
```

## Components and Their Roles

1. **Prometheus (metrics collection + alert evaluation)**
   - Scrapes metrics from Services annotated with `prometheus.io/*`.
   - Collects node and Kubernetes state metrics (node-exporter, kube-state-metrics).
   - Evaluates alert rules and sends alerts to Alertmanager.
   - Config: `k8s/helm-values/monitoring/prometheus-values.yaml`

2. **Alertmanager (alert routing)**
   - Receives alerts from Prometheus.
   - Groups and routes alerts by severity, namespace, and service.
   - Config scaffold exists for routing.
   - Config: `k8s/helm-values/monitoring/prometheus-values.yaml`

3. **Grafana (dashboards + alert visibility)**
   - Shows dashboards, alert lists, and alert annotations.
   - Dashboards are provisioned as code so they are versioned.
   - Config: `k8s/helm-values/monitoring/grafana-values.yaml`

4. **Loki + Promtail (logs)**
   - Promtail collects container logs and ships them to Loki.
   - Grafana queries Loki to correlate logs with alerts/metrics.
   - Configs: `k8s/helm-values/monitoring/loki-values.yaml`, `k8s/helm-values/monitoring/promtail-values.yaml`

5. **Exporters (dependencies visibility)**
   - Postgres, Redis, RabbitMQ exporters provide dependency metrics.
   - Configs: `k8s/helm-values/monitoring/*-exporter-values.yaml`

6. **Blackbox Exporter (endpoint probes)**
   - Performs HTTP probes to validate real reachability.
   - Helps detect DNS/routing issues that internal metrics might miss.
   - Config: `k8s/helm-values/monitoring/blackbox-exporter-values.yaml`

7. **Pushgateway (short-lived jobs)**
   - Allows batch jobs (migrations, backups, timeout handlers) to push metrics.
   - Scraped by Prometheus as a static target.
   - Config: `k8s/helm-values/monitoring/prometheus-values.yaml`

## How It All Fits Together

1. **Applications + Infra emit metrics** through annotated Services or exporters.
2. **Prometheus scrapes metrics** and stores time series.
3. **Recording rules** precompute SLI/SLO metrics for consistent alerts and dashboards.
4. **Alerting rules** fire on availability, latency, stability, saturation, and infrastructure issues.
5. **Alertmanager** routes alerts to the right receiver.
6. **Grafana** displays dashboards, active alerts, and alert annotations.
7. **Loki logs** provide root-cause evidence when alerts fire.

## Downtime Scenario: API Gateway Failure

**Situation:** The API Gateway becomes unhealthy due to a bad deployment.

### Step 1: Alert Fires
- `PayflowHighErrorRateCritical` triggers because 5xx rate exceeds 5% for 5 minutes.
- `PayflowHighLatencyP95` may also fire if latency spikes.

### Step 2: Alert Visibility
- Alert is listed in Grafana under **Active Alerts (Filtered)**.
- An alert annotation appears on charts at the exact failure time.

### Step 3: Scope the Blast Radius
In Grafana:
- Filter `Service = api-gateway` to see service-specific charts.
- Check error rate and latency graphs to confirm the impact window.
- Verify whether other services are healthy.

### Step 4: Root Cause from Logs
Use Grafana Loki:
- Open the logs panel for `api-gateway`.
- Look at the time range around the alert annotation.
- Identify exceptions, timeout messages, or upstream failures.

### Step 5: Mitigation
Possible actions:
- Roll back the deployment.
- Scale replicas if capacity is the issue.
- Adjust CPU/memory limits if throttling or OOM is detected.

### Step 6: Post-Incident Validation
After the fix:
- Alerts resolve in Alertmanager and Grafana.
- Error and latency graphs return to baseline.
- Log volume and error signatures drop.

## Why This Helps During Downtime

- **Fast detection:** Alerts fire when users are affected.
- **Quick scoping:** Per-service alerts isolate the failing component.
- **Deep diagnosis:** Logs and metrics together reveal root cause.
- **Consistent signals:** Recording rules ensure dashboards and alerts agree.

