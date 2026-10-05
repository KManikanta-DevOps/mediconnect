# Runbook: SLOFastBurn alert
1. Grafana "MediConnect SLO" -> which service has the 5xx spike?
2. `kubectl -n mediconnect get pods; kubectl -n mediconnect logs deploy/<svc> --tail=100`
3. Recent deploy? Argo CD -> History -> roll back, or revert the tag-bump commit.
4. DB suspect? Check RDS CPU/connections in CloudWatch and failover status.
5. Write a short post-mortem in docs/.
