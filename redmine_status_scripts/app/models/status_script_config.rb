# plugins/redmine_status_scripts/app/models/status_script_config.rb
class StatusScriptConfig < ActiveRecord::Base
  belongs_to :from_status, class_name: 'IssueStatus', optional: true
  belongs_to :to_status, class_name: 'IssueStatus'
  belongs_to :project, optional: true
  has_many :status_script_logs, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validates :to_status_id, presence: true
  validates :script_type, inclusion: { in: %w[shell webhook ruby] }
  validates :script_content, presence: true, if: :content_required?
  validates :webhook_url, presence: true, if: :webhook_type?

  scope :enabled, -> { where(enabled: true) }
  scope :for_project, ->(project) { where(project: [nil, project]) }
  scope :global, -> { where(project_id: nil) }

  def enabled?
    enabled
  end

  def content_required?
    %w[shell ruby].include?(script_type)
  end

  def webhook_type?
    script_type == 'webhook'
  end

  def self.find_for_transition(from_status_id, to_status_id, project_id = nil)
    Rails.logger.info "Looking for script config: #{from_status_id} -> #{to_status_id}, project: #{project_id}"
    
    configs = enabled.where(to_status_id: to_status_id)
    Rails.logger.info "Found #{configs.count} configs for target status #{to_status_id}"
    
    # Erst projektspezifische Konfiguration suchen
    if project_id
      project_config = configs.where(project_id: project_id)
                             .where('from_status_id IS NULL OR from_status_id = ?', from_status_id)
                             .order(Arel.sql('from_status_id DESC NULLS LAST'))
                             .first
      
      if project_config
        Rails.logger.info "Found project-specific config: #{project_config.name}"
        return project_config
      end
    end
    
    # Dann globale Konfiguration
    global_config = configs.where(project_id: nil)
                          .where('from_status_id IS NULL OR from_status_id = ?', from_status_id)
                          .order(Arel.sql('from_status_id DESC NULLS LAST'))
                          .first
    
    if global_config
      Rails.logger.info "Found global config: #{global_config.name}"
    else
      Rails.logger.info "No config found for transition"
    end
    
    global_config
  end
end

# plugins/redmine_status_scripts/app/models/status_script_log.rb
class StatusScriptLog < ActiveRecord::Base
  belongs_to :issue
  belongs_to :from_status, class_name: 'IssueStatus', optional: true
  belongs_to :to_status, class_name: 'IssueStatus'
  belongs_to :status_script_config, optional: true

  validates :issue_id, presence: true
  validates :to_status_id, presence: true
  validates :executed_at, presence: true

  scope :recent, -> { order(executed_at: :desc) }
  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }

  def transition_description
    from_name = from_status&.name || 'Unbekannt'
    to_name = to_status.name
    "#{from_name} → #{to_name}"
  end

  def execution_summary
    if success?
      "Erfolgreich"
    else
      "Fehlgeschlagen" + (error_message.present? ? ": #{error_message}" : "")
    end
  end

  def duration_in_ms
    return nil unless started_at && finished_at
    ((finished_at - started_at) * 1000).round(2)
  end
end