#!/bin/bash

# Create lab-network stack
echo "Creating lab-network stack..."
aws cloudformation create-stack \
  --stack-name lab-network \
  --template-body file://lab-network.yaml \
  --tags Key=application,Value=inventory

# Wait for lab-network stack creation to complete
echo "Waiting for lab-network stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name lab-network
echo "lab-network stack creation completed."

# Create lab-application stack
echo "Creating lab-application stack..."
aws cloudformation create-stack \
  --stack-name lab-application \
  --template-body file://lab-application.yaml \
  --parameters ParameterKey=NetworkStackName,ParameterValue=lab-network \
  --tags Key=application,Value=inventory

# Wait for lab-application stack creation to complete
echo "Waiting for lab-application stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name lab-application
echo "lab-application stack creation completed."

# Retrieve outputs for lab-application stack
echo "Retrieving outputs for lab-application stack..."
aws cloudformation describe-stacks --stack-name lab-application --query 'Stacks[0].Outputs' --output table

# Create change set for updating the lab-application stack
CHANGE_SET_NAME="lab-application-changeset-$(date +%s)"
echo "Creating change set for lab-application update..."
aws cloudformation create-change-set \
  --stack-name lab-application \
  --template-body file://lab-application2.yaml \
  --parameters ParameterKey=NetworkStackName,ParameterValue=lab-network \
  --tags Key=application,Value=inventory \
  --change-set-name $CHANGE_SET_NAME \
  --change-set-type UPDATE

# Wait for the change set creation to complete
echo "Waiting for the change set creation to complete..."
aws cloudformation wait change-set-create-complete \
  --stack-name lab-application \
  --change-set-name $CHANGE_SET_NAME
echo "Change set created: $CHANGE_SET_NAME"

# Display the details of the change set (resources that will be updated)
echo "Showing changes for the update..."
aws cloudformation describe-change-set \
  --stack-name lab-application \
  --change-set-name $CHANGE_SET_NAME \
  --query 'Changes[*].ResourceChange.{Action:Action,LogicalResourceId:LogicalResourceId,ResourceType:ResourceType,Replacement:Replacement}' \
  --output table

# Confirm if the user wants to apply the change set
read -p "Do you want to execute the change set? (yes/no): " choice
if [ "$choice" == "yes" ]; then
  # Execute the change set
  echo "Executing the change set..."
  aws cloudformation execute-change-set \
    --stack-name lab-application \
    --change-set-name $CHANGE_SET_NAME

  # Wait for lab-application stack update to complete
  echo "Waiting for lab-application stack update to complete..."
  aws cloudformation wait stack-update-complete --stack-name lab-application
  echo "lab-application stack update completed."
else
  echo "Change set not executed."
fi

# Delete lab-application stack
echo "Deleting lab-application stack..."
aws cloudformation delete-stack --stack-name lab-application

# Wait for lab-application stack deletion to complete
echo "Waiting for lab-application stack deletion to complete..."
aws cloudformation wait stack-delete-complete --stack-name lab-application
echo "lab-application stack deleted successfully."
