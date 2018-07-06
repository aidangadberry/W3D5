class AttrAccessorObject
  def self.my_attr_accessor(*names)
    names.each do |method_name|
      define_method(method_name) do
        instance_variable_get("@#{method_name}".to_sym)
      end

      define_method("#{method_name}=".to_sym) do |val|
        instance_variable_set("@#{method_name}".to_sym, val)
      end
    end
  end
end
