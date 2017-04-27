module Intercom
  # The service removes inactive users/leads from Intercom and uploads the contacts to sendinblue
  class InactiveUserDeletionService
    include Loggable

    # Map Intercom segments to SendinBlue list names
    SEGMENTS_TO_LIST = {
      'Stale Paid Applicants' => 'Paid Applicants',
      'Stale Payment Initiated' => 'Payment Initiated',
      'Stale Conversing Users' => 'Conversing Users',
      'Stale Applicants' => 'Applicants',
      'Stale Users' => 'Stale Users',
      'Stale Leads' => 'Stale Leads'
    }.freeze

    def initialize(mock: false)
      @mock = mock
      @intercom_client = Intercom::Client.new(token: Rails.application.secrets.intercom_access_token)
      @sendinblue_client = Sendinblue::Mailin.new('https://api.sendinblue.com/v2.0', Rails.application.secrets.sendinblue_api_key)
    end

    def execute
      intercom_segments.each do |segment|
        log "Uploading contacts from Intercom segment: #{segment} to SendinBlue..."
        upload_to_sendinblue(segment)
        log "Deleting users from Intercom segment: #{segment}"
        delete_from_intercom(segment)
      end
    end

    private

    def intercom_segments
      SEGMENTS_TO_LIST.keys
    end

    def upload_to_sendinblue(segment)
      sendinblue_contacts = contacts_to_upload(segment)
      return if sendinblue_contacts.blank?

      sendinblue_contacts.each do |contact|
        if @mock
          log "@sendinblue_client.create_update_user({ email: '#{contact[:email]}', ...})"
        else
          @sendinblue_client.create_update_user(contact)
        end
      end
    end

    # Extract user information from intercom stale users/leads and create a contact list in the format required by SendinBlue.
    def contacts_to_upload(segment)
      segment_users = intercom_segment_users(segment)
      log "There are #{segment_users.count} contacts to upload..."

      segment_users.map do |intercom_user|
        next if intercom_user.email.blank?

        {
          email: intercom_user.email,
          listid: [list_id(SEGMENTS_TO_LIST[segment])],
          attributes: sendinblue_attributes(intercom_user)
        }
      end - [nil]
    end

    def sendinblue_attributes(user)
      name_attribute(user)
        .merge(phone_attribute(user))
        .merge(education_attributes(user))
        .merge(location_attributes(user))
    end

    def name_attribute(user)
      user.name.present? ? { NAME: user.name } : {}
    end

    def phone_attribute(user)
      if user.custom_attributes['phone'].present?
        { PHONE: user.custom_attributes['phone'] }
      elsif user.phone.present?
        { PHONE: user.phone }
      else
        {}
      end
    end

    def education_attributes(user)
      education_attributes = {}
      education_attributes[:COLLEGE] = user.custom_attributes['college'] if user.custom_attributes['college'].present?
      education_attributes[:UNIVERSITY] = user.custom_attributes['university'] if user.custom_attributes['university'].present?
      education_attributes
    end

    def location_attributes(user)
      location_attributes = {}
      location_attributes[:CITY] = user.location_data.city_name if user.location_data.city_name.present?
      location_attributes[:STATE] = user.location_data.region_name if user.location_data.region_name.present?
      location_attributes
    end

    def delete_from_intercom(segment)
      segment_users = intercom_segment_users(segment)
      return if segment_users.blank?
      if @mock
        log "@intercom_client.users.submit_bulk_job(delete_items: [#{segment_users.count} users])"
      else
        # Intercom API supports bulk jobs for only maximum 100 items per request. Split users to chunks of 100.
        segment_users.each_slice(100).each do |segment_users_chunk|
          @intercom_client.users.submit_bulk_job(delete_items: segment_users_chunk)
        end
      end
    end

    def intercom_segment_users(segment)
      @intercom_segment_users ||= Hash.new do |hash, key|
        hash[key] = @intercom_client.users.find_all(segment_id: segment_id(key)).to_a
      end

      @intercom_segment_users[segment]
    end

    def segment_id(segment_name)
      @intercom_segments ||= @intercom_client.segments.all
      @intercom_segments.find { |segment| segment.name == segment_name }&.id
    end

    def list_id(list_name)
      @sendinblue_lists ||= @sendinblue_client.get_lists({})
      @sendinblue_lists['data'].detect { |list| list['name'] == list_name }['id']
    end
  end
end