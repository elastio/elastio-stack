#!/bin/bash

me=$(basename $0)
dir=$(readlink -f $(dirname $0))
elastio_aws_id=537513441174
default_security_group="elastio-s0-server"
default_instance_type="m5d.2xlarge"
default_instance_name="$(whoami)-s0-server"

usage()
{
    echo "Usage examples:"
    echo "   $me --key-name my_ec2_key --name my_s0_server --type m5d.2xlarge"
    echo "   $me -k my_ec2_key -n my_s0_server -t m5ad.2xlarge"
    echo
    echo "  -k | --ssh-key-name       : A name of an aws EC2 key in the PEM format for the SSH connection to the instance."
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
    echo "  -h | --help             : Show this usage help."
}

[ "$1" == "" ] && echo "Script need some arguments!" && usage && exit -1

while [ "$1" != "" ]; do
    case $1 in
        -k | --ssh-key-name)        shift && key_name=$1 ;;
        -n | --instance-name)       shift && instance_name=$1 ;;
        -t | --instance-type)       shift && instance_type=$1 ;;
        -g | --security-group)      shift && security_group=$1 ;;
        -h | --help)                usage && exit ;;
        *)                          echo "Wrong arguments!"
                                    usage && exit 15 ;;
    esac
        shift
done

if ! which aws >/dev/null 2>&1; then
    echo "Please install aws cli v.2 and try again."
    echo "You can use a package manager i.e. dnf/yum or apt or follow this instruction https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html."
    exit 1
fi

set -e

if [ -z "$key_name" ]; then
    echo "Please specify the '--key-name' parameter. Otherwise, you won't be able to connect to the running instance via ssh!"
    echo
    usage
    exit 2
fi

[ -z "$instance_name" ] && instance_name=$default_instance_name
[ -z "$instance_type" ] && instance_type=$default_instance_type

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

echo "Launching \"$instance_name\" (instance type $instance_type) with the latest Elastio s0 AMI ($latest_ami)"

instance_json=$(aws ec2 run-instances \
    --image-id "$latest_ami" \
    --instance-type "$instance_type" \
    --key-name "$key_name" \
    --ebs-optimized \
    --security-groups "$security_group" \
    --tag-specifications \
    "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" \
    --output json)

#echo $instance_json | jq "."

instance_id=$(echo $instance_json | jq ".Instances[].InstanceId" -r)
echo "Launched EC2 instance id $instance_id"

echo "Querying instance info for public DNS..."
instance_info=$(aws ec2 describe-instances --instance-ids $instance_id --output json)

instance_dns=$(echo $instance_info | jq ".Reservations[].Instances[].PublicDnsName" -r)

echo "The instance DNS is $instance_dns"
echo
echo "SSH into the instance with 'ssh ec2-user@$instance_dns' using key $key_name."
