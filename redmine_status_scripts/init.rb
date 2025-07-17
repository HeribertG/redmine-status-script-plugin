Redmine::Plugin.register :redmine_status_scripts do
  name 'Redmine Status Scripts Plugin'
  author 'projektfokus'
  description 'Führt Skripte bei Status-Wechseln aus'
  version '1.0.0'
  url 'https://projektfokus.ch'
  author_url 'https://projektfokus.ch'

  settings default: {
    'script_path' => '/path/to/scripts',
    'enable_logging' => true,
    'timeout' => 30
  }, partial: 'settings/status_scripts'

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
      env = script_params.transform_keys { |k| "REDMINE_#{k.to_s.upcase}" }
                        .transform_values { |v| v.to_s }
      
      script_file = Tempfile.new(['status_script', '.sh'], '/tmp')
      script_file.write(config.script_content)
      script_file.close
      File.chmod(0755, script_file.path)
      
      output_file = script_file.path + '.out'
      error_file = script_file.path + '.err'
      
      pid = Process.spawn(env, script_file.path, out: output_file, err: error_file)
      Process.wait(pid)
      
      output = ""
      output = File.read(output_file) if File.exist?(output_file)
      error_content = File.read(error_file) if File.exist?(error_file)
      output += "\nSTDERR:\n#{error_content}" if error_content.present?
      
      [output_file, error_file].each { |f| File.delete(f) if File.exist?(f) }
      script_file.unlink
      
      output.presence || "Script executed successfully"
    else
      "Script type #{config.script_type} not implemented yet"
    end
  end
end

Rails.logger.info "Status Script Plugin: Loaded successfully with hook"