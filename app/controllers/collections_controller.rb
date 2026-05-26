class CollectionsController < ApplicationController
  before_action :set_collection, only: %i[show update destroy]

  def index
    @collections = Current.user.collections.ordered
  end

  def show
    @documents = @collection.documents
    # Documents to add are fetched on demand by the search picker (see
    # CollectionDocumentsController#search), so they aren't loaded here.
  end

  def create
    collection = Current.user.collections.create!(collection_params)
    redirect_to collection_path(collection)
  end

  def update
    @collection.update!(collection_params)
    redirect_to collection_path(@collection), notice: "Collection renamed."
  end

  def destroy
    @collection.destroy!
    redirect_to collections_path, notice: "Collection deleted."
  end

  private

  def set_collection
    @collection = Current.user.collections.find_by!(public_token: params[:id])
  end

  def collection_params
    params.expect(collection: [ :name ])
  end
end
