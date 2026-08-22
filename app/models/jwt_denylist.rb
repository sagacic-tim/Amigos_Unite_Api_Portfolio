# app/models/jwt_denylist.rb
class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist
  self.table_name = 'jwt_denylist'

  validates :jti, presence: true, uniqueness: true

  def self.jwt_revoked?(payload, amigo)
    Rails.logger.debug "JwtDenylist - Checking revoked jti=#{payload['jti']} exp=#{payload['exp']}"
    exists?(jti: payload['jti'])
  end
  
  def self.revoke_jwt(payload, amigo)
    Rails.logger.debug "JwtDenylist - Checking revoked jti=#{payload['jti']} exp=#{payload['exp']}"
    jti = payload['jti']
    exp = payload['exp']
  
    if jti && exp
      create!(jti: jti, exp: Time.at(exp))
    else
      Rails.logger.error "JwtDenylist - Missing jti or exp; keys=#{payload.keys.join(',')}"
      raise "Invalid payload: missing jti or exp"
    end
  end
end
