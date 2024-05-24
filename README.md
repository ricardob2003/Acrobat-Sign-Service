# Acrobat Sign Service

This Rails service, `AcrobatSignService`, is designed to integrate Adobe Sign API functionalities into your Rails application. It allows for creating, managing, and downloading agreements (contracts) dynamically using the Adobe Sign API. The service includes functionalities to handle access tokens, create transient documents, create agreements, and download signed agreements as PDFs.

## Features

- **Token Management**: Handles the generation and refreshing of OAuth tokens for the Adobe Sign API.
- **Document Handling**: Manages the uploading of documents to Adobe Sign to create transient documents.
- **Agreement Creation**: Facilitates the creation of agreements for signatures using transient document IDs.
- **Download Agreements**: Allows downloading of the finalized agreements in PDF format.

## Requirements

- Ruby on Rails
- Faraday gem for HTTP requests
- Adobe Sign API credentials
- rails credentials:edit and ensure credentials adhere to the following format 

acrobat_sign:
  client_id: your_client_id
  client_secret: your_client_secret
  refresh_token: your_refresh_token
  api_access_point: your_api_endpoint


Ensure the `faraday` and `faraday_multipart` gems are included in your Gemfile:

```ruby
gem 'faraday'
gem 'faraday_multipart'
