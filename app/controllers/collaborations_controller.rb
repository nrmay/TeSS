class CollaborationsController < ApplicationController

  before_filter :get_resource
  before_filter :authorize_resource

  respond_to :json

  def create
    @collaboration = @resource.collaborations.create(Collaboration.new(user: params[:user_id]))

    respond_with(@collaboration)
  end

  def destroy
    Collaboration.find(params[:id]).destroy
    head :no_content
  end

  def index
    @collaborations = @resource.collaborations

    respond_with(@collaborations)
  end

  private

  # This is really awkward, but there isn't a better way of doing it.
  # Scan the params for the ID of the parent resource, e.g. workflow_id, material_id etc.
  def get_resource
    params.each do |name, value|
      if name.end_with?('_id')
        c = name.chomp('_id').classify.constantize rescue NameError
        if c.method_defined?(:collaborations)
          @resource = c.friendly.find(value)
        end
      end
    end
  end

  def authorize_resource
    authorize @resource, :manage?
  end

end
