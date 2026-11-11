# TrueNAS operations exporter contract

Source: `http://192.168.111.69:9766/metrics`, scraped as job `truenas-ops` every 60 seconds.

Required bounded series:
- `truenas_ops_scrape_success` (one)
- `truenas_zfs_snapshot_held_bytes{root}` (two: `tank/k8s/vixens`, `tank/data/shared`)
- `truenas_gfs_task_enabled{root,tier}` (eight: two roots × hourly/daily/weekly/monthly)
- `truenas_gfs_latest_snapshot_timestamp{root,tier}` (eight)
- `truenas_nfs_service_up`, `truenas_iscsi_service_up` (one each)

The VMRule explicitly alerts when the exporter is up while this bounded contract is incomplete.
