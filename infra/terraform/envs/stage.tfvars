vpc_cidr            = "10.20.0.0/16"
node_instance_types = ["t3.medium"]
node_capacity_type  = "ON_DEMAND"
node_min            = 2
node_max            = 4
db_multi_az         = false
alert_email         = "you@example.com"
ses_sender          = "no-reply@example.com"
