class Translation < ActiveRecord::Base
  belongs_to :translatable, :polymorphic => true
  belongs_to :translator, :class_name => 'User'
  
  scope :unverified, {:conditions => "translator_id IS NULL"}
  scope :verified, {:conditions => "translator_id IS NOT NULL"}
  scope :for_user, lambda {|user_id| where(:user_id => user_id) if user_id.present? }

  validates_presence_of :text
  
  def self.translate(translator, translatable_type, translatable_id, attribute_name, text)
    t = find_or_initialize_by_translatable_type_and_translatable_id_and_attribute_name(translatable_type, translatable_id, attribute_name)
    
    t.update_attributes(:translator_id => translator.id, :text => text)
  end
  
  def attribute_untranslated
    translatable.send(attribute_name)
  end
end
