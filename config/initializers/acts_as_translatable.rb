# Make an input to create a translated input
class SimpleForm::FormBuilder
  def translated_input(attribute_name, options = {})    
    options.reverse_merge! :wrapper_html => {}
    output = "".html_safe

    template.content_tag :div, :class => "form_group" do
      # Because the translated_attribute is a pseudo attribute, we need to find out what input type to make or simple form will just make a string input. 
      input_type = default_input_type(attribute_name, find_attribute_column(attribute_name), {})
      output = input(attribute_name, options)
      options[:wrapper_html].merge!(:class => "translation_field")
      options[:as] = input_type
      output << input("#{attribute_name}_translated", options)
    end

    return output
  end
end