# TrueNAS operations exporter contract

Source: `http://192.168.111.69:9766/metrics`, scraped as job `truenas-ops` every 60 seconds.

Required bounded series:
- `truenas_ops_scrape_success` (one)
- `truenas_zfs_snapshot_held_bytes{root}` (two: `tank/k8s/vixens`, `tank/data/shared`)
- `truenas_gfs_task_enabled{root,tier}` (eight: two roots × hourly/daily/weekly/monthly)
- `truenas_gfs_latest_snapshot_timestamp{root,tier}` (eight)
- `truenas_nfs_service_up`, `truenas_iscsi_service_up` (one each)

The VMRule explicitly alerts when the exporter is up while this bounded contract is incomplete.

## Scrutiny SMART contract

The same local exporter reads Scrutiny only through its loopback summary API. It emits bounded per-disk labels (`disk`, `protocol`) and never exposes serials or WWNs:
- `truenas_scrutiny_up` and `truenas_scrutiny_disk_count`
- `truenas_scrutiny_disk_status{disk,protocol}`
- `truenas_scrutiny_temperature_celsius{disk,protocol}`
- `truenas_scrutiny_power_on_hours{disk,protocol}`
- `truenas_scrutiny_last_collection_timestamp{disk,protocol}`

### Physical SMART slot summary

`truenas_scrutiny_slot_state{bus,slot}` publishes the fixed appliance layout: three NVMe slots and eight SATA bays. Values are `0` healthy, `1` empty, and `2` degraded. This keeps empty SATA bays visible without emitting a serial, WWN, or a synthetic disk identity.

### GFS newest-snapshot age

The dashboard intentionally filters `truenas_gfs_latest_snapshot_timestamp == 0`: a zero denotes a retention tier with no snapshot yet, not a snapshot created at the Unix epoch.
