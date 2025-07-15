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
    
    # Script-Konfiguration suchen
    config = StatusScriptConfig.find_for_transition(old_status_id, new_status_id, issue.project_id)
    
    unless config
      Rails.logger.info "Status Script: No config found for transition #{old_status_id} -> #{new_status_id}"
      return
    end
    
    Rails.logger.info "Status Script: Found config '#{config.name}'"
    
    # Log-Eintrag erstellen
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
      
      # Erfolg loggen
      log.update!(
        success: true,
        output: output,
        finished_at: Time.current
      )
      
      Rails.logger.info "Status Script: Executed successfully"
      
    rescue StandardError => e
      # Fehler loggen
      log.update!(
        success: false,
        error_message: e.message,
        finished_at: Time.current
      )
      
      Rails.logger.error "Status Script Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  def execute_script(issue, config, old_status_id, new_status_id)
    script_params = build_script_params(issue, old_status_id, new_status_id)
    
    case config.script_type
    when 'shell'
      execute_shell_script(config.script_content, script_params, config.timeout)
    when 'webhook'
      execute_webhook(config.webhook_url, script_params, config.timeout)
    when 'ruby'
      execute_ruby_code(config.script_content, script_params)
    else
      raise "Unsupported script type: #{config.script_type}"
    end
  end

  def build_script_params(issue, old_status_id, new_status_id)
    {
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
  end

  def execute_shell_script(script_content, params, timeout = 30)
    return "No script content" unless script_content.present?
    
    Rails.logger.info "Status Script: Executing shell script"
    
    # Umgebungsvariablen setzen
    env = params.transform_keys { |k| "REDMINE_#{k.to_s.upcase}" }
                .transform_values { |v| v.to_s }
    
    # Temporäres Script-File erstellen
    script_file = Tempfile.new(['status_script', '.sh'], '/tmp')
    script_file.write(script_content)
    script_file.close
    
    # Ausführbar machen
    File.chmod(0755, script_file.path)
    
    # Script ausführen
    output = ""
    begin
      output_file = script_file.path + '.out'
      error_file = script_file.path + '.err'
      
      Rails.logger.info "Status Script: Running script #{script_file.path}"
      
      pid = Process.spawn(env, script_file.path, 
                         out: output_file, 
                         err: error_file)
      
      Timeout.timeout(timeout) do
        Process.wait(pid)
      end
      
      # Output lesen
      if File.exist?(output_file)
        output = File.read(output_file)
        File.delete(output_file)
      end
      
      if File.exist?(error_file)
        error_content = File.read(error_file)
        File.delete(error_file)
        output += "\nSTDERR:\n#{error_content}" if error_content.present?
      end
      
      Rails.logger.info "Status Script: Shell script completed successfully"
      
    rescue Timeout::Error
      Process.kill('TERM', pid) rescue nil
      raise "Script timeout after #{timeout} seconds"
    rescue => e
      Rails.logger.error "Status Script: Shell script failed: #{e.message}"
      raise e
    end
    
    output.presence || "Script executed successfully"
    
  ensure
    script_file&.unlink
  end

  def execute_webhook(url, params, timeout = 30)
    return "No webhook URL" unless url.present?
    
    require 'net/http'
    require 'json'
    
    Rails.logger.info "Status Script: Sending webhook to #{url}"
    
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = timeout
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['User-Agent'] = 'Redmine Status Scripts Plugin'
    request.body = params.to_json
    
    response = http.request(request)
    
    unless response.code.start_with?('2')
      raise "Webhook failed with status #{response.code}: #{response.body}"
    end
    
    Rails.logger.info "Status Script: Webhook sent successfully"
    "Webhook sent successfully. Response: #{response.code}"
  end

  def execute_ruby_code(code, params)
    return "No Ruby code" unless code.present?
    
    Rails.logger.info "Status Script: Executing Ruby code"
    
    # Sicheren Kontext erstellen
    binding_context = Object.new
    
    # Parameter als Instanzvariablen setzen
    params.each do |key, value|
      binding_context.instance_variable_set("@#{key}", value)
    end
    
    # Output capturing
    original_stdout = $stdout
    $stdout = StringIO.new
    
    begin
      # Code ausführen
      result = binding_context.instance_eval(code)
      output = $stdout.string
      output += "\nReturn value: #{result.inspect}" if result
      
      Rails.logger.info "Status Script: Ruby code executed successfully"
      return output.presence || "Ruby code executed successfully"
      
    rescue => e
      Rails.logger.error "Status Script: Ruby code failed: #{e.message}"
      raise e
    ensure
      $stdout = original_stdout
    end
  end
end