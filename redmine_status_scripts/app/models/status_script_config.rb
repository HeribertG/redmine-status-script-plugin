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
    configs = enabled.where(to_status_id: to_status_id)
    
    # Erst projektspezifische Konfiguration suchen
    if project_id
      project_config = configs.where(project_id: project_id)
                             .where(from_status_id: [nil, from_status_id])
                             .order('from_status_id DESC NULLS LAST')
                             .first
      return project_config if project_config
    end
    
    # Dann globale Konfiguration
    configs.where(project_id: nil)
           .where(from_status_id: [nil, from_status_id])
           .order('from_status_id DESC NULLS LAST')
           .first
  end
end