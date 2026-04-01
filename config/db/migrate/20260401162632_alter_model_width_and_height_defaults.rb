# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table :model do
      set_column_default :width, 0
      set_column_default :height, 0
    end
  end

  down do
    alter_table :model do
      set_column_default :width, 0
      set_column_default :height, 0
    end
  end
end
