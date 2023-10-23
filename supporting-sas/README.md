# se-sas-enablement
This repository contains the hands-on training materials for the solution engineers to get started with supporting SAS in customer environments. Details information on SAS can be found in the SAS runbook, https://docs.google.com/document/d/1srBVL93i9qhRMoFt2I6UoacDpL9dURf1lpSn5NbZjSM/edit#heading=h.514rlcmzmvw9

The exercises listed below cover SAS Analytics Pro/SAS Analytics Pro Advanced Programming and SAS for Containers 9.4 (SAS4C 9.4) versions.

# Prerequisites
- Read through the SAS runbook put together by the Partner team, https://docs.google.com/document/d/1srBVL93i9qhRMoFt2I6UoacDpL9dURf1lpSn5NbZjSM/edit#heading=h.514rlcmzmvw9
- A Domino instance to create compute environments and test workloads. 
- Valid SAS License key and Certificate file bundle to pull the SAS Analytics Pro/Advance programming images from the SAS docker registry.
- SAS Order Number and SAS Installation key for SAS4C 9.4. These are required for downloading the SAS software depot files required for the installation.
- EC2 instance or Mac with docker running to pull, build, and push docker images.

Please reach out to Wasantha Gamage or Jed Record if you need help getting the prerequisites. 

# Exercise 1 - Install SAS Compute Environments

This exercise will walk you through a typical SAS compute environment in Domino.

## SAS Analytics Pro/ SAS Analytics Pro - Advanced Programming

### Step 1: 
Pull the SAS Analytics Pro image from the SAS docker registry. Follow the How to pull an image from the SAS repository section from the SAS Runbook.
https://docs.google.com/document/d/1srBVL93i9qhRMoFt2I6UoacDpL9dURf1lpSn5NbZjSM/edit#heading=h.j1rv99xald9l


### Step 2: 
Build the SAS base image with Domino hooks. An example Dockerfile is available here, https://docs.google.com/document/d/1srBVL93i9qhRMoFt2I6UoacDpL9dURf1lpSn5NbZjSM/edit#heading=h.jxoxepix59ja


### Step3: 
Push the SAS image to a docker registry

### Step4: 
Create a Domino compute environment with the base image, https://docs.google.com/document/d/1srBVL93i9qhRMoFt2I6UoacDpL9dURf1lpSn5NbZjSM/edit#heading=h.jxoxepix59ja


## SAS Analytics for Containers (SAS4C) 9.4
Installing SAS 9.4 is a complex process. First, you need to deploy SAS 9.4 for Unix/Linux outside of the Domino and get the content of the SASHome directory in a tar format. The steps are described here, https://docs.google.com/document/d/17-QGGdtHR_5dW1P5SWu2Y3Gln2Zfq7yFQLySZocG0_o/edit#heading=h.sowpimyei9ok

Then you can build the SAS compute environment following the SAS runbook https://docs.google.com/document/d/1srBVL93i9qhRMoFt2I6UoacDpL9dURf1lpSn5NbZjSM/edit#heading=h.aotxygq3zlko.

# Excercise 2 - Execute SAS code
# Excercise 3 - Customize SAS Compute Environments 
# Excercise 4 - Configure External Data access