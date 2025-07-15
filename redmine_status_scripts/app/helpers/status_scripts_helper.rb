module StatusScriptsHelper
  
  def get_script_placeholder(script_type)
    case script_type&.to_s
    when 'shell'
      shell_script_placeholder
    when 'ruby'
      ruby_script_placeholder
    when 'webhook'
      ''
    else
      ''
    end
  end

  def shell_script_placeholder
    <<~SHELL
      #!/bin/bash
      echo "Issue $REDMINE_ISSUE_ID changed to $REDMINE_NEW_STATUS_NAME"
      echo "Project: $REDMINE_PROJECT_NAME"
      echo "Assignee: $REDMINE_ASSIGNEE_NAME"

      # Beispiel: Slack-Benachrichtigung
      curl -X POST -H 'Content-type: application/json' \\
        --data "{\\"text\\":\\"Issue #$REDMINE_ISSUE_ID wurde auf '$REDMINE_NEW_STATUS_NAME' gesetzt\\"}" \\
        https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK

      # Beispiel: E-Mail senden
      echo "Issue #$REDMINE_ISSUE_ID Status: $REDMINE_NEW_STATUS_NAME" | \\
        mail -s "Redmine Update" admin@example.com

      # Beispiel: Log-Datei schreiben
      echo "$(date): Issue #$REDMINE_ISSUE_ID -> $REDMINE_NEW_STATUS_NAME" >> /var/log/redmine-status.log
    SHELL
  end

  def ruby_script_placeholder
    <<~RUBY
      # Zugriff auf Parameter über @variablen
      puts "Issue #{@issue_id}: #{@issue_subject}"
      puts "Status: #{@old_status_name} → #{@new_status_name}"
      puts "Project: #{@project_name}"
      puts "Assignee: #{@assignee_name}"

      # Beispiel: E-Mail versenden
      if @new_status_name == 'Resolved'
        # UserMailer.issue_resolved(@issue_id).deliver_now
        puts "E-Mail würde gesendet werden für gelöstes Issue"
      end

      # Beispiel: HTTP-Request an externe API
      require 'net/http'
      require 'json'

      uri = URI('https://your-api.com/webhook')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = {
        event: 'status_changed',
        issue_id: @issue_id,
        new_status: @new_status_name,
        project: @project_name
      }.to_json

      # response = http.request(request)

      # Beispiel: Datei schreiben
      File.open('/tmp/redmine-updates.log', 'a') do |f|
        f.puts "#{Time.now}: Issue ##{@issue_id} -> #{@new_status_name}"
      end
    RUBY
  end

  def script_type_options
    [
      ['Shell Script', 'shell'],
      ['Webhook (HTTP POST)', 'webhook'],
      ['Ruby Code', 'ruby']
    ]
  end

  def status_badge(enabled)
    classes = enabled ? 'status-badge enabled' : 'status-badge disabled'
    text = enabled ? 'Aktiv' : 'Inaktiv'
    content_tag :span, text, class: classes
  end

  def script_type_badge(script_type)
    classes = "script-type-badge script-type-#{script_type}"
    content_tag :span, script_type.humanize, class: classes
  end

  def result_badge(success, message = nil)
    classes = success ? 'result-badge success' : 'result-badge error'
    text = success ? '✓ Erfolgreich' : '✗ Fehlgeschlagen'
    
    if message.present?
      text += ": #{truncate(message, length: 50)}"
    end
    
    content_tag :span, text, class: classes
  end

  def execution_time_badge(started_at, finished_at)
    return '-' unless started_at && finished_at
    
    duration_ms = ((finished_at - started_at) * 1000).round(2)
    
    classes = case duration_ms
              when 0..1000
                'duration-badge fast'
              when 1001..5000
                'duration-badge medium'
              else
                'duration-badge slow'
              end
    
    content_tag :span, "#{duration_ms}ms", class: classes
  end

  def status_transition_display(from_status, to_status)
    from_name = from_status&.name || 'Jeder Status'
    to_name = to_status.name
    
    content_tag :span, class: 'transition' do
      content_tag(:span, from_name, class: 'from-status') +
      content_tag(:span, ' → ', class: 'arrow') +
      content_tag(:span, to_name, class: 'to-status')
    end
  end

  def script_config_summary(config)
    summary = []
    
    # Status transition
    from_status = config.from_status&.name || 'Jeder Status'
    to_status = config.to_status.name
    summary << "#{from_status} → #{to_status}"
    
    # Project scope
    project_scope = config.project&.name || 'Alle Projekte'
    summary << project_scope
    
    # Script type
    summary << config.script_type.humanize
    
    summary.join(' | ')
  end

  def available_parameters_for_type(script_type)
    base_params = [
      'issue_id', 'issue_subject', 'project_id', 'project_name',
      'old_status_id', 'old_status_name', 'new_status_id', 'new_status_name',
      'assignee_id', 'assignee_name', 'author_id', 'author_name',
      'created_on', 'updated_on'
    ]

    case script_type&.to_s
    when 'shell'
      base_params.map { |param| "REDMINE_#{param.upcase}" }
    when 'ruby'
      base_params.map { |param| "@#{param}" }
    when 'webhook'
      base_params
    else
      []
    end
  end

  def format_script_content(content, script_type)
    return '' if content.blank?
    
    # Basic syntax highlighting via CSS classes
    case script_type
    when 'shell'
      content_tag :pre, content, class: 'script-content language-bash'
    when 'ruby'
      content_tag :pre, content, class: 'script-content language-ruby'
    else
      content_tag :pre, content, class: 'script-content'
    end
  end

  def log_filter_options
    {
      success: [
        ['Alle', ''],
        ['Erfolgreich', 'true'],
        ['Fehlgeschlagen', 'false']
      ],
      configs: StatusScriptConfig.order(:name).pluck(:name, :id)
    }
  end

  def pagination_info(collection)
    return '' unless collection.respond_to?(:current_page)
    
    start_item = (collection.current_page - 1) * collection.limit_value + 1
    end_item = [start_item + collection.limit_value - 1, collection.total_count].min
    
    "#{start_item}-#{end_item} von #{collection.total_count}"
  end

  def render_log_details(log)
    details = []
    
    if log.output.present?
      details << content_tag(:div, class: 'log-section') do
        content_tag(:h4, 'Ausgabe:') +
        content_tag(:pre, log.output, class: 'output')
      end
    end
    
    if log.error_message.present?
      details << content_tag(:div, class: 'log-section') do
        content_tag(:h4, 'Fehler:') +
        content_tag(:pre, log.error_message, class: 'error')
      end
    end
    
    if log.script_params.present?
      details << content_tag(:div, class: 'log-section') do
        content_tag(:h4, 'Parameter:') +
        content_tag(:pre, log.script_params, class: 'params')
      end
    end
    
    content_tag :div, safe_join(details), class: 'log-output'
  end

  def script_statistics_chart_data
    # Data for simple statistics chart
    last_30_days = 30.days.ago..Time.current
    
    logs_by_day = StatusScriptLog.where(executed_at: last_30_days)
                                 .group_by_day(:executed_at)
                                 .group(:success)
                                 .count
    
    chart_data = []
    (0..29).each do |days_ago|
      date = days_ago.days.ago.to_date
      successful = logs_by_day[[date, true]] || 0
      failed = logs_by_day[[date, false]] || 0
      
      chart_data << {
        date: date.strftime('%m-%d'),
        successful: successful,
        failed: failed,
        total: successful + failed
      }
    end
    
    chart_data.reverse
  end

  def render_mini_chart(data)
    return '' if data.empty?
    
    max_value = data.map { |d| d[:total] }.max
    return '' if max_value == 0
    
    bars = data.map do |point|
      height_percent = (point[:total].to_f / max_value * 100).round(1)
      success_percent = point[:total] > 0 ? (point[:successful].to_f / point[:total] * 100).round(1) : 0
      
      content_tag :div, '', 
                  class: 'chart-bar',
                  style: "height: #{height_percent}%",
                  title: "#{point[:date]}: #{point[:successful]}/#{point[:total]} erfolgreich",
                  data: { 
                    success_rate: success_percent,
                    total: point[:total]
                  }
    end
    
    content_tag :div, safe_join(bars), class: 'mini-chart'
  end

  def issue_link_with_project(issue)
    link_to "##{issue.id}", issue_path(issue), class: 'issue-link' do
      content_tag(:span, "##{issue.id}", class: 'issue-id') +
      content_tag(:span, issue.project.name, class: 'project-name')
    end
  end

  def truncate_with_tooltip(text, length = 50)
    return text if text.length <= length
    
    truncated = truncate(text, length: length)
    content_tag :span, truncated, title: text, class: 'truncated-text'
  end

  def script_execution_trend(config)
    recent_logs = config.status_script_logs.recent.limit(10)
    return 'Keine Daten' if recent_logs.empty?
    
    success_rate = (recent_logs.successful.count.to_f / recent_logs.count * 100).round(1)
    trend_class = case success_rate
                  when 90..100
                    'trend-excellent'
                  when 70..89
                    'trend-good'
                  when 50..69
                    'trend-warning'
                  else
                    'trend-critical'
                  end
    
    content_tag :span, "#{success_rate}%", class: "execution-trend #{trend_class}"
  end

  def render_webhook_test_form(config)
    return unless config.script_type == 'webhook'
    
    form_with url: test_status_script_path(config), method: :post, local: true, class: 'webhook-test-form' do |f|
      content_tag(:div, class: 'form-group') do
        f.label(:test_data, 'Test-Daten (JSON):') +
        f.text_area(:test_data, 
                   value: sample_webhook_data.to_json, 
                   rows: 8, 
                   class: 'code-editor')
      end +
      content_tag(:div, class: 'form-actions') do
        f.submit('Webhook testen', class: 'button') +
        content_tag(:span, ' oder ', class: 'separator') +
        link_to('Standard-Daten verwenden', '#', class: 'use-sample-data')
      end
    end
  end

  private

  def sample_webhook_data
    {
      issue_id: 1234,
      issue_subject: 'Test Issue',
      project_id: 1,
      project_name: 'Test Project',
      old_status_id: 1,
      old_status_name: 'New',
      new_status_id: 2,
      new_status_name: 'In Progress',
      assignee_id: 1,
      assignee_name: 'Test User',
      author_id: 1,
      author_name: 'Test Author',
      created_on: Time.current.iso8601,
      updated_on: Time.current.iso8601,
      test_mode: true
    }
  end
end