# Click Count - Antoine Masselot

## The Application

This application, written in Java with JDK8 connects to a Redis backend to store a counter of clicks.

To make it easier to deploy this application to multiple environments (more flexible), I changed the [Configuration.java](./src//main/java/fr/xebia/clickcount/Configuration.java) to use environment variables.

This allows us to build the application inside a Docker image, and configure it via environment variables.

## Docker

This application is packaged with Docker, via [this Dockerfile](./Dockerfile), and runs on top of docker-compose.

As this application is developed in Java, we will need to break the Dockerfile in two steps:
- `Build`: We will be using a `maven` image (based on openjdk version 8) to build the application
- `Run`: We will be using a `tomcat` image (with openjdk version 8) to run the built application

This allows us to build the smallest docker image possible, with only the necessary tools to run the application, as the build is done in a previous stage during the Docker build.

I pushed the image on my DockerHub account: `amasselot/xebia`, new Updates of the images are pushed automatically based on the Git commit SHA.

## Terraform - Provision the infrastructure

This application is deployed on Amazon Web Services with Terraform.

Our application is composed of the following stack:
- Back-End Instances running our application (with Tomcat inside a Docker container)
- A Security Group for Back-end instances allowing ingress: port 22 (SSH) and 80 (HTTP) to everyone. In the futur, we will restrain the CIDR_BLOCK allowed to access SSH.
- an Elastic Load Balancer, balancing the incoming traffic to the backend instances
- An ElastiCache Redis Cluster, to store our application's data
- A Security Group for the ElastiCache Cluster, to only allow ingress on port 6379 (redis) to Back-end instances.

In order to make it easy to reuse the same terraform code to deploy our stack in multiple stages, I wrote a [Terraform module](./automatoin/terraform/application) in charge of deploying the whole stack based on given variables (number of instances for the back-end service, machines types, cache types for redis, stage in which we want to deploy).

This way, I could use the same module 2 times for staging and production platforms, each stage with custom configuration (see [the terraform entrypoint](./automation/terraform/main.tf).

To deploy the infrastructure, you need to go through multiple steps:
- Create an AWS Account
- Create an IAM User with the following policies:
  - EC2FullAccess
  - ElastiCacheFullAccess 
  - Obviously, we could restrain these permissions, but I'm aiming for simplicity as this is a technical test
- Retrieve Access key ID and Secret access key for your AWS User
- Create a SSH key Pair (used to manage your EC2 Instances on which your application will run)
  ```bash
  ssh-keygen -t rsa
  ```
- Run Terraform scripts:
  ```bash
  export AWS_ACCESS_KEY_ID=<your-aws-access-key-id>
  export AWS_SECRET_ACCESS_KEY=<your-aws-secret-key>
  
  cd automation/terraform
  terraform init
  terraform apply -var ssh_public_key_file=<path-to-your-public-key-file>
  ```

## Ansible - Provision the application

Now that we have provisioned our infrastructure on AWS, we want to provision the software and the application on our instances. For that, we're using Ansible and Ansible Playbook.

As we're running our Application inside Docker containers, we will need to install Docker on our instances. We are using `geerlingguy's ansible-role-docker` from Ansible-Galaxy for that purpose.

Also, I developed 2 roles for:
- `common`: installs common packages and librairies on instances (e.g. `docker` and `docker-compose` pip dependencies), common to all instances in the system
- `application`: Installs and configures the application project with docker-compose (login to private registry if provided, pull image, run the docker-compose project with `jinja templates`, use configuration from variables).

We're using two different playbooks, [staging.yml](./automation/ansible/staging.yml) and [production.yml](./automation/ansible/production.yml), which runs the same roles, but on different hosts (thanks to AWS instances tags and AWS dynamic inventory for Ansible).

To make it easy to scale our infrastructure, we're using `AWS Dynamic Inventories for Ansible`, which automatically generates the hosts inventory by querying AWS EC2's APIs, so make sure you have credentials for an AWS User with EC2 Reading permissions (you may use the IAM credentials generated previously and used for Terraform).

To run this playbook:
- Install PIP dependencies (BOTO, necessary to query AWS EC2 APIs):
  ```bash
  pip install -r automation/ansible/requirements.txt
  ```
- Install Ansible-galaxy dependencies (Docker role):
  ```bash
  ansible-galaxy install -r automation/ansible/roles/requirements.yml --roles-path automation/ansible/.imported-roles
  ```
- Make sure your AWS credentials are exported:
  ```bash
  export AWS_ACCESS_KEY_ID=<your-access-key>
  export AWS_SECRET_ACCESS_KEY=<secret-key>
  ```
- Get your ElastiCache endpoints, you'll need it to run the `application` role and configure your container with the right back-end, either via `terraform state show` or via `AWS Console`, I did not use Ansible-Vault to store secrets for the sake of simplicity (ElastiCache clusters are protected by security groups, only allowing connections from Application EC2 instances, using a vault would be a plus but not necessary for this test). Add these endpoints to [staging](./automation/ansible/inventory/group_vars/tag_stage_staging.yml) or [production](./automation/ansible/inventory/group_vars/tag_stage_production.yml) group_vars inventory files, or via ansible-playbook flag `-e`.
- Set up authentication to Docker registry, and image endpoint+tag if needed, you can use variables for that, take a look at the [defaults variables](./automation/ansible/roles/application/defaults/main.yml) for the application role.
- Make sure your SSH Key is loaded in your agent (or just use the `--key` flag in next step):
  ```bash
  ssh-add <path-to-my-key>
  ```
- Run the playbook: --become is needed for the first run, as we need to install packages like Docker, which require privileges
  ```bash
  export ANSIBLE_CFG=./ansible.cfg

  cd automation/ansible
  # For staging
  ansible-playbook -i inventory/ec2.py staging.yml --user ubuntu --become

  # For Production
  ansible-playbook -i inventory/ec2.py production.yml --user ubuntu --become
  ```

If you want to re-deploy a new version of the application, you can run the following command:
```bash
ansible-playbook -i inventory/ec2.py staging.yml --limit tag_component_application --tags application_deploy --user ubuntu -e application_docker_image=your-image -e application_docker_tag=your-tag
```

These Playbooks are used in CI/CD pipelines, to automatically re-deploy latest version of the application.

## CI/CD: How the application is automatically deployed on our different stages

The Continuous Deployment of this application is managed with GitHub Actions, inside two actions:
- [Deployment to staging](./.github/workflows/deploy-staging.yml): On a push to the master branch
- [Deployment to production](./.github/workflows/deploy-production.yml): When a new release is published, this allows us trigger the deployment to production platform manually 

Both of these actions are quite similar, running the following steps:
- Build Docker image (Dockerfile is split in multiple stages, which makes it easy to build the application and handle the built .war file with tomcat in the final stage)
- Push Docker image to Docker registry
- Install Ansible, PIP Dependencies required to run the playbooks, and Ansible-Galaxy roles
- Import SSH Key to ssh-agent, and run playbook (either staging playbook targeting staging hosts, or production playbook targeting production hosts)

For the sake of simplicity in this test, I did not add a `serial` strategy to ansible playbooks (used to roll updates within batches to avoid downtime) but this would be a great addition.
