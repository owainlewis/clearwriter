# Gives a model a non-enumerable public identifier used as its URL :id.
# Base58 alphabet (no 0/O/l/I) so tokens are unambiguous when read aloud.
# Document and Collection both use this; to_param makes routes use the token.
module HasPublicToken
  extend ActiveSupport::Concern

  PUBLIC_TOKEN_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".chars.freeze
  PUBLIC_TOKEN_LENGTH = 22

  included do
    before_validation :assign_public_token, on: :create
    validates :public_token, presence: true, uniqueness: true
  end

  def to_param
    public_token
  end

  private

  def assign_public_token
    return if public_token.present?

    loop do
      candidate = Array.new(PUBLIC_TOKEN_LENGTH) { PUBLIC_TOKEN_ALPHABET.sample(random: SecureRandom) }.join
      next if self.class.exists?(public_token: candidate)

      self.public_token = candidate
      break
    end
  end
end
