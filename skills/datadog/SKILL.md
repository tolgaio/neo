# Datadog API Skill

## Authentication

Datadog API requires two keys passed as headers:

```bash
-H "DD-API-KEY: $DD_API_KEY"
-H "DD-APPLICATION-KEY: $DD_APPLICATION_KEY"
```

Both environment variables `DD_API_KEY` and `DD_APPLICATION_KEY` are available.

## Base URL

```
https://api.datadoghq.com/api/
```

## Common Endpoints

### Metrics

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/metrics` | List active metrics (requires `?from=<unix_timestamp>`) |
| POST | `/v1/series` | Submit metrics |
| GET | `/v1/query` | Query metric data (requires `?query=<query>&from=<ts>&to=<ts>`) |

### Monitors

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/monitor` | List all monitors |
| GET | `/v1/monitor/{id}` | Get monitor by ID |
| POST | `/v1/monitor` | Create a monitor |
| PUT | `/v1/monitor/{id}` | Update a monitor |
| DELETE | `/v1/monitor/{id}` | Delete a monitor |

### Dashboards

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/dashboard` | List all dashboards |
| GET | `/v1/dashboard/{id}` | Get dashboard by ID |
| POST | `/v1/dashboard` | Create a dashboard |
| PUT | `/v1/dashboard/{id}` | Update a dashboard |
| DELETE | `/v1/dashboard/{id}` | Delete a dashboard |

### Events

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/events` | List events (requires `?start=<ts>&end=<ts>`) |
| POST | `/v1/events` | Post an event |
| GET | `/v1/events/{id}` | Get event by ID |

### Logs

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v2/logs/events/search` | Search logs |
| POST | `/v1/input` | Send logs |

## Example Requests

### List metrics from last 24 hours

```bash
curl -s -X GET "https://api.datadoghq.com/api/v1/metrics?from=$(date -d '24 hours ago' +%s)" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -H "DD-APPLICATION-KEY: $DD_APPLICATION_KEY"
```

### List all monitors

```bash
curl -s -X GET "https://api.datadoghq.com/api/v1/monitor" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -H "DD-APPLICATION-KEY: $DD_APPLICATION_KEY"
```

### List all dashboards

```bash
curl -s -X GET "https://api.datadoghq.com/api/v1/dashboard" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -H "DD-APPLICATION-KEY: $DD_APPLICATION_KEY"
```

### Get a specific dashboard

```bash
curl -s -X GET "https://api.datadoghq.com/api/v1/dashboard/{dashboard_id}" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -H "DD-APPLICATION-KEY: $DD_APPLICATION_KEY"
```

### Query metrics

```bash
curl -s -X GET "https://api.datadoghq.com/api/v1/query?from=$(date -d '1 hour ago' +%s)&to=$(date +%s)&query=avg:system.cpu.user{*}" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -H "DD-APPLICATION-KEY: $DD_APPLICATION_KEY"
```

### Update a monitor

```bash
curl -s -X PUT "https://api.datadoghq.com/api/v1/monitor/{monitor_id}" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -H "DD-APPLICATION-KEY: $DD_APPLICATION_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "...", "name": "...", "type": "metric alert"}'
```

## Rate Limits

- Free tier: 100 requests/minute
- Pro tier: 1000 requests/minute
- Enterprise: Higher limits

Handle 429 responses with exponential backoff.

## Documentation Links

- [API Reference](https://docs.datadoghq.com/api/latest/)
- [Authentication](https://docs.datadoghq.com/api/latest/authentication/)
- [Metrics API](https://docs.datadoghq.com/api/latest/metrics/)
- [Monitors API](https://docs.datadoghq.com/api/latest/monitors/)
- [Dashboards API](https://docs.datadoghq.com/api/latest/dashboards/)
- [Events API](https://docs.datadoghq.com/api/latest/events/)
- [Logs API](https://docs.datadoghq.com/api/latest/logs/)
- [API & Application Keys](https://docs.datadoghq.com/account_management/api-app-keys/)
