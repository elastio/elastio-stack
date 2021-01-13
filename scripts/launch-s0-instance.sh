#!/bin/bash

me=$(basename $0)
dir=$(readlink -f $(dirname $0))
elastio_aws_id=537513441174
security_group="elastio-s0-server"
default_instance_type="m5d.2xlarge"
default_instance_name="$(whoami)-s0-server"

usage()
{
    echo "Usage examples:"
    echo "   $me --key-name my_ec2_key --name my_s0_server --type m5d.2xlarge"
    echo "   $me --k /path/to/key.pem -n my_s0_server -t m5d.2xlarge"
    echo
    echo "  -k | --key-name : A name of an aws EC2 key in the PEM format for the SSH connection to the instance."
    echo
    echo "  -n | --name     : Optional. Name of an instance. It's shown in the AWS console."
    echo "                    The default value is \"[user_name]-s0-server\"."
    echo
    echo "  -t | --type     : Optional. An instance type. See https://aws.amazon.com/ec2/instance-types/ for more details."
    echo "                    The default value is \"m5d.2xlarge\"."
    echo
    echo "  -h | --help     : Show this usage help."
}

[ "$1" == "" ] && echo "Script need some arguments!" && usage && exit -1

while [ "$1" != "" ]; do
    case $1 in
        -k | --key-name)   shift && key_name=$1 ;;
        -n | --name)       shift && instance_name=$1 ;;
        -t | --type)       shift && instance_type=$1 ;;
        -h | --help)       usage && exit ;;
        *)                 echo "Wrong arguments!"
                           usage && exit 15 ;;
    esac
        shift
done

set -e

if [ -z "$key_name" ]; then
    echo "Please specify the '--key-name' parameter. Otherwise, you won't be able to connect to the running instance via ssh!"
    echo
    usage
    exit 1
fi

[ -z "$instance_name" ] && instance_name=$default_instance_name
[ -z "$instance_type" ] && instance_type=$default_instance_type

latest_ami=$(aws ec2 describe-images --owners $elastio_aws_id \
    --filters "Name=name,Values=s0-ami*" "Name=state,Values=available" \
    --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" --output text)

if aws ec2 describe-security-groups | jq '.SecurityGroups[].GroupName' | tr -d '"' | grep -q "$security_group" ; then
    sg_id=$(aws ec2 describe-security-groups --group-names $security_group --query "SecurityGroups[:1].GroupId" --output text)
else
    if ! sg_id=$(aws ec2 create-security-group --group-name $security_group --description "Ports 22 and 61234 are open to the world for s0 server and ssh" --output text) ; then
        echo "Failed to create a security group to open ports for s0 server and ssh. Do you have enough permissions?"
        exit 2
    fi
    if ! aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 22 --cidr 0.0.0.0/0 ||
       ! aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 61234 --cidr 0.0.0.0/0 ; then
        echo "Failed to open ports 22 and 61234 for s0 server and ssh!"
        exit 3
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
echo "SSH into the instance using the key '$key_name' like this: 'ssh -i /path/to/$key_name.pem ec2-user@$instance_dns'"
