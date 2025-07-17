# plugins/redmine_status_scripts/db/migrate/003_normalize_existing_script_content.rb
class NormalizeExistingScriptContent < ActiveRecord::Migration[6.1]
  def up
    say "Normalisiere existierende Script-Inhalte..."
    
    StatusScriptConfig.find_each do |config|
      changes_made = false
      
      # Script-Inhalt normalisieren
      if config.script_content.present?
        original_content = config.script_content
        normalized_content = normalize_script_content(original_content, config.script_type)
        
        if original_content != normalized_content
          config.update_column(:script_content, normalized_content)
          changes_made = true
          say "  - Config '#{config.name}': Script-Inhalt normalisiert"
        end
      end
      
      # Webhook-URL normalisieren
      if config.webhook_url.present?
        original_url = config.webhook_url
        normalized_url = original_url.strip.gsub(/[\r\n\t]/, '')
        
        if original_url != normalized_url
          config.update_column(:webhook_url, normalized_url)
          changes_made = true
          say "  - Config '#{config.name}': Webhook-URL normalisiert"
        end
      end
      
      # Name normalisieren
      if config.name.present?
        original_name = config.name
        normalized_name = original_name.strip.gsub(/[\r\n]/, ' ').squeeze(' ')
        
        if original_name != normalized_name
          config.update_column(:name, normalized_name)
          changes_made = true
          say "  - Config '#{config.name}': Name normalisiert"
        end
      end
      
      # Beschreibung normalisieren
      if config.description.present?
        original_desc = config.description
        normalized_desc = original_desc.strip.gsub(/\r\n/, "\n").gsub(/\r/, "\n")
        
        if original_desc != normalized_desc
          config.update_column(:description, normalized_desc)
          changes_made = true
          say "  - Config '#{config.name}': Beschreibung normalisiert"
        end
      end
      
      # Umgebungsvariablen normalisieren
      if config.environment_variables.present?
        original_env = config.environment_variables
        lines = original_env.split(/\r?\n/).map(&:strip).reject(&:empty?)
        normalized_env = lines.join("\n")
        
        if original_env != normalized_env
          config.update_column(:environment_variables, normalized_env)
          changes_made = true
          say "  - Config '#{config.name}': Umgebungsvariablen normalisiert"
        end
      end
      
      unless changes_made
        say "  - Config '#{config.name}': Keine Änderungen erforderlich", true
      end
    end
    
    say "Normalisierung abgeschlossen."
  end

  def down
    say "Rollback der Normalisierung ist nicht möglich - die ursprünglichen Daten sind überschrieben."
    say "Falls erforderlich, müssen die Scripts manuell überprüft werden."
  end

  private

  def normalize_script_content(content, script_type)
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
end