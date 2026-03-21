# frozen_string_literal: true

class DocumentsController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  before_action :set_document, only: %i[show destroy]

  def index
    @q = params[:q].to_s.strip
    @documents = current_user.documents.order(:title)
    @documents = @documents.where("title ILIKE ?", "%#{@q}%") if @q.present?
  end

  def show; end

  def new
    @document = current_user.documents.new
  end

  def create
    @document = current_user.documents.new(document_params)

    if @document.save
      redirect_to @document, notice: "Document was successfully uploaded."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @document.destroy
    redirect_to documents_url, notice: "Document was successfully deleted."
  end

  private

  def set_document
    @document = current_user.documents.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :file)
  end
end
