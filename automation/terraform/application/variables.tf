variable "application_instance_type" {
  type = string
  default = "t2.micro"
  description = "Instance type to use for API instances"
}

variable "application_instance_count" {
  type = number
  default = 1
  description = "Number of instances to create for the API"
}

variable "application_ami" {
  type = string
  description = "Image to use for API instances (e.g. Ubuntu, Debian)"
}

variable "application_key_name" {
  type = string
  description = "AWS Key name (SSH) to use for the API instances"
}

variable "application_stage" {
  type = string
  description = "Stage in which the infrastructure is deployed (e.g. staging, production)"
  default = "staging"
}

// REDIS

variable "application_redis_cache_type" {
  type = string
  default = "cache.t2.micro"
  description = "Cache type (machines) to use for Redis back-end"
}

variable "application_redis_node_count" {
  type = string
  default = 1
  description = "Number of nodes to use for Redis instance"
}

variable "application_redis_port" {
  type = number
  default = 6379
  description = "Port on which Redis Server should listen"
}

variable "application_redis_version" {
  type = string
  default = "3.2.10"
  description = "Version of Redis"
}