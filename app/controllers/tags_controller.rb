class TagsController < ApplicationController
  # GET /tags — list distinct tags for the current user with document counts.
  def index
    @tag_counts = Current.user.documents
      .where("array_length(tags, 1) > 0")
      .pluck(:tags)
      .flatten
      .tally
      .sort_by { |_, count| [ -count, _ ] }
  end
end
