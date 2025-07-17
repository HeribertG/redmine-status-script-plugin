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
  
  # Neue Validierungen für normalisierte Eingaben
  validate :validate_script_content_format
  validate :validate_webhook_url_format

  scope :enabled, -> { where(enabled: true) }
  scope :for_project, ->(project) { where(project: [nil, project]) }
  scope :global, -> { where(project_id: nil) }

  # Callback um Eingaben zu normalisieren bevor sie gespeichert werden
  before_save :normalize_content_fields

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
                             .order('from_status_id DESC, id DESC')  # MySQL 5.7 kompatibel
                             .first
      
      if project_config
        Rails.logger.info "Found project-specific config: #{project_config.name}"
        return project_config
      end
    end
    
    # Dann globale Konfiguration
    global_config = configs.where(project_id: nil)
                          .where('from_status_id IS NULL OR from_status_id = ?', from_status_id)
                          .order('from_status_id DESC, id DESC')  # MySQL 5.7 kompatibel
                          .first
    
    if global_config
      Rails.logger.info "Found global config: #{global_config.name}"
    else
      Rails.logger.info "No config found for transition"
    end
    
    global_config
  end

  # Neue Methode für normalisierte Script-Inhalte
  def normalized_script_content
    return nil unless script_content.present?
    normalize_script_content(script_content)
  end

  # Neue Methode für normalisierte Webhook-URL
  def normalized_webhook_url
    return nil unless webhook_url.present?
    normalize_webhook_url(webhook_url)
  end

  private

  def normalize_content_fields
    # Script-Inhalt normalisieren
    if script_content.present?
      self.script_content = normalize_script_content(script_content)
    end
    
    # Webhook-URL normalisieren  
    if webhook_url.present?
      self.webhook_url = normalize_webhook_url(webhook_url)
    end
    
    # Name und Beschreibung normalisieren
    if name.present?
      self.name = normalize_text_field(name)
    end
    
    if description.present?
      self.description = normalize_text_field(description)
    end
    
    # Umgebungsvariablen normalisieren
    if environment_variables.present?
      self.environment_variables = normalize_environment_variables(environment_variables)
    end
  end

  def normalize_script_content(content)
    return content if content.blank?
    
    case script_type
    when 'shell'
      normalize_shell_script(content)
    when 'ruby'  
      normalize_ruby_script(content)
    else
      content
    end
  end

  def normalize_shell_script(content)
    # Shell-Skripte: Zeilenendezeichen normalisieren
    normalized = content.gsub(/\r\n/, "\n").gsub(/\r/, "\n")
    
    # Überflüssige Leerzeichen am Zeilenende entfernen, aber Einrückung beibehalten
    lines = normalized.split("\n").map(&:rstrip)
    
    # Leere Zeilen am Ende entfernen
    while lines.last&.empty?
      lines.pop
    end
    
    # Mit einem Newline abschließen
    lines.join("\n") + "\n"
  end

  def normalize_ruby_script(content)
    # Ruby-Code: Zeilenendezeichen normalisieren aber Struktur beibehalten
    content.gsub(/\r\n/, "\n").gsub(/\r/, "\n")
  end

  def normalize_webhook_url(url)
    # URL trimmen und problematische Zeichen entfernen
    url.strip.gsub(/[\r\n\t]/, '')
  end

  def normalize_text_field(text)
    # Normale Textfelder: Nur Whitespace normalisieren
    text.strip.gsub(/[\r\n]/, ' ').squeeze(' ')
  end

  def normalize_environment_variables(env_vars)
    return env_vars if env_vars.blank?
    
    # Umgebungsvariablen Zeile für Zeile normalisieren
    lines = env_vars.split(/\r?\n/).map do |line|
      line.strip
    end.reject(&:empty?)
    
    lines.join("\n")
  end

  def validate_script_content_format
    return unless script_content.present? && content_required?
    
    case script_type
    when 'shell'
      validate_shell_script_format
    when 'ruby'
      validate_ruby_script_format
    end
  end

  def validate_shell_script_format
    # Prüfe auf häufige Shell-Script-Probleme
    if script_content.include?("\0")
      errors.add(:script_content, 'darf keine Null-Bytes enthalten')
    end
    
    # Warne vor potentiell problematischen Zeichen
    if script_content.match?(/[^\x00-\x7F]/)
      Rails.logger.warn "Status Script Config #{id}: Shell script contains non-ASCII characters"
    end
  end

  def validate_ruby_script_format
    # Basis-Syntax-Check für Ruby-Code
    begin
      # Nur eine grundlegende Syntax-Prüfung
      RubyVM::InstructionSequence.compile(script_content)
    rescue SyntaxError => e
      errors.add(:script_content, "hat eine ungültige Ruby-Syntax: #{e.message}")
    end
  end

  def validate_webhook_url_format
    return unless webhook_url.present? && webhook_type?
    
    begin
      uri = URI.parse(webhook_url)
      unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        errors.add(:webhook_url, 'muss eine gültige HTTP/HTTPS-URL sein')
      end
    rescue URI::InvalidURIError
      errors.add(:webhook_url, 'ist keine gültige URL')
    end
    
    # Prüfe auf problematische Zeichen
    if webhook_url.match?(/[\r\n\t]/)
      errors.add(:webhook_url, 'darf keine Zeilenwechsel oder Tabs enthalten')
    end
  end
end