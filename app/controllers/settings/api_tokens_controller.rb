class Settings::ApiTokensController < ApplicationController
  def index
    @api_tokens = Current.user.api_tokens.order(created_at: :desc)
    @new_token = flash[:raw_token]  # shown once after creation
  end

  def create
    record = ApiToken.create_for_user!(Current.user, name: params[:name].to_s.strip)
    redirect_to settings_api_tokens_path, flash: { raw_token: record.raw_token, notice: "Token created — copy it now; you won't see it again." }
  end

  def destroy
    token = Current.user.api_tokens.find(params[:id])
    token.destroy!
    redirect_to settings_api_tokens_path, notice: "Token revoked."
  end
end
