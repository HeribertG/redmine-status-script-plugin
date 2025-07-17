Redmine::Plugin.register :redmine_status_scripts do
  name 'Redmine Status Scripts Plugin'
  author 'projektfokus'
  description 'Führt Skripte bei Status-Wechseln aus'
  version '1.0.1'
  url 'https://projektfokus.ch'
  author_url 'https://projektfokus.ch'

  
  menu :admin_menu, :status_scripts, 
       { controller: 'status_scripts', action: 'index' }, 
       caption: 'Status Scripts',
       html: { class: 'icon icon-package' }
end

class StatusScriptHooks < Redmine::Hook::Listener
  def controller_issues_edit_after_save(context = {})
    issue = context[:issue]
    journal = context[:journal]
    
    Rails.logger.info "Status Script Hook: Issue ##{issue.id} updated"
    
    if journal && journal.details.any? { |detail| detail.property == 'attr' && detail.prop_key == 'status_id' }
      Rails.logger.info "Status Script Hook: Status changed detected"
      execute_status_script(issue, journal)
    else
      Rails.logger.info "Status Script Hook: No status change detected"
    end
  end

  private

  def execute_status_script(issue, journal)
    status_detail = journal.details.find { |d| d.property == 'attr' && d.prop_key == 'status_id' }
    return unless status_detail
    
    old_status_id = status_detail.old_value.to_i
    new_status_id = status_detail.value.to_i
    
    Rails.logger.info "Status Script: Transition #{old_status_id} -> #{new_status_id}"
    
    config = StatusScriptConfig.find_for_transition(old_status_id, new_status_id, issue.project_id)
    
    unless config
      Rails.logger.info "Status Script: No config found for transition #{old_status_id} -> #{new_status_id}"
      return
    end
    
    Rails.logger.info "Status Script: Found config '#{config.name}'"
    
    log = StatusScriptLog.create!(
      issue_id: issue.id,
      from_status_id: old_status_id,
      to_status_id: new_status_id,
      status_script_config_id: config.id,
      executed_at: Time.current,
      started_at: Time.current,
      success: false
    )
    
    begin
      Rails.logger.info "Status Script: Executing #{config.script_type} script"
      output = execute_script(issue, config, old_status_id, new_status_id)
      
      log.update!(
        success: true,
        output: output,
        finished_at: Time.current
      )
      
      Rails.logger.info "Status Script: Executed successfully"
      
    rescue StandardError => e
      log.update!(
        success: false,
        error_message: e.message,
        finished_at: Time.current
      )
      
      Rails.logger.error "Status Script Error: #{e.message}"
    end
  end

  def execute_script(issue, config, old_status_id, new_status_id)
    script_params = {
      issue_id: issue.id,
      issue_subject: issue.subject,
      project_id: issue.project_id,
      project_name: issue.project.name,
      old_status_id: old_status_id,
      old_status_name: IssueStatus.find_by(id: old_status_id)&.name,
      new_status_id: new_status_id,
      new_status_name: IssueStatus.find_by(id: new_status_id)&.name,
      assignee_id: issue.assigned_to_id,
      assignee_name: issue.assigned_to&.name,
      author_id: issue.author_id,
      author_name: issue.author.name,
      created_on: issue.created_on.iso8601,
      updated_on: issue.updated_on.iso8601
    }
    
    case config.script_type
    when 'shell'
      execute_shell_script_normalized(config.script_content, script_params, config.timeout)
    else
      "Script type #{config.script_type} not implemented yet"
    end
  end

  def execute_shell_script_normalized(script_content, params, timeout = 30)
    return "No script content" unless script_content.present?
    
    Rails.logger.info "Status Script: Executing shell script (normalized)"
    
    # Zeilenendezeichen normalisieren
    normalized_content = script_content.gsub(/\r\n/, "\n").gsub(/\r/, "\n")
    
    # Überflüssige Leerzeichen am Zeilenende entfernen
    normalized_content = normalized_content.split("\n").map do |line|
      line.rstrip
    end.join("\n")
    
    # Sicherstellen, dass das Script mit einem Newline endet
    normalized_content += "\n" unless normalized_content.end_with?("\n")
    
    # Umgebungsvariablen setzen
    env = params.transform_keys { |k| "REDMINE_#{k.to_s.upcase}" }
                .transform_values { |v| normalize_env_value(v.to_s) }
    
    # Temporäres Script-File erstellen
    script_file = Tempfile.new(['status_script', '.sh'], '/tmp')
    
    begin
      script_file.write(normalized_content)
      script_file.close
      File.chmod(0755, script_file.path)
      
      Rails.logger.info "Status Script: Script file created at #{script_file.path}"
      
      output_file = script_file.path + '.out'
      error_file = script_file.path + '.err'
      
      Rails.logger.info "Status Script: Running script #{script_file.path}"
      
      pid = Process.spawn(env, script_file.path, out: output_file, err: error_file)
      
      begin
        Timeout.timeout(timeout) do
          Process.wait(pid)
        end
      rescue Timeout::Error
        Process.kill('TERM', pid) rescue nil
        raise "Script timeout after #{timeout} seconds"
      end
      
      output = ""
      if File.exist?(output_file)
        output = File.read(output_file)
        output = normalize_output(output)
      end
      
      if File.exist?(error_file)
        error_content = File.read(error_file)
        if error_content.present?
          error_content = normalize_output(error_content)
          output += "\nSTDERR:\n#{error_content}"
        end
      end
      
      Rails.logger.info "Status Script: Shell script completed successfully"
      
      output.presence || "Script executed successfully"
      
    rescue => e
      Rails.logger.error "Status Script: Shell script failed: #{e.message}"
      raise e
    ensure
      script_file&.unlink
      [output_file, error_file].each { |f| File.delete(f) if f && File.exist?(f) }
    end
  end

  private

  def normalize_env_value(value)
    value.to_s.gsub(/\r\n/, ' ').gsub(/[\r\n]/, ' ').strip
  end

  def normalize_output(output)
    return "" if output.blank?
    output.gsub(/\r\n/, "\n").gsub(/\r/, "\n")
  end
end

Rails.logger.info "Status Script Plugin: Loaded successfully with normalized hook (v1.0.1)"