class Document < ApplicationRecord
  PUBLIC_TOKEN_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".chars.freeze
  PUBLIC_TOKEN_LENGTH = 22
  MAX_BODY_BYTES = 5.megabytes

  TITLE_FALLBACK_LIMIT = 80

  belongs_to :user

  before_validation :assign_public_token, on: :create
  before_save :derive_title_from_body

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

  # iA Writer style: the document title IS the first H1 (or first non-empty
  # line if no H1 exists). The user never edits title directly — it's derived
  # on every save so the list view and metadata stay in sync with the body.
  def derive_title_from_body
    self.title = compute_title_from(body)
  end

  def compute_title_from(text)
    return "" if text.blank?

    text.each_line do |line|
      stripped = line.strip
      next if stripped.empty?

      if stripped.start_with?("# ")
        return stripped.sub(/\A#+\s*/, "").sub(/\s*#*\s*\z/, "").strip
      end

      truncated = stripped.length > TITLE_FALLBACK_LIMIT ?
        stripped[0, TITLE_FALLBACK_LIMIT - 1] + "…" :
        stripped
      return truncated
    end

    ""
  end
end
