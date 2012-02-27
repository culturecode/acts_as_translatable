module ActsAsTranslatable
  class Engine < Rails::Engine
  end
  
  module ActMethod
    # Overwrite the attribute accessor for each attribute
    # listed as translatable. an attribute_untranslated
    # accessor is also created to allow access to the
    # untranslated version of the accessor.
    def acts_as_translatable(*attrs)
      options = attrs.last.is_a?(Hash) ? attrs.pop : {}

      cattr_accessor :translatable_options
      self.translatable_options = options
      
      cattr_accessor :translatable_attributes
      self.translatable_attributes = attrs.collect!(&:to_s)

      has_many :translations, :as => :translatable, :dependent => :destroy, :autosave => true

      # Create scopes to return all the records that have not been translated fully
      # e.g.      
      #
      # SELECT * FROM "item_types" INNER JOIN "item_item_types" ON "item_types".id = "item_item_types".item_type_id
      # WHERE (("item_item_types".item_id = 53)) AND ((

      # -- Where the item type has fields with text in them that needs to be translated
      # case when "item_types".name ~ E'\\\\S+' then (1) else (0) end > 0

      # -- And the item type is not in the list of item types that have been fully translated
      # AND "item_types".id NOT IN ( SELECT translatable_id FROM "translations" WHERE (translatable_type = 'ItemType'
      
      # -- Make sure we don't count translations that are blank towards the total translations count for this ItemType
      # AND translator_id IS NOT NULL AND text ~ '\\S+')

      # -- Only pick groups that have the same number of translations as they have translatable fields with text in them
      # GROUP BY translatable_id, translatable_type HAVING count(*) = case when "item_types".name ~ E'\\\\S+' then (1) else (0) end)))
      translatable_attributes_filled_sql = []
        for attribute in self.translatable_attributes
          translatable_attributes_filled_sql << %(case when #{quoted_table_name}.#{attribute} ~ E'\\\\S+' then (1) else (0) end)
        end
      translatable_attributes_filled_sql = translatable_attributes_filled_sql.join('+')
          
      fully_translated = Translation.select(:translatable_id).where(%(translatable_type = '#{self.name}' AND text ~ E'\\\\S+')).group(:translatable_id, :translatable_type).having("count(*) = #{translatable_attributes_filled_sql}")
      associations = column_names.include?('associations_translated')
      
      scope :translation_incomplete, where("#{'NOT associations_translated OR' if associations} (#{translatable_attributes_filled_sql} > 0 AND #{quoted_table_name}.id NOT IN (#{fully_translated.to_sql}))")
      scope :translation_complete, where("#{'associations_translated AND' if associations} #{quoted_table_name}.id IN (#{fully_translated.to_sql})")

      before_validation :set_locale, :on => :create
      
      attrs.each do |attribute|
        # GETTERS
        # Return the translated value or the untranslated value if no translation is available
        define_method("localized_#{attribute}") do
          if self.locale.blank? || self.locale == I18n.locale.to_s
            send(attribute)
          else
            translation = attribute_translation(attribute)
            translation ? translation.text : send(attribute)
          end
        end

        # Return the translation or the default value for that column
        define_method("#{attribute}_translated") do
          translation = attribute_translation(attribute)
          translation ? translation.text : self.class.columns.find {|column| column.name == attribute }.try(:default) # We 'try', because this may be an ActiveRecord::Base.store column, with no default
        end
        
        # SETTERS
        define_method("#{attribute}_translated=") do |value|
          translation = attribute_translation(attribute)
          if value.blank?
            puts "blank"
            translation.destroy if translation
          elsif translation
            puts "update"
            translation.text = value
          else
            puts "new"
            self.translations.build(:attribute_name => attribute, :text => value)
          end
        end        
      end

      # Cache whether or not the associations have been translated
      if options[:translatable_associations] && column_names.include?('associations_translated')
        after_save :update_associations_translated_cache
      end

      include ActsAsTranslatable::InstanceMethods
    end    
  end

  module InstanceMethods
    # Returns true if there are translations for each translatable attribute
    def translation_complete?
      !translation_incomplete?
    end

    def translation_incomplete?
      self.class.translation_incomplete.exists?(self)
    end
    
    def attribute_translation(attribute_name)
      translations.detect {|translation| translation.attribute_name == attribute_name.to_s }
    end
    
    # Because we have a number of associations that can be untranslated, we check them and cache whether or not all the associations have been translated
    def update_associations_translated_cache
      result = Array(translatable_options[:translatable_associations]).all? do |association|
        records = send(association)
        case records
        when ActiveRecord::Base
          # If it's a single record
          send(association).translation_complete?
        else
          # If it's a relation
          send(association).translation_incomplete.empty?
        end
      end
      # Save without triggering callbacks
      self.class.update_all({:associations_translated => result}, :id => self.id) if self.class.column_names.include? 'associations_translated'
    end    
    
    private 
    
    def set_locale
      self.locale = I18n.locale.to_s if self.locale.blank?
    end    
    
    def target_locale
      self.locale == I18n.available_locales.first.to_s ? I18n.available_locales.second.to_s : I18n.available_locales.first.to_s
    end
  end
end