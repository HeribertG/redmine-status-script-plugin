class StatusScriptsController < ApplicationController
  before_action :require_admin
  before_action :find_status_script_config, only: [:show, :edit, :update, :destroy, :toggle]

  def index
    @status_script_configs = StatusScriptConfig.includes(:from_status, :to_status, :project)
                                               .order(:name)
    @status_script_logs = StatusScriptLog.includes(:issue, :from_status, :to_status)
                                         .recent
                                         .limit(10)
  end

  def show
    @logs = @status_script_config.status_script_logs
                                 .includes(:issue, :from_status, :to_status)
                                 .recent
                                 .limit(50)
  end

  def new
    @status_script_config = StatusScriptConfig.new
    @issue_statuses = IssueStatus.sorted
    @projects = Project.active.sorted
  end

  def create
    @status_script_config = StatusScriptConfig.new(status_script_config_params)
    
    if @status_script_config.save
      flash[:notice] = 'Status Script wurde erfolgreich erstellt.'
      redirect_to status_scripts_path
    else
      @issue_statuses = IssueStatus.sorted
      @projects = Project.active.sorted
      render :new
    end
  end

  def edit
    @issue_statuses = IssueStatus.sorted
    @projects = Project.active.sorted
  end

  def update
    if @status_script_config.update(status_script_config_params)
      flash[:notice] = 'Status Script wurde erfolgreich aktualisiert.'
      redirect_to status_script_path(@status_script_config)
    else
      @issue_statuses = IssueStatus.sorted
      @projects = Project.active.sorted
      render :edit
    end
  end

  def destroy
    @status_script_config.destroy
    flash[:notice] = 'Status Script wurde gelöscht.'
    redirect_to status_scripts_path
  end

  def toggle
    @status_script_config.update(enabled: !@status_script_config.enabled)
    status_text = @status_script_config.enabled? ? 'aktiviert' : 'deaktiviert'
    flash[:notice] = "Status Script wurde #{status_text}."
    redirect_to status_scripts_path
  end

  def logs
    @logs = StatusScriptLog.includes(:issue, :from_status, :to_status, :status_script_config)
                           .recent
                           .limit(100)
    
    # Einfache Filter
    if params[:success].present?
      @logs = @logs.where(success: params[:success] == 'true')
    end
    
    if params[:issue_id].present?
      @logs = @logs.where(issue_id: params[:issue_id])
    end
  end

  private

  def find_status_script_config
    @status_script_config = StatusScriptConfig.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def status_script_config_params
    params.require(:status_script_config).permit(
      :name, :description, :from_status_id, :to_status_id, :project_id,
      :script_type, :script_content, :webhook_url, :enabled, :timeout
    )
  end
end