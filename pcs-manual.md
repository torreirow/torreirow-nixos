# Deploy new cluster in preconfigured region
## LustreFS
- Change to the directory `stack/LustreFS`
- Set the backend if not already done
- Execute terraform command plan
- If terraform plan is OK, continue with:
  - Execute terraform command apply

```
cd stack/lustre_fs
terraform init --backend-config=../../infra_environments/prod/prod.tfbackend
terraform plan -var-file=../../infra_environments/prod/prod.tfvars
terraform apply -var-file=../../infra_environments/prod/prod.tfvars
```
## EFS
- Change to the directory `stack/efs`
- Set the backend if not already done
- Execute terraform command plan
- If terraform plan is OK, continue with:
  - Execute terraform command apply

```
cd stack/efs
terraform init --backend-config=../../infra_environments/prod/prod.tfbackend
terraform plan -var-file=../../infra_environments/prod/prod.tfvars
terraform apply -var-file=../../infra_environments/prod/prod.tfvars
```

## PCS
- Change to the directory `stack/efs`
- Set the backend if not already done
- Execute terraform command plan
- If terraform plan is OK, continue with:
  - Execute terraform command apply

```
cd stack/efs
terraform init --backend-config=../../infra_environments/prod/prod.tfbackend
terraform plan -var-file=../../infra_environments/prod/prod.tfvars
terraform apply -var-file=../../infra_environments/prod/prod.tfvars
```




## AWS Parallel Computing Service
In the old configuration there were **partition** is named **queues** in PCS:

PCS queues --> Slurm partitions

### Create cluster
- Click create cluster
- Fill in the details:

```
Cluster name: hpc-cluster-prod
Controller size: Small, Medium or Large, depending on the maximum number of parallel nodes.
VPC: actiflow
Subnet: private_az1 
Security groups: default actiflow
```
- Click Create

The cluster is now being deployed. This can take up to 10 minutes.
Monitor the field `status`. When deploying the status is `Creating`. When deploying has finished the status is `Active`.

### Login node 
This will be the node where you login to start jobs. It will not be part of any queues/partitions.

In the main page of the newly created cluster:
- Click `Compute node groups` tab
- Click `Create Compute node groups` button
- Fill in the details
```
Compute node group name: hpc-actiflow-prod-login
EC2 launch template: actiflow_pcs_template_prod
Version: Select the latest version
IAM instance profile: AWSPCS-profile-actiflow
Subnets: private_az1
Instance types: Select a suitable/desirable instance type, eg: c5.xlarge
Scaling configuration: Since this is a login node, this node should always be running so:
  Minimum instance count: 1
  Maximum instance count: 1
```

- Click `Create`

You will see a message `Started creating compute node group hpc-actiflow-prod-login`

The status will be `Creating`. When the group has been created the status is `Active`

The creation will fail if the instance type selected is too small for the Amazon Image that is defined in the launch-template.

- Wait for the status to be `Active`. 



### Compute Nodes
#### Create Node Groups
In the main page of the newly created cluster:
- Click `Compute node groups` tab
- Click `Create Compute node groups` button
- Fill in the details
(!) Some instance type and Subnets combinations result in a creation failure.
`Instance type is not available in the selected availability-zone` (availability-zone = Subnet). Select another Subnet (private_az_?)  or another Instance.

```
Compute node group name: hpc-actiflow-prod-<groupname>
EC2 launch template: actiflow_pcs_template_prod
Version: Select the latest version
IAM instance profile: AWSPCS-profile-actiflow
Subnets: private_az1 
Instance types: Select a suitable/desirable instance type, eg: hpc6a.48xlarge
Scaling configuration: 
  Minimum instance count: 0 
  Maximum instance count: <desired_max_amount_of_parallel_nodes> 
```

- Click `Create`

You will see a message `Started creating compute node group hpc-actiflow-prod-<groupname>`

The status will be `Creating`. When the group has been created the status is `Active`

The creation will fail if the instance type selected is too small for the Amazon Image that is defined in the launch-template.

- Wait for the status to be `Active`. 

Repeat for other node groups, with different instance types.

#### Create Queue/Partitions
These queues will be visible in Slurm as partitions

In the main page of the newly created cluster:
- Click `Queues` tab

- Click `Create queue` button
- Fill in the details

```
Queue name: <desired queue name>
Compute node groups: (!) DO NOT select the login node group
  - Select the node groups you want to use for this queue
```

- Click `Create` button

You will see a message `Started creating queue hpc-prod-<queuename>`

The status will be `Creating`. When the group has been created the status is `Active`

#### Connect to login node
- Lookup the **Login Node** in the [AWS Console EC2[(). It has the name of the cluster + login. E.g.: **hpc-actiflow-prod-login**
- Make sure you are connected via the VPN to AWS
- Connect to the *Login Node* using the private key that is defined in de configuration json-file (**template_keypair_name**)

