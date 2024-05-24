# app/services/acrobat_sign_service.rb
class AcrobatSignService
    require "faraday/multipart"
  
    # This method is used to get the access token for the Adobe Sign API
    def self.access_token
      new.access_token
    end
  
    def access_token
      #Check if there is and existing token and if it has expired
      stored_token = Rails.cache.read(:acrobat_sign_access_token)
  
      if stored_token && stored_token[:expires_at] > Time.current
        # If the token is still valid, return it
        stored_token[:value]
      else
        # If the token is expired or doesn't exist, refresh it
        refresh_tokens
        Rails.cache.read(:acrobat_sign_access_token)[:value]
      end
    end
  
    def self.create_transient_document(file_path)
      #For every request to the Adobe Sign API, you need to include the access token in the Authorization header
  
      access_token = self.access_token
      base_url = Rails.application.credentials.dig(:acrobat_sign, :api_access_point)
      transient_url = "#{base_url}api/rest/v6/transientDocuments"
  
      conn = Faraday.new(url: transient_url) do |f|
        f.request :multipart
        f.request :url_encoded
        f.adapter :net_http
      end
  
      file_name = File.basename(file_path)
      mime_type = "application/vnd.openxmlformats-officedocument.wordprocessingml.document" # MIME type for .docx files
  
      payload = {
        "File-Name" => file_name,
        "File" => Faraday::Multipart::FilePart.new(file_path, mime_type, file_name),
      }
  
      response = conn.post do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
        req.headers["Accept"] = "application/json"
        req.body = payload
      end
  
      if response.success?
        { success: true, body: JSON.parse(response.body) }
      else
        { success: false, error: "Failed to create transient document: #{response.status} - #{response.body}" }
      end
    end
  
    def self.create_agreement(transient_document_id, agreement_name, participant_email, signature_type, state)
      #For every request, you need to include the access token
  
      access_token = self.access_token
      base_url = Rails.application.credentials.dig(:acrobat_sign, :api_access_point)
      agreement_url = "#{base_url}api/rest/v6/agreements"
  
      conn = Faraday.new(url: agreement_url) do |f|
        f.request :json
        f.headers["Authorization"] = "Bearer #{access_token}"
        f.headers["Accept"] = "application/json"
        f.headers["Content-Type"] = "application/json"
        f.adapter Faraday.default_adapter
      end
  
      #Create the agreement parameters, including the transient document ID
  
      agreement_params = {
        fileInfos: [{
          transientDocumentId: transient_document_id,
        }],
        name: agreement_name,
        participantSetsInfo: [{
          memberInfos: [{
            email: participant_email,
          }],
          order: 1,
          role: "SIGNER",
        }],
        signatureType: signature_type,
        state: state,
      }
  
      response = conn.post do |req|
        req.body = agreement_params.to_json
      end
  
      if response.success?
        { success: true, body: JSON.parse(response.body) }
      else
        { success: false, error: "Failed to create agreement: #{response.status} - #{response.body}" }
      end
    end
  
    def self.download_contract(agreement_id)
      #This method downloads the signed contract as a PDF file
  
      access_token = self.access_token
      base_url = Rails.application.credentials.dig(:acrobat_sign, :api_access_point)
      agreement_url = "#{base_url}api/rest/v6/agreements/#{agreement_id}/combinedDocument"
  
      conn = Faraday.new(url: agreement_url) do |f|
        f.headers["Authorization"] = "Bearer #{access_token}"
        f.headers["Accept"] = "application/pdf" # Specify that you expect a PDF response
        f.adapter Faraday.default_adapter
      end
  
      response = conn.get
  
      if response.success?
        StringIO.new(response.body)
      else
        { success: false, error: "Failed to download contract: #{response.status} - #{response.body}" }
      end
    end
  
    private
  
    def refresh_tokens
      # Make a POST request to the Adobe Sign API to refresh the access token
  
      base_url = Rails.application.credentials.dig(:acrobat_sign, :api_access_point)
      refresh_endpoint = "/oauth/v2/refresh"
      conn = Faraday.new(url: "#{base_url}#{refresh_endpoint}")
      response = conn.post do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.headers["Accept"] = "application/json"
        req.body = {
          refresh_token: Rails.application.credentials.dig(:acrobat_sign, :refresh_token),
          client_id: Rails.application.credentials.dig(:acrobat_sign, :client_id),
          client_secret: Rails.application.credentials.dig(:acrobat_sign, :client_secret),
          grant_type: "refresh_token",
        }.to_query
      end
  
      # Parse the response and update the tokens and expiration time
      if response.status == 200
        data = JSON.parse(response.body)
        update_tokens_and_expiration(
          data["access_token"],
          data["refresh_token"],
          data["expires_in"].to_i,
          data["api_access_point"] || Rails.application.credentials.dig(:acrobat_sign, :api_access_point),
          data["web_access_point"] || Rails.application.credentials.dig(:acrobat_sign, :web_access_point)
        )
      else
        Rails.logger.error("Error refreshing token: #{response.status} - #{response.body}")
        raise "Failed to refresh the Adobe Acrobat Sign access token. Response: #{response.status} - #{response.body}"
      end
    end
  
    def update_tokens_and_expiration(access_token, refresh_token, expires_in, api_access_point, web_access_point)
      Rails.cache.write(:acrobat_sign_access_token, { value: access_token, expires_at: Time.current + expires_in.seconds }, expires_in: expires_in.seconds)
      Rails.cache.write(:acrobat_sign_refresh_token, refresh_token) if refresh_token
      # Optionally update API and web access points if necessary and provided
      Rails.cache.write(:acrobat_sign_api_access_point, api_access_point) if api_access_point
      Rails.cache.write(:acrobat_sign_web_access_point, web_access_point) if web_access_point
    end
  end
  