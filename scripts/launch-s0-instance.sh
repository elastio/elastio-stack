#!/bin/bash

me=$(basename $0)
dir=$(readlink -f $(dirname $0))
elastio_aws_id=537513441174
default_security_group="elastio-s0-server"
default_instance_type="m5d.2xlarge"
default_instance_name="$(whoami)-s0-server"
default_block_size=fixed
bootstrap=/tmp/s0-bootstrap.yml
db_mount=/mnt/elastio
unit_file=/etc/systemd/user/s0.service
service=s0

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
      ExecStart=/bin/bash -c '/usr/bin/s0 --log-output compact vault serve s3 --bucket $S0_BUCKET --key-id $S0_KMS $BLOCK_SIZE --server-address 0.0.0.0 --db-path $DB_MOUNT 2>&1 | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" >> /var/log/s0-service.log'
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
    s0 vault create s3 --bucket $S0_BUCKET --key-id $S0_KMS 2>&1 | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" > /var/log/s0-vault-create.log

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

usage()
{
    echo "Usage examples:"
    echo "   $me --ssh-key-name my_ec2_key --instance-name my_s0_server --instance-type m5d.2xlarge --kms-key-alias my_kms_key --bucket-name my_s3_bucket"
    echo "   $me -s my_ec2_key -n my_s0_server -t m5ad.2xlarge -k my_kms_key -b my_s3_bucket"
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
    echo "                              The grop 'elastio-s0-server' will be created and then used in case if this OR next argument is not specified."
    echo "                              NOTE: The group existance and the pen ports in the group aren't checked."
    echo "                                    The script may not have permissions and assumes that the group is configured properly."
    echo
    echo "  -b | --bucket-name        : s3 bucket name for s0 vault."
    echo
    echo "  -k | --kms-key-alias      : KMS key alias for the data encription in the s0 vault."
    echo
    echo "  -p | --instance-profile   : An instance provile with access to the s3 bucket and KMS key from 2 parametrers abowe."
    echo "                              See aws doscs for more details how to create one:"
    echo "                              https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html"
    echo "                              https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html"
    echo
    echo "  -z | --s0-block-size      : Optional. A block size for the s0 shard. There are 2 possible values: \"fixed\" and \"variable\". The \"fixed\" is default."
    echo "                              - The \"fixed\" selects the shard with a fixed-length block size."
    echo "                                This shard is intended for use with backups of block storage systems like EBS, local disks, and VMs."
    echo "                              - The \"variable\" selects the shard with a variable-length block size."
    echo "                                This shard is intended for use with backups of file systems, streams, and any other data that isn't organized"
    echo "                                into fixed size blocks."
    echo
    echo "  -h | --help               : Show this usage help."
}

[ "$1" == "" ] && echo "Script need some arguments!" && usage && exit -1

while [ "$1" != "" ]; do
    case $1 in
        -s | --ssh-key-name)        shift && ssh_key_name=$1 ;;
        -n | --instance-name)       shift && instance_name=$1 ;;
        -t | --instance-type)       shift && instance_type=$1 ;;
        -g | --security-group)      shift && security_group=$1 ;;
        -b | --bucket-name)         shift && bucket_name=$1 ;;
        -k | --kms-key-alias)       shift && kms_key_alias=$1 ;;
        -p | --instance-profile)    shift && instance_profile=$1 ;;
        -z | --s0-block-size)       shift && block_size=$1 ;;
        -h | --help)                usage && exit ;;
        *)                          echo "Wrong arguments!"
                                    usage && exit 15 ;;
    esac
        shift
done

if ! which aws >/dev/null 2>&1 || [[ $(aws --version | cut -d' ' -f1 | cut -d'/' -f2 | cut -d'.' -f1) < "2" ]]; then
    echo "Please install aws cli v.2 and try again."
    echo "You can use a package manager i.e. dnf/yum or apt or follow this instruction https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html."
    exit 1
fi

set -e

if [ -z "$ssh_key_name" ]; then
    echo "Please specify the '--ssh-key-name' parameter. Otherwise, you won't be able to connect to the running instance via ssh!"
    echo
    usage
    exit 2
fi

if [ -z "$kms_key_alias" ] || [ -z "$bucket_name" ] || [ -z "$instance_profile" ]; then
    echo "The '--instance-profile', '--bucket-name' and '--kms-key-alias' are required parameters. Please specify them."
    echo
    usage
    exit 3
fi

[ -z "$instance_name" ] && instance_name=$default_instance_name
[ -z "$instance_type" ] && instance_type=$default_instance_type
[ -z "$block_size" ]    && block_size=$default_block_size

case $block_size in
  fixed)    ;;
  variable) ;;
  *) echo "The value of the \"--s0-block-size\" should be equal to the \"fixed\" or \"variable\". Current value is \"$block_size\" and it's unexpected."
     echo
     usage
     exit 4
  ;;
esac

latest_ami=$(aws ec2 describe-images --owners $elastio_aws_id \
    --filters "Name=name,Values=s0-ami*" "Name=state,Values=available" \
    --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" --output text)

if [ -z "$security_group" ]; then
    security_group=$default_security_group
    if seq_gropups=$(aws ec2 describe-security-groups); then
        if ! echo "$seq_gropups" | jq '.SecurityGroups[].GroupName' | tr -d '"' | grep -q "$security_group" ; then
            if ! sg_id=$(aws ec2 create-security-group --group-name $security_group --description "Ports 22 and 61234 are open to the world for s0 server and ssh" --output text) ; then
                echo "Failed to create a security group to open ports for s0 server and ssh. Do you have enough permissions?"
                exit 3
            fi
            if ! aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 22 --cidr 0.0.0.0/0 ||
               ! aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 61234 --cidr 0.0.0.0/0 ; then
                echo "Failed to open ports 22 and 61234 for s0 server and ssh!"
                exit 4
            fi
        fi
    else
        echo "There is no permission to check existance of the security group '$security_group' and get its ID."
        echo "Please fix permissions to allow operations 'ec2:DescribeSecurityGroups,ec2:DescribeSecurityGroups,ec2:AuthorizeSecurityGroupIngress'"
        echo "or use script parameter '--security-group' instead!"
        exit 5
    fi
fi

export INSTANCE_NAME=$instance_name
export S0_BUCKET=$bucket_name
export S0_KMS=$kms_key_alias
export BLOCK_SIZE="--$block_size"
export DB_MOUNT=$db_mount
export SERVICE=$service
export UNIT_FILE=$unit_file

# Build the cloud-init script including some env vars
create_s0_bootstrap

echo "Launching \"$instance_name\" (instance type $instance_type) with the latest Elastio s0 AMI ($latest_ami)"

instance_json=$(aws ec2 run-instances \
    --image-id "$latest_ami" \
    --instance-type "$instance_type" \
    --key-name "$ssh_key_name" \
    --iam-instance-profile Name="$instance_profile" \
    --ebs-optimized \
    --block-device-mappings "DeviceName=/dev/xvda,Ebs={VolumeSize=30}" \
    --user-data file://$bootstrap \
    --security-groups "$security_group" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" \
    --output json)

#echo $instance_json | jq "."

instance_id=$(echo $instance_json | jq ".Instances[].InstanceId" -r)
echo "Launched EC2 instance id $instance_id"

echo "Querying instance info for public DNS..."
instance_info=$(aws ec2 describe-instances --instance-ids $instance_id --output json)

instance_dns=$(echo $instance_info | jq ".Reservations[].Instances[].PublicDnsName" -r)

echo "The instance DNS is $instance_dns"
echo
echo "SSH into the instance with 'ssh ec2-user@$instance_dns' using key $ssh_key_name."
