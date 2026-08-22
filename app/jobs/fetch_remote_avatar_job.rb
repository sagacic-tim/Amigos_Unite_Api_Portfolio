# app/jobs/fetch_remote_avatar_job.rb
require "open-uri"

class FetchRemoteAvatarJob < ApplicationJob
  queue_as :default
  retry_on OpenURI::HTTPError, Timeout::Error, SocketError, URI::InvalidURIError,
           wait: 10.seconds, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(amigo_id, source:, url: nil)
    amigo = Amigo.find(amigo_id)
    return if amigo.avatar_source == "upload"

    ok =
      case source
      when "gravatar" then amigo.attach_gravatar
      when "url"      then (u = url.presence || amigo.avatar_remote_url) && amigo.attach_remote_image(u)
      else false
      end

    if ok
      amigo.send(:process_avatar)
      amigo.touch(:avatar_synced_at)
    elsif !amigo.avatar.attached?
      amigo.attach_default_avatar
    end
  end
end
