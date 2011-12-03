class EditableContentsController < ApplicationController
  before_filter :find_editable_content, :only => [:show, :edit, :update, :destroy]
  
  def index
    @editable_contents = EditableContent.order('title ASC')
  end
  
  def new
    @editable_content = EditableContent.new
  end

  def create
    @editable_content = EditableContent.create!(params[:editable_content])
    redirect_to @editable_content
  rescue ActiveRecord::RecordInvalid
    render :action => :new
  end
  
  def show
  end
  
  def edit
  end
    
  def update
    @editable_content.update_attributes!(params[:editable_content])
    redirect_to @editable_content
  rescue ActiveRecord::RecordInvalid
    render :action => :new
  end
  
  def destroy
    raise "Cannot Destroy protected system content" if @editable_content.system?
    @editable_content.destroy
    redirect_to editable_contents_path
  rescue => e
    render :action => :show, :alert => e.message
  end
  
  private

  def find_editable_content
    @editable_content = EditableContent.find(params[:id])
  end
end
