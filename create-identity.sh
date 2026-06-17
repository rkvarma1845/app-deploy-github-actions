#!/bin/bash

RESOURCE_GROUP="my-rg"
LOCATION="centralindia"
IDENTITY_NAME="my-uami"
ACR_NAME="myacr"

echo "Creating User Assigned Identity..."

az identity create \
  --name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

PRINCIPAL_ID=$(az identity show \
  --name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --query principalId \
  --output tsv)

echo "Done."
