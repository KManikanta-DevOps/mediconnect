# Runbook: restore RDS from backup (run quarterly, record the result)

**Targets:** RPO 5 min (PITR), RTO 60 min.

1. Pick restore time: `aws rds describe-db-instances --db-instance-identifier mediconnect-prod`
2. Restore to a new instance:
   ```bash
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier mediconnect-prod \
     --target-db-instance-identifier mediconnect-restore-test \
     --restore-time 2026-01-01T10:00:00Z --db-subnet-group-name mediconnect-prod
   ```
3. Wait for `available`, connect from a pod, run `SELECT count(*) FROM appointments;` and compare with expectation.
4. Point the `appointment-db` / `records-db` secrets at the new endpoint (or promote), restart deployments.
5. Delete the test instance. Write the measured RTO below.

| Date | Measured RTO | Notes |
|---|---|---|
| _fill in after drill_ | | |
