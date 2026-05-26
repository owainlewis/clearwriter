require "digest"

class ApiToken < ApplicationRecord
  PREFIX = "pair_"
  RANDOM_LENGTH = 24

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true

  attr_accessor :raw_token

  # Creates a new token for the user. The raw string is returned in
  # `record.raw_token` exactly once — only `token_digest` is persisted.
  def self.create_for_user!(user, name: "")
    raw = "#{PREFIX}#{SecureRandom.urlsafe_base64(RANDOM_LENGTH)}"
    record = create!(user: user, name: name, token_digest: digest_for(raw))
    record.raw_token = raw
    record
  end

  def self.authenticate(raw)
    return nil if raw.blank?

    find_by(token_digest: digest_for(raw))
  end

  def self.digest_for(raw)
    Digest::SHA256.hexdigest(raw.to_s)
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end
end
