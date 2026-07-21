# scanmynet_sdk example

Demonstrates configuring the SDK, running a scan, and rendering the report.

## Running

An API key is required — the report request returns 401 without one:

```bash
flutter run --dart-define=SMN_API_KEY=your-key
```

Contact ScanMyNet for credentials. Never commit a key to source control.
