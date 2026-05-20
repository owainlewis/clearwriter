class Document < ApplicationRecord
  PUBLIC_TOKEN_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".chars.freeze
  PUBLIC_TOKEN_LENGTH = 22
  MAX_BODY_BYTES = 5.megabytes

  belongs_to :user

  before_validation :assign_public_token, on: :create

  validates :public_token, presence: true, uniqueness: true
  validate :body_within_byte_limit

  scope :public_docs, -> { where(is_public: true) }
  scope :with_tag, ->(tag) { where("tags @> ARRAY[?]::varchar[]", tag) }
  scope :updated_since, ->(time) { where("updated_at >= ?", time) }

  def to_param
    public_token
  end

  # Virtual attribute so the edit-page chip input can be a single text field.
  # Splits on comma, trims, lowercases, dedupes.
  def tags_text
    tags.join(", ")
  end

  def tags_text=(value)
    self.tags = value.to_s
      .split(",")
      .map { |t| t.strip.downcase }
      .reject(&:blank?)
      .uniq
  end

  private

  def assign_public_token
    return if public_token.present?

    loop do
      candidate = Array.new(PUBLIC_TOKEN_LENGTH) { PUBLIC_TOKEN_ALPHABET.sample(random: SecureRandom) }.join
      next if Document.exists?(public_token: candidate)

      self.public_token = candidate
      break
    end
  end

  def body_within_byte_limit
    return if body.nil?
    return if body.bytesize <= MAX_BODY_BYTES

    errors.add(:body, "must be at most #{MAX_BODY_BYTES / 1.megabyte} MB")
  end
end
