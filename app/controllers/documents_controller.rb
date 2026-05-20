class DocumentsController < ApplicationController
  before_action :set_document, only: %i[edit update destroy preview]

  def index
    @documents = Current.user.documents.order(updated_at: :desc)
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
    render html: ClearwriterMarkdown.render(body), layout: false
  end

  private

  def set_document
    @document = Current.user.documents.find_by!(public_token: params[:id])
  end

  def document_params
    params.expect(document: [ :title, :body, { tags: [] } ])
  end
end
