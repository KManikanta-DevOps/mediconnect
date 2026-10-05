vpc_cidr            = "10.10.0.0/16"
node_instance_types = ["t3.medium", "t3a.medium"]
node_capacity_type  = "SPOT"
node_min            = 1
node_max            = 3
db_multi_az         = false
alert_email         = "you@example.com"
ses_sender          = "no-reply@example.com"
