# plugins/redmine_status_scripts/db/migrate/004_expand_script_content_field.rb
class ExpandScriptContentField < ActiveRecord::Migration[6.1]
  def up
    say "Vergrößere script_content Feld für größere Scripts..."
    
    # Aktuelle Feldgröße prüfen
    script_content_column = StatusScriptConfig.columns.find { |c| c.name == 'script_content' }
    
    if script_content_column
      current_type = script_content_column.sql_type
      say "  Aktueller Typ: #{current_type}"
      
      case current_type.downcase
      when /text/
        say "  Feld ist bereits TEXT - vergrößere zu LONGTEXT"
        change_column :status_script_configs, :script_content, :text, limit: 4294967295
      when /varchar/
        say "  Feld ist VARCHAR - ändere zu LONGTEXT"
        change_column :status_script_configs, :script_content, :text, limit: 4294967295
      else
        say "  Unbekannter Typ - ändere zu LONGTEXT"
        change_column :status_script_configs, :script_content, :text, limit: 4294967295
      end
    else
      say "  script_content Spalte nicht gefunden!"
    end
    
    # Auch andere relevante Text-Felder erweitern
    say "Erweitere weitere Text-Felder..."
    
    # description erweitern (falls noch nicht groß genug)
    change_column :status_script_configs, :description, :text, limit: 65535 if column_exists?(:status_script_configs, :description)
    
    # environment_variables erweitern  
    change_column :status_script_configs, :environment_variables, :text, limit: 65535 if column_exists?(:status_script_configs, :environment_variables)
    
    # Auch in den Log-Tabellen erweitern
    change_column :status_script_logs, :output, :text, limit: 4294967295 if column_exists?(:status_script_logs, :output)
    change_column :status_script_logs, :error_message, :text, limit: 4294967295 if column_exists?(:status_script_logs, :error_message)
    change_column :status_script_logs, :script_params, :text, limit: 4294967295 if column_exists?(:status_script_logs, :script_params)
    
    say "Feldvergrößerung abgeschlossen."
    
    # Informationen über die neuen Limits
    say "Neue Limits:"
    say "  - script_content: ~4GB (LONGTEXT)"
    say "  - description: ~64KB (TEXT)"
    say "  - environment_variables: ~64KB (TEXT)"
    say "  - output/error_message/script_params: ~4GB (LONGTEXT)"
  end

  def down
    say "Verkleinere Text-Felder zurück auf Standard-Größen..."
    
    # Warnung ausgeben
    say "WARNUNG: Diese Migration kann zu Datenverlust führen, wenn große Scripts existieren!"
    
    # Zurück zu kleineren Feldgrößen
    change_column :status_script_configs, :script_content, :text, limit: 65535
    change_column :status_script_configs, :description, :text, limit: 65535
    change_column :status_script_configs, :environment_variables, :text, limit: 65535
    
    change_column :status_script_logs, :output, :text, limit: 65535
    change_column :status_script_logs, :error_message, :text, limit: 65535
    change_column :status_script_logs, :script_params, :text, limit: 65535
    
    say "Felder auf Standard-TEXT-Größe zurückgesetzt."
  end
end