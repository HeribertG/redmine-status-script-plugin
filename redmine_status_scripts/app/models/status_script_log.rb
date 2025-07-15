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
end