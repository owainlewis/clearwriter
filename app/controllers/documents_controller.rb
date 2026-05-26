class DocumentsController < ApplicationController
  before_action :set_document, only: %i[edit update destroy preview]

  def index
    scope = Current.user.documents.order(updated_at: :desc)

    @tag = params[:tag].presence
    @since = parse_since(params[:since])

    scope = scope.with_tag(@tag) if @tag
    scope = scope.updated_since(@since) if @since

    @documents = scope
  end

  def create
    document = Current.user.documents.create!
    redirect_to edit_document_path(document)
  end

  def edit
  end

  def update
    @document.update!(document_params)
    head :no_content
  end

  def destroy
    @document.destroy!
    redirect_to documents_path, notice: "Document deleted."
  end

  # POST /documents/:id/preview — renders the supplied body (or saved body
  # if none given) to HTML. Used by the edit-page ⌘R toggle so the preview
  # reflects unsaved changes without writing them.
  def preview
    body = params[:body].presence || @document.body
    render html: PairMarkdown.render(body), layout: false
  end

  private

  def set_document
    @document = Current.user.documents.find_by!(public_token: params[:id])
  end

  def document_params
    # title is derived from the body's first heading on save (see Document#derive_title_from_body),
    # so it isn't accepted from the form.
    params.expect(document: [ :body, :tags_text ])
  end

  # Accepts "7d", "30d", "all", or nil. Defaults to 7 days (the Recent view)
  # when the param is absent. Returns nil to mean "no filter."
  def parse_since(value)
    case value
    when nil, "" then 7.days.ago
    when "all" then nil
    when /\A(\d+)d\z/ then Regexp.last_match(1).to_i.days.ago
    else 7.days.ago
    end
  end
end
