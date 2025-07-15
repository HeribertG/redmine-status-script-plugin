# plugins/redmine_status_scripts/db/migrate/002_create_status_script_logs.rb
class CreateStatusScriptLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :status_script_logs do |t|
      t.integer :issue_id, null: false
      t.integer :from_status_id, null: true
      t.integer :to_status_id, null: false
      t.bigint :status_script_config_id, null: true
      t.integer :user_id, null: true
      t.datetime :executed_at, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.boolean :success, default: true
      t.text :output
      t.text :error_message
      t.text :script_params
      t.timestamps
    end

    add_index :status_script_logs, :issue_id
    add_index :status_script_logs, :executed_at
    add_index :status_script_logs, :success
  end
end