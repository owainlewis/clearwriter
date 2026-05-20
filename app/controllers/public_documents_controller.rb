class PublicDocumentsController < ApplicationController
  allow_unauthenticated_access only: %i[show]

  # GET /d/:token         → rendered HTML
  # GET /d/:token.md      → raw markdown (text/markdown)
  #
  # Both routes return 404 (not 403) when the document is not public,
  # so existence is never leaked.
  def show
    @document = Document.public_docs.find_by!(public_token: params[:token])

    respond_to do |format|
      format.html
      format.md { render plain: @document.body, content_type: "text/markdown; charset=utf-8" }
    end
  end
end
