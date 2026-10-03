############################################
# INITIALIZE LAB PARAMETERS AND PACKAGES   #
############################################
CLIENT_IP="Put in your IP Address" # Change this line
LAB_EC2_NAME="mlflow"
LAB_KEY_NAME="${LAB_EC2_NAME}-keypair"
LAB_KEY_FILE="${LAB_KEY_NAME}.pem"
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
CLOUD9_LOCAL_IPV4=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4`

DATABASE_INSTANCE="labrdsinstance"
DATABASE_NAME="mlflowdb"
DATABASE_USER="dbadmin"
DATABASE_SECURITY_GROUP="rds-securitygroup"

if [ ! -f "/usr/local/aws-cli/v2/current/bin/aws" ]; 
then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
fi

alias aws2="/usr/local/aws-cli/v2/current/bin/aws"
aws configure set region us-east-1
aws2 configure set region us-east-1

export AWS_SHARED_CREDENTIALS_FILE=/home/ec2-user/.aws/credentials

############################################
# USE EXISTING OR CREATE NEW S3 BUCKET     #
############################################
S3_BUCKET_NAME=`aws s3api list-buckets --query "Buckets[0].Name" --output text`

if [ "${S3_BUCKET_NAME}" == None ]; 
then
    S3_BUCKET_NAME="s3-dle-`uuidgen`"
    aws s3api create-bucket --bucket ${S3_BUCKET_NAME} --no-cli-pager
fi

############################################
# CREATE EC2 INSTANCE USING AWS CLI        #
############################################
CIDR_SUFFIX=
if [ "${CLIENT_IP}" = "0.0.0.0" ]; then
    CIDR_SUFFIX="/0"
else
    CIDR_SUFFIX="/32"
fi

aws ec2 create-key-pair \
    --key-name "${LAB_KEY_NAME}" \
    --query 'KeyMaterial' \
    --output text > "${LAB_KEY_FILE}" --no-cli-pager

chmod 400 "${LAB_KEY_FILE}" # Change file permissions 

# Add necessary firewall rules to EC2 security group
aws ec2 create-security-group --group-name "${LAB_EC2_NAME}-sg" \
  --description "mlflow security group" --no-cli-pager
  
SECURITY_GROUP_ID=`aws ec2 describe-security-groups --group-names "${LAB_EC2_NAME}-sg" --query "SecurityGroups | [0].GroupId" --output text`

aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 22 --cidr "${CLOUD9_LOCAL_IPV4}/32" --no-cli-pager
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 22 --cidr "${CLIENT_IP}${CIDR_SUFFIX}" --no-cli-pager
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 5000 --cidr "${CLIENT_IP}${CIDR_SUFFIX}" --no-cli-pager
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 8888 --cidr "${CLIENT_IP}${CIDR_SUFFIX}" --no-cli-pager
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 8083 --cidr "${CLOUD9_LOCAL_IPV4}/32" --no-cli-pager
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 8080 --cidr "${CLIENT_IP}${CIDR_SUFFIX}" --no-cli-pager
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 9092 --cidr "${CLIENT_IP}${CIDR_SUFFIX}" --no-cli-pager

# Run instances
aws ec2 run-instances --image-id ami-06e46074ae430fba6 \
  --count 1 \
  --instance-type t2.micro \
  --key-name ${LAB_KEY_NAME} \
  --security-group-ids ${SECURITY_GROUP_ID} \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${LAB_EC2_NAME}}]" --no-cli-pager

# Query instance details
EC2_INSTANCE_ID=`aws ec2 describe-instances --filters "Name=tag:Name,Values=${LAB_EC2_NAME}" --query 'Reservations[*].Instances[*].InstanceId | [0] | [0]' --output text`
aws ec2 wait instance-running --instance-ids ${EC2_INSTANCE_ID}  --no-cli-pager
EC2_DNS=`aws ec2 describe-instances --filters "Name=tag:Name,Values=${LAB_EC2_NAME}" --query 'Reservations[*].Instances[*].PublicDnsName | [0] | [0]' --output text`
EC2_LOCAL_IPV4=`aws ec2 describe-instances --filters "Name=tag:Name,Values=${LAB_EC2_NAME}" --query 'Reservations[*].Instances[*].PrivateIpAddress | [0] | [0]' --output text`

# Associate LabInstanceProfile with EC2 instance for S3 access
# aws ec2 associate-iam-instance-profile --iam-instance-profile Name=LabInstanceProfile --instance-id ${EC2_INSTANCE_ID} --no-cli-pager

