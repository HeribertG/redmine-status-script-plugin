# plugins/redmine_status_scripts/init.rb

# Hook-Klasse laden
require_dependency 'status_script_hooks'

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

Rails.logger.info "Status Script Plugin: Loaded successfully"