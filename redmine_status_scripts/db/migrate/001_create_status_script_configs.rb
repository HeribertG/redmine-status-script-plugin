class CreateStatusScriptConfigs < ActiveRecord::Migration[6.1]
  def change
    create_table :status_script_configs do |t|
      t.string :name, null: false, limit: 255
      t.text :description
      t.integer :from_status_id, null: true
      t.integer :to_status_id, null: false
      t.integer :project_id, null: true
      t.string :script_type, null: false, limit: 20
      t.text :script_content
      t.string :webhook_url, limit: 500
      t.boolean :enabled, default: true
      t.integer :timeout, default: 30
      t.text :environment_variables
      t.timestamps
    end

    add_index :status_script_configs, [:from_status_id, :to_status_id]
    add_index :status_script_configs, :project_id
    add_index :status_script_configs, :enabled
    
    # Foreign Keys separat hinzufügen
    add_foreign_key :status_script_configs, :issue_statuses, column: :from_status_id
    add_foreign_key :status_script_configs, :issue_statuses, column: :to_status_id
    add_foreign_key :status_script_configs, :projects, column: :project_id
  end
end