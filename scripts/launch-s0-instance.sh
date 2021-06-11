#!/bin/bash

_readlink() {
    # Emulate GNU readlink's -f option on systems that do not have GNU toolchain (Mac)
    [[ -z "$1" ]] && echo "_readlink: missing argument" >&2
    CWD=$(pwd)
    cd -P $1
    pwd
    cd $CWD
}

# Disable sending aws cli 2 output to less or more
export AWS_PAGER=""

me=$(basename $0)
dir=$(_readlink $(dirname $0))
elastio_aws_id=537513441174
default_security_group="elastio-s0-server"
default_instance_type="m5d.2xlarge"
default_instance_name="$(whoami)-s0-server"
default_block_size=fixed
bootstrap=/tmp/s0-bootstrap.yml
trust_policy=/tmp/s0-role-trust-policy.json
role=/tmp/s0-role-policy.json
role_name="s0-role"
policy_name="s0-permissions"
db_mount=/mnt/elastio
unit_file=/etc/systemd/user/s0.service
service=s0

# The default SpotInstanceType is 'one-time' with the InstanceInterruptionBehavior 'terminate'.
# See thread https://github.com/elastio/elastio-stack/pull/33#discussion_r649148466 for details.
instance_market_options="--instance-market-options MarketType=spot"

create_s0_bootstrap()
{
    rm -f $bootstrap
    cat << EOF > $bootstrap
#cloud-config
# Bootstrap a 's0' server on Amazon Linux 2.
# This script is intended to run as part of the cloud init

write_files:
  - path: /home/ec2-user/.aws/config
    owner: ec2-user:ec2-user
    content: |
      [default]
      output = json

  - path: $UNIT_FILE
    owner: ec2-user:ec2-user
    permissions: '0664'
    content: |
      [Unit]
      Description="Elastio Scale-to-Zero service"
      After=network.target

      [Service]
      User=ec2-user
      StartLimitInterval=5
      StartLimitBurst=10
      TimeoutStopSec=5min
      ExecStart=/bin/bash -c '/usr/bin/s0 vault serve s3 --bucket $S0_BUCKET --key-id $S0_KMS $BLOCK_SIZE --server-address 0.0.0.0 --db-path $DB_MOUNT 2>&1 | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" >> /var/log/s0-service.log'
      Restart=always
      RestartSec=5

      [Install]
      WantedBy=multi-user.target

runcmd:
  # Format and mount nvme disk
  - |
    mkdir -p $DB_MOUNT
    if [[ -b /dev/nvme1n1 && -b /dev/nvme2n1 ]]; then
      # Two disks; make an array
      mdadm --create --verbose /dev/md0 --level=0 --raid-devices=2 /dev/nvme1n1 /dev/nvme2n1
      mkfs.xfs -f /dev/md0
      mount /dev/md0 $DB_MOUNT
    elif [ -b /dev/nvme1n1 ]; then
      # One disk; no need to involve mdadm
      parted -a optimal --script /dev/nvme1n1 mklabel gpt
      parted -a optimal --script /dev/nvme1n1 mkpart primary 0% 100%
      mkfs.xfs -f /dev/nvme1n1p1
      mount /dev/nvme1n1p1 $DB_MOUNT
    fi
    chown -R ec2-user:ec2-user $DB_MOUNT

  # Configure AWS region
  - |
    echo "region = \$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep -w region | cut -d: -f2 | tr -d '", ')" >> /home/ec2-user/.aws/config
    cp -r /home/ec2-user/.aws /root/

  # Create s0 vault
  - |
    if ! aws s3 ls s3://$S0_BUCKET/vault.json | grep -wsq "vault\.json" ; then
      echo "The '$S0_BUCKET' bucket doesnt contain a s0 vault yet. Creating one..."
      s0 vault create s3 --bucket $S0_BUCKET --key-id $S0_KMS 2>&1 | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" > /var/log/s0-vault-create.log
    else
      echo "The vault in the '$S0_BUCKET' bucket already exists."
    fi

  # Prepare and start s0 service
  - |
    touch /var/log/s0-service.log
    chown ec2-user:ec2-user /var/log/s0-service.log
    systemctl daemon-reload
    systemctl enable $UNIT_FILE
    systemctl start $SERVICE

output:
  all: '| tee -a /var/log/cloud-init-output.log'

EOF
}


create_instance_profile()
{
    local bucket=$1
    local key_arn=$2
    local profile_name=$3

    rm -f $trust_policy
    cat << EOF > $trust_policy
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    rm -f $role
    cat << EOF > $role
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "kms:*",
            "Resource": "$key_arn"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::$bucket"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::$bucket/*"
        }
    ]
}
EOF

    set -eu
    r_name="${profile_name}-${role_name}"
    p_name="${profile_name}-${policy_name}"
    echo "Creating IAM role \"$r_name\""
    aws iam create-role --role-name $r_name --assume-role-policy-document file://$trust_policy

    echo "Attaching policy \"$p_name\" to the IAM role \"$r_name\""
    aws iam put-role-policy --role-name $r_name --policy-name $p_name --policy-document file://$role
    echo "The IAM role \"$r_name\" has these permissions:"
    cat $role
    echo

    echo "Creating IAM instance profile \"$profile_name\""
    aws iam create-instance-profile --instance-profile-name $profile_name

    echo "Adding role \"$r_name\" to the instance profile \"$profile_name\""
    aws iam add-role-to-instance-profile --instance-profile-name $profile_name --role-name $r_name

    rm -r $trust_policy $role

    # Sleep a bit to avoid an error (InvalidParameterValue: Invalid IAM Instance Profile name) when calling the RunInstances operation.
    sleep 10
}

usage()
{
    echo "Usage examples:"
    echo "   $me --ssh-key-name my_ec2_key --instance-name my_s0_server --instance-type m5d.2xlarge --kms-key-alias my_kms_key --bucket-name my_s3_bucket --instance-profile my_profile"
    echo "   $me -s my_ec2_key -n my_s0_server -t m5ad.2xlarge -k my_kms_key -b my_s3_bucket -p my_profile"
    echo
    echo "  -s | --ssh-key-name       : A name of an aws EC2 key in the PEM format for the SSH connection to the instance."
    echo
    echo "  -n | --instance-name      : Optional. Name of an instance. It's shown in the AWS console."
    echo "                              The default value is \"[user_name]-s0-server\"."
    echo
    echo "  -t | --instance-type      : Optional. An instance type. See https://aws.amazon.com/ec2/instance-types/ for more details."
    echo "                              The default value is \"m5d.2xlarge\"."
    echo
    echo "  -g | --security-group     : Optional. A name of the security group which has ports 22 and 61234 open to the world for SSH and s0 server respectively."
    echo "                              The group 'elastio-s0-server' will be created and then used in case if this OR next argument is not specified."
    echo "                              NOTE: The group existance and the open ports in the group aren't checked."
    echo "                                    The script may not have permissions and assumes that the group is configured properly."
    echo
    echo "  -u | --subnet-id          : Optional. A subnet ID to use instead of the default subnet associated with the default VPC."
    echo "                              Mandatory if you don't have a default VPC. Use the subnet ID associated with the non-default VPC, which you would like to use in this case."
    echo
    echo "  -b | --bucket-name        : s3 bucket name for s0 vault."
    echo
    echo "  -k | --kms-key-alias      : KMS key alias for the data encription in the s0 vault. Also accepts a key ID in UUID format."
    echo
    echo "  -p | --instance-profile   : A name of the existing instance provile with access to the s3 bucket and KMS key from 2 parameters above."
    echo "                              See AWS docs for more details how to create one:"
    echo "                              https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html"
    echo "                              https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html"
    echo "                              Or use a parameter '--create-profile' to create it."
    echo
    echo "  -c | --create-profile     : Optional. An instance provile name to create. This parameter will have full access to the s3 bucket and KMS key from 3 parameters above."
    echo "                              This parameter is used instead of the '--instance-profile' parameter in case if you'd like to create it."
    echo
    echo "  -z | --shard              : Optional. Which of the vault's shards to serve. There are 2 possible values: \"fixed\" and \"variable\". The \"fixed\" is default."
    echo "                              - The \"fixed\" selects the shard using fixed-block deduplication."
    echo "                                This shard is intended for use with backups of block storage systems like EBS, local disks, and VMs."
    echo "                              - The \"variable\" selects the shard using variable (i.e. content-defined) deduplication."
    echo "                                This shard is intended for use with backups of file systems, streams, and any other data that isn't organized"
    echo "                                into fixed size blocks."
    echo
    echo "       --on-demand          : Optional. Create an on-demand instance instead of the default spot instance."
    echo
    echo "  -h | --help               : Show this usage help."
}

[ "$1" == "" ] && echo "Script need some arguments!" && usage && exit -1

while [ "$1" != "" ]; do
    case $1 in
        -s | --ssh-key-name)        shift && ssh_key_name=$1 ;;
        -n | --instance-name)       shift && instance_name=$1 ;;
        -t | --instance-type)       shift && instance_type=$1 ;;
        -u | --subnet-id)           shift && subnet_id=$1 ;;
        -g | --security-group)      shift && security_group=$1 ;;
        -b | --bucket-name)         shift && bucket_name=$1 ;;
        -k | --kms-key-alias)       shift && kms_key_alias="${1#alias/}" ;;
        -p | --instance-profile)    shift && instance_profile=$1 ;;
        -c | --create-profile)      shift && new_instance_profile=$1 ;;
        -z | --shard)               shift && block_size=$1 ;;
             --on-demand)           instance_market_options="" ;;
        -h | --help)                usage && exit ;;
        *)                          echo "Wrong arguments!"
                                    usage && exit 15 ;;
    esac
        shift
done

if ! which aws >/dev/null 2>&1 || [[ $(aws --version | cut -d' ' -f1 | cut -d'/' -f2 | cut -d'.' -f1) < "2" ]]; then
    echo "Please install AWS CLI v2 and try again."
    echo "You can use a package manager i.e. dnf/yum or apt or follow these instructions https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html."
    exit 1
fi

set -e -o pipefail

if [ -z "${ssh_key_name-}" ]; then
    echo "Please specify the '--ssh-key-name' parameter. Otherwise, you won't be able to connect to the running instance via ssh!"
    echo
    usage
    exit 2
fi

if [ -z "${kms_key_alias-}" ] || [ -z "${bucket_name-}" ] || ([ -z "${instance_profile-}" ] && [ -z "${new_instance_profile-}" ]); then
    echo "The '--instance-profile' (or '--create-profile'), '--bucket-name', '--kms-key-alias' are required parameters. Please specify them."
    echo
    usage
    exit 3
fi

if [ ! -z "${instance_profile-}" ] && [ ! -z "${new_instance_profile-}" ]; then
    echo "Both '--instance-profile' and '--create-profile' are specified. Please leave just one."
    echo "Use '--instance-profile' if you already have it or use '--create-profile' to create it."
    echo
    usage
    exit 3
fi

[ -z "${instance_name-}" ] && instance_name=$default_instance_name
[ -z "${instance_type-}" ] && instance_type=$default_instance_type
[ -z "${block_size-}" ]    && block_size=$default_block_size

case $block_size in
  fixed)    ;;
  variable) ;;
  *) echo "The value of the \"--s0-block-size\" should be equal to the \"fixed\" or \"variable\". Current value is \"$block_size\" and it's unexpected."
     echo
     usage
     exit 4
  ;;
esac

[ -z "${AWS_DEFAULT_REGION-}" ] &&
    current_region=$(aws configure list | grep region | awk '{print $2}') ||
    current_region=$AWS_DEFAULT_REGION

if [ -z "${current_region-}" ]; then
    echo "Current region isn't set for the AWS CLI neiser via AWS_DEFAULT_REGION environment variable nor via 'aws configure'."
    echo "It have to be set to launch an ec2 instance in this region."
    exit 5
fi

echo "Validating bucket \"$bucket_name\"..."
if ! bucket_region=$(aws s3api get-bucket-location --bucket $bucket_name --output text) || [ -z "$bucket_region" ]; then
    echo "The bucket $bucket_name doesn't exist or you don't own it."
    exit 6
fi

if [[ "$current_region" != "$bucket_region" ]]; then
    echo "The AWS CLI is configured to use the '$current_region' region. And an ec2 instance will be launched in this region."
    echo "However the bucket '$bucket_name' is located in the different region '$bucket_region'."
    echo "Please chouse another bucket in the '$current_region' region or change current region to the '$bucket_region'."
    echo "NOTE: The launched ec2 instance, s3 bucket and KMS key should be in the same region!"
    exit 7
fi

echo "Validating KMS key alias \"$kms_key_alias\"..."
# Check is it a key ID like a UUID, like this 6dff1da6-da8e-43ac-9127-d39ed3c540d6 or something else, assuming an alias.
alias_prefix="alias/"
[[ $kms_key_alias =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] && alias_prefix=
if ! kms_key_description=$(aws kms describe-key --key-id $alias_prefix$kms_key_alias --output json); then
    echo "The KMS key alias '$kms_key_alias' isn't found!"
    exit 8
fi

kms_key_arn=$(echo "$kms_key_description" | grep "arn:aws:kms" |  tr -d '",' | awk '{ print $NF}')
kms_key_region=$(echo "$kms_key_arn" | cut -d':' -f4)

if [[ "$current_region" != "$kms_key_region" ]]; then
    echo "The AWS CLI is configured to use the '$current_region' region. And an ec2 instance will be launched in this region."
    echo "However the KMS key '$kms_key_alias' is located in the different region '$kms_key_region'."
    echo "Please chouse another KMS key in the '$current_region' region or change current region to the '$kms_key_region'."
    echo "NOTE: The launched ec2 instance, s3 bucket and KMS key should be in the same region!"
    exit 9
fi

if ! aws ec2 describe-vpcs --filters "Name=isDefault, Values=true" --output text | grep default | grep -q True && [ -z "${subnet_id-}" ]; then
    echo "There is no default VPC in your profile. Please specify an argument \"--subnet-id\" with an ID of a subnet, associated with the VPC which you'd like to use."
    exit 15
fi

if [ -z "${security_group-}" ]; then
    security_group=$default_security_group
    if seq_groups=$(aws ec2 describe-security-groups); then
        vpc_sg_args=""
        if [ -n "${subnet_id-}" ]; then
            # Find VPC ID by subnet ID
            if ! vpc_id=$(aws ec2 describe-subnets --subnet-ids $subnet_id --output json | grep VpcId | tr -d '",' | awk '{ print $NF}') ; then
                echo "Failed to get non-default VPC ID by the subnet ID $subnet_id. Can't create a security group for the non-default VPC!"
                exit 16
            fi
            vpc_sg_args="Name=vpc-id,Values=$vpc_id"
            vpc_cg_create_args="--vpc-id $vpc_id"
        fi
        if ! aws ec2 describe-security-groups --filters Name=group-name,Values=$security_group $vpc_sg_args | grep -q GroupId ; then
            if ! sg_id=$(aws ec2 create-security-group $vpc_cg_create_args --group-name $security_group \
                                                       --description "Ports 22 and 61234 are open to the world for s0 server and ssh" \
                                                       --output text ) ; then
                echo "Failed to create a security group to open ports for s0 server and ssh. Do you have enough permissions?"
                exit 10
            fi
            if ! aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 22 --cidr 0.0.0.0/0 ||
               ! aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 61234 --cidr 0.0.0.0/0 ; then
                echo "Failed to open ports 22 and 61234 for s0 server and ssh!"
                exit 11
            fi
        fi
        [ -z "${sg_id-}" ] && sg_id=$(aws ec2 describe-security-groups --filters Name=group-name,Values=$security_group $vpc_sg_args | grep GroupId | head -1 | tr -d '",' | awk '{print $NF}')
    else
        echo "There is no permission to check existance of the security group '$security_group' and get its ID."
        echo "Please fix permissions to allow operations 'ec2:DescribeSecurityGroups,ec2:DescribeSecurityGroups,ec2:AuthorizeSecurityGroupIngress'"
        echo "or use script parameter '--security-group' instead!"
        exit 12
    fi
fi

if [ ! -z "${new_instance_profile-}" ]; then
    echo "Creating instance profile \"$new_instance_profile\"..."
    create_instance_profile $bucket_name $kms_key_arn $new_instance_profile
    instance_profile=$new_instance_profile
fi

echo "Validating instance profile \"$instance_profile\"..."
if ! aws iam get-instance-profile --instance-profile-name $instance_profile >/dev/null ; then
    echo "The instance profile '$instance_profile' isn't found!"
    exit 13
else
    existing_role=$(aws iam get-instance-profile --instance-profile-name $instance_profile | grep RoleName | head -1 | tr -d '",' | awk '{print $NF}')
    existing_policy=$(aws iam list-role-policies --role-name $existing_role --output text | cut -f2)
    if [ $(aws iam get-role-policy --policy-name $existing_policy --role-name $existing_role --output text | grep s3 | grep $bucket_name | wc -l) -ne 2 ]; then
        echo "Current instance profile has role $existing_role with the policy $existing_policy which hasn't access to the s3 bucket $bucket_name."
        echo "Please fix it or create another instance profile using the --create-profile script parameter."
        exit 15
    fi
fi

latest_ami=$(aws ec2 describe-images --owners $elastio_aws_id \
    --filters "Name=name,Values=s0-ami*" "Name=state,Values=available" \
    --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" --output text)

if [ -z "${latest_ami-}" ]; then
    echo "The Elastio s0 AMI was not found in region $current_region. This usually means the region is not one Elastio currently supports."
    exit 14
fi

export INSTANCE_NAME=$instance_name
export S0_BUCKET=$bucket_name
export S0_KMS="$alias_prefix$kms_key_alias"
export BLOCK_SIZE="--$block_size"
export DB_MOUNT=$db_mount
export SERVICE=$service
export UNIT_FILE=$unit_file

# Build the cloud-init script including some env vars
create_s0_bootstrap

echo "Launching \"$instance_name\" (instance type $instance_type) with the latest Elastio s0 AMI ($latest_ami)"

aws_subnet_args=""
[ -n "${subnet_id-}" ] && aws_subnet_args="--subnet-id $subnet_id"

instance_json=$(aws ec2 run-instances \
    --image-id "$latest_ami" \
    --instance-type "$instance_type" \
    --key-name "$ssh_key_name" \
    --iam-instance-profile Name="$instance_profile" \
    $instance_market_options \
    --ebs-optimized \
    --block-device-mappings "DeviceName=/dev/xvda,Ebs={VolumeSize=30}" \
    --user-data file://$bootstrap \
    --security-group-ids "$sg_id" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" \
    --output json $aws_subnet_args)

instance_id=$(echo "$instance_json" | grep InstanceId | tr -d '",' | awk '{print $NF}')
echo "Launched EC2 instance id $instance_id"

echo "Querying instance info for public DNS..."
instance_info=$(aws ec2 describe-instances --instance-ids $instance_id --output json)

instance_dns=$(echo "$instance_info" | grep PublicDnsName | head -1 | tr -d '",' | awk '{print $NF}')
if [ "$instance_dns" == "PublicDnsName:" ]; then
    if public_ip=$(echo "$instance_info" | grep PublicIpAddress | head -1 | tr -d '",' | awk '{print $NF}') && [ -n "$public_ip" ] && [ "$public_ip" != "PublicIpAddress:" ] ; then
        echo
        echo "The instance has no public DNS but has public IP. It seems you are using non-default VPC with the disabled \"DNS hostnames\"."
        echo
        echo "SSH into the instance with 'ssh ec2-user@$public_ip' using key $ssh_key_name."
    else
        echo "The instance has no public DNS. It seems you are using non-default VPC and a subnet without \"auto-assign public IPv4 address\" enabled."
        private_ip=$(echo "$instance_info" | grep -w PrivateIpAddress | head -1 | tr -d '",' | awk '{print $NF}')
        echo "The started ec2 instance is available just in the internal subnet by the private IP: $private_ip"
    fi
else
    echo "The instance DNS is $instance_dns"
    echo
    echo "SSH into the instance with 'ssh ec2-user@$instance_dns' using key $ssh_key_name."
fi
