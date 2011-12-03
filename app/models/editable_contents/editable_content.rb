class EditableContent < ActiveRecord::Base  
  include EditableContentsHelper
  
  validates_presence_of :title
  validates_uniqueness_of :title, :case_sensitive => false

  scope :search, lambda {|text| where('title ILIKE ? OR body ILIKE ?', "%#{text}%", "%#{text}%") if text.present?}
  scope :section, lambda {|section| where(:section => section) if section.present?}    
    
  before_save :downcase_section
    
  def self.sections
    connection.select_values(select('section').to_sql)
  end
    
  def self.section!(section)
    where("LOWER(section) = LOWER(?)", section).first || create(:title => section.to_s.titleize, :body => "This is a stub. You can edit this text yourself. Edit the content called #{section.to_s.titleize}", :section => section)
  end
  
  def to_s
    self.body
  end
  
  def to_html(options = nil)
    markdown(self.body, options)
  end
  
  private
  
  def downcase_section
    self.section = self.section.downcase
  end
end
