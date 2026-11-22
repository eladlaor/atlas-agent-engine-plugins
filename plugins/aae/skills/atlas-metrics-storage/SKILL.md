---
name: atlas-metrics-storage
description: "MongoDB Atlas cluster storage metrics, read-only through the atlas CLI: disk space used and free, IOPS, read/write latency, throughput and queue depth per node and partition, plus per-database data, storage and index size and document counts, largest first. Use when the user asks \"am I running out of disk\", \"how full is my cluster\", \"which database is biggest\", \"disk latency\", \"IOPS on my cluster\", \"how big are my indexes\". Never changes the cluster."
---

# Atlas metrics: storage

Two parts. **Disks** checks each node's partitions against the space threshold
(warn at 80% used, crit at 90%). **Databases** ranks the databases on the primary by
storage size.

## Run it

The engine is `../../scripts/atlas-metrics.sh`, resolved relative to the directory
of this `SKILL.md`. Call it `$AM` below.

```bash
$AM storage --cluster <name>                          # disks on every node + databases on the primary
$AM storage --cluster <name> --part disks --last 24h
$AM storage --cluster <name> --part databases --top 20
$AM storage --cluster <name> --part databases --database app --database analytics --format json
$AM storage --cluster <name> --threshold DISK_PARTITION_SPACE_PERCENT_USED:warn=70,crit=85
```

- `--disk-profile` and `--database-profile` choose a different profile. The built-ins
  are `disk` and `database-size`. The user can define their own (`atlas-metrics-profiles`).
- Sizes are the latest sample in the window. A longer `--last` doesn't change the size.
  It widens the IOPS and latency statistics.

## Read the result

- **Lead with the space verdict,** per node. Secondaries usually mirror the primary.
  One node that differs is worth naming.
- **Storage size and data size differ.** Data size is the documents uncompressed;
  storage size is what they take on disk after compression. Index size is separate
  from both.
- High disk latency together with high I/O wait in `atlas-metrics-snapshot --profile cpu`
  means storage is the bottleneck.

Exit codes are as in `atlas-metrics-snapshot`. Report 2–4 as failures, never as "nothing found".

## Next steps

- Which collections grew → per-collection detail lives in the Atlas Data Explorer.
  This engine stops at database level, because Atlas exposes no per-collection size
  measurement.
- Indexes that cost space without being used → `atlas-metrics-advisor --part drop-indexes`.
