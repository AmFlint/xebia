resource "aws_instance" "application" {
  ami = var.application_ami
  instance_type = var.application_instance_type
  count = var.application_instance_count

  key_name = var.application_key_name

  security_groups = [aws_security_group.application_security_group.name]

  tags = {
    Name      = "${var.application_stage}-application"
    component = "application"
    stage     = var.application_stage
  }
}

resource "aws_security_group" "application_security_group" {
  name        = "${var.application_stage}_application_security_group"
  description = "security group for the APIs"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// ELB

resource "aws_elb" "application_load_balancer" {
  name               = "${var.application_stage}-elb"
  availability_zones = ["eu-west-2a"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/rest/healthcheck"
    interval            = 30
  }

  instances                   = aws_instance.application.*.id
  cross_zone_load_balancing   = false
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name  = "${var.application_stage}-elb"
    stage = var.application_stage
  }
}

// REDIS

resource "aws_elasticache_cluster" "api-redis" {
  cluster_id           = "${var.application_stage}-api-redis"
  engine               = "redis"
  node_type            = var.application_redis_cache_type
  num_cache_nodes      = var.application_redis_node_count
  parameter_group_name = "default.redis3.2"
  engine_version       = var.application_redis_version
  port                 = var.application_redis_port
  security_group_ids = [aws_security_group.api-redis.id]
}

resource "aws_security_group" "api-redis" {
  name        = "${var.application_stage}_application_redis_security_group"
  description = "security group for Redis"

  // Allow Application Instances to communicate to redis service
  ingress {
    from_port = var.application_redis_port
    to_port = var.application_redis_port
    protocol = "tcp"
    security_groups = [aws_security_group.application_security_group.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
