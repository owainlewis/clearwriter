class Document < ApplicationRecord
  include HasPublicToken

  MAX_BODY_BYTES = 5.megabytes

  TITLE_FALLBACK_LIMIT = 80

  belongs_to :user
  has_many :collection_documents, dependent: :destroy
  has_many :collections, through: :collection_documents
  has_many :task_documents, dependent: :destroy
  has_many :tasks, through: :task_documents

  before_save :derive_title_from_body

  validate :body_within_byte_limit

  scope :public_docs, -> { where(is_public: true) }
  scope :with_tag, ->(tag) { where("tags @> ARRAY[?]::varchar[]", tag) }
  scope :updated_since, ->(time) { where("updated_at >= ?", time) }

  # Substring search over title and body. ILIKE is the deliberate v1 choice:
  # no migration, good enough for an agent finding a doc by a phrase it
  # remembers. Upgrade path is a tsvector column + GIN index if ranking matters.
  def self.search(query)
    pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where("title ILIKE :q OR body ILIKE :q", q: pattern)
  end

  # Virtual attribute so the edit-page chip input can be a single text field.
  # Splits on comma, trims, lowercases, dedupes.
  def tags_text
    tags.join(", ")
  end

  def tags_text=(value)
    self.tags = value.to_s
      .split(",")
      .map { |t| t.strip.downcase.delete_prefix("#") }
      .reject(&:blank?)
      .uniq
  end

  private

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
