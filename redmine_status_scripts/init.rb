# plugins/redmine_status_scripts/init.rb
Redmine::Plugin.register :redmine_status_scripts do
  name 'Redmine Status Scripts Plugin'
  author 'projektfokus'
  description 'Führt Skripte bei Status-Wechseln aus'
  version '1.0.0'
  url 'https://projektfokus.ch'
  author_url 'https://projektfokus.ch'

  # Plugin-Einstellungen
  settings default: {
    'script_path' => '/path/to/scripts',
    'enable_logging' => true,
    'timeout' => 30
  }, partial: 'settings/status_scripts'

  # Menü-Eintrag für Administration
  menu :admin_menu, :status_scripts, 
       { controller: 'status_scripts', action: 'index' }, 
       caption: 'Status Scripts',
       html: { class: 'icon icon-package' }
end

# Hook-Klasse definieren
class StatusScriptHooks < Redmine::Hook::ViewListener
  def controller_issues_edit_after_save(context = {})
    issue = context[:issue]
    
    # Prüfen ob sich der Status geändert hat
    if issue.status_id_changed?
      execute_status_script(issue)
    end
  end

  private

  def execute_status_script(issue)
    old_status_id = issue.status_id_was
    new_status_id = issue.status_id
    
    # Script-Konfiguration suchen
    config = StatusScriptConfig.find_for_transition(
      old_status_id, 
      new_status_id, 
      issue.project_id
    )
    
    return unless config
    
    begin
      # Script ausführen
      execute_script(issue, config)
      
      # Log-Eintrag erstellen
      log_execution(issue, config, true)
      
    rescue StandardError => e
      Rails.logger.error "Status Script Error: #{e.message}"
      log_execution(issue, config, false, e.message)
    end
  end

  def execute_script(issue, config)
    script_params = build_script_params(issue)
    
    case config.script_type
    when 'shell'
      execute_shell_script(config.script_content, script_params)
    when 'webhook'
      execute_webhook(config.webhook_url, script_params)
    when 'ruby'
      execute_ruby_code(config.script_content, script_params)
    end
  end

  def build_script_params(issue)
    {
      issue_id: issue.id,
      issue_subject: issue.subject,
      project_id: issue.project_id,
      project_name: issue.project.name,
      old_status_id: issue.status_id_was,
      old_status_name: IssueStatus.find_by(id: issue.status_id_was)&.name,
      new_status_id: issue.status_id,
      new_status_name: issue.status.name,
      assignee_id: issue.assigned_to_id,
      assignee_name: issue.assigned_to&.name,
      author_id: issue.author_id,
      author_name: issue.author.name,
      created_on: issue.created_on.iso8601,
      updated_on: issue.updated_on.iso8601
    }
  end

  def execute_shell_script(script_content, params)
    return unless script_content.present?
    
    # Umgebungsvariablen setzen
    env = params.transform_keys { |k| "REDMINE_#{k.to_s.upcase}" }
                .transform_values { |v| v.to_s }
    
    # Temporäres Script-File erstellen
    script_file = Tempfile.new(['status_script', '.sh'])
    script_file.write(script_content)
    script_file.close
    
    # Ausführbar machen
    File.chmod(0755, script_file.path)
    
    # Script ausführen mit Timeout
    timeout = Setting.plugin_redmine_status_scripts['timeout']&.to_i || 30
    
    pid = Process.spawn(env, script_file.path)
    begin
      Timeout.timeout(timeout) do
        Process.wait(pid)
      end
    rescue Timeout::Error
      Process.kill('TERM', pid)
      raise "Script timeout after #{timeout} seconds"
    end
    
  ensure
    script_file&.unlink
  end

  def execute_webhook(url, params)
    return unless url.present?
    
    require 'net/http'
    require 'json'
    
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = params.to_json
    
    timeout = Setting.plugin_redmine_status_scripts['timeout']&.to_i || 30
    http.read_timeout = timeout
    
    response = http.request(request)
    
    unless response.code.start_with?('2')
      raise "Webhook failed with status #{response.code}: #{response.body}"
    end
  end

  def execute_ruby_code(code, params)
    return unless code.present?
    
    # Sicheren Kontext erstellen
    binding_context = Object.new
    
    # Parameter als Instanzvariablen setzen
    params.each do |key, value|
      binding_context.instance_variable_set("@#{key}", value)
    end
    
    # Code ausführen
    binding_context.instance_eval(code)
  end

  def log_execution(issue, config, success, error_message = nil)
    return unless Setting.plugin_redmine_status_scripts['enable_logging']
    
    StatusScriptLog.create!(
      issue_id: issue.id,
      from_status_id: issue.status_id_was,
      to_status_id: issue.status_id,
      status_script_config_id: config.id,
      executed_at: Time.current,
      success: success,
      error_message: error_message
    )
  rescue StandardError => e
    Rails.logger.error "Failed to log script execution: #{e.message}"
  end
end