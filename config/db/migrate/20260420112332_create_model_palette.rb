# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :model_palette do
      primary_key :id

      foreign_key :model_id, :model, null: false, on_delete: :cascade, on_update: :cascade
      foreign_key :palette_id, :palette, null: false, on_delete: :cascade, on_update: :cascade

      column :created_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    add_index :model_palette, %i[model_id palette_id], unique: true
  end
end
