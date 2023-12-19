# 🕊️  Self Paced Enablement for configuring SSO for your own Domino using Azure Entra ID as an IDP 🕊️


## Enterprise Application

To delegate identity and access management functions to Microsoft Entra ID, an application must be registered with a Microsoft Entra tenant. When you register your application with Microsoft Entra ID, you're creating an identity configuration for your application that allows it to integrate with Microsoft Entra ID

For the rest of this guideline we will use the terrafrom code below to create an Enterprise application and all needed features in order to authenticate with Domino keycloak using SAML or OIDC - both configurations have different workflows and parameters to connect to Domino which we will deep dive into further in this runbook.
https://github.com/cerebrotech/AzureEntraID-SSO/tree/main/EntraIDApp 



## SAML Provider 

1. Create Enterprise application:

 In order to create the application use the terrafrom code above - in the [main.tf](https://github.com/cerebrotech/AzureEntraID-SSO/blob/main/EntraIDApp/main.tf) file you need to replace the display names for the user group, the application and the redirect uris of your Domino instance which you can get from keycloak. (in this case we will use the SAML provider endpoint)


<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/saml-provider.png"/>


The steps to deploy the code are outlined in the [Readme](https://github.com/cerebrotech/AzureEntraID-SSO/blob/main/Readme.md) file. 

Post applying the terrafrom code you will get two outputs which we will use later on to connect to keycloak

For the case of SAML authentication we will need only the Entity ID output

### Via Terraform:

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/via-terrafrom.png"/>


### Via Azure UI:

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/via-azure-ui.png"/>


2. Authenticate to keycloak through SAML 

Go to Azure UI Entra ID → Application → Overview → Endpoints → Federation metadata documents → Copy

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/Authenticate-to-keycloak-through-SAML1.png"/>

Go to Domino Keycloak UI → SAML provider → import External IDP Config → Paste & Import the config

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/Authenticate-to-keycloak-through-SAML2.png"/>

Now since you have the SAML provider enabled using Entra ID App, you need to add:

`Service Provider Entity ID` is Terrafrom output `Enitity ID`

Configuration `Truset Email` and `Enabled` need to be enabled

First Login Flow should be `Domino First Broker Login`

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/Authenticate-to-keycloak-through-SAML3.png"/>

2. Add Mappers to keycloak: 

Go to Identoty Provider → SAML → Mappers and edit the following 3 mappers:

Email Mapper: `Attribute Name`: http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/addmappers1.png"/>

First Name Mapper: `Attribute Name`: http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/addmappers2.png"/>

Last Name Mapper: `Attribute Name`: http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/addmappers3.png"/>

Create a new mapper wih `Template`: ${ATTRIBUTE.http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name | localpart}

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/addmappers4.png"/>

***the NameID is a way of identifying a user. It's a unique identifier assigned to a user which is used to manage their identity across different systems. When a user authenticates via a SAML Identity Provider (IdP), the NameID is used to represent the user's identity in SAML assertions.In the context of Azure Entra ID, the NameID format can vary. It might be an email address, a username, a uuid or something else, depending on how the [SAML configuration is set up in Azure](https://learn.microsoft.com/en-us/entra/identity-platform/saml-claims-customization#view-or-edit-claims). Azure Entra ID and the Keycloak must agree on the format of the NameID.***






## OIDC Provider 

1. Create Enterprise application:

 In order to create the application use the terrafrom code above - in the [main.tf](https://github.com/cerebrotech/AzureEntraID-SSO/blob/main/EntraIDApp/main.tf) file you need to replace the display names for the user group, the application and the redirect uris of your Domino instance which you can get from keycloak. (in this case we will use the OIDC provider endpoint)

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/oidc1.png"/>


The steps to deploy the code are outlined in the [Readme](https://github.com/cerebrotech/AzureEntraID-SSO/blob/main/Readme.md) file. 

Post applying the terrafrom code you will get two outputs which we will use later on to connect to keycloak

For the case of OIDC authentication we will need the OIDC_secret output and the Entity ID


Via Terraform:


<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/oidc2.png"/>


Via Azure UI:

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/oidc3.png"/>

2. Authenticate to keycloak through OIDC

Go to Azure UI Entra ID → Application → Overview → Endpoints → OpenID Connect metadata documents → Copy

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/oidc4.png"/>

Go to Domino Keycloak UI → OIDC provider → import External IDP Config → Paste & Import the config

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/oidc5.png"/>


Now that the OIDC provider imported the application config, you need to fill in: 

`Client ID` with the first Terrafrom output `Enitity ID`

`Client secret` with the second Terraform output `OIDC_secret` 

Configuration `Store Tokens` and `Stored Tokens Readable` need to be enabled

First Login Flow should be `Domino First Broker Login`

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/oidc6.png"/>

***For OIDC configuration we do not need to create mappers as these will be automatically imported from the User Info URL***