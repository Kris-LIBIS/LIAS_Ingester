class ComplexFileCollecter

  def initialize(config = nil)
    @raise_exception = false
    @config = config
  end
  
  private
  
  def config_init(obj)
    @config = obj.get_config unless @config
  end
  
  public
  
  def check(obj)
    
    return true unless @config.complex
    
    config_init obj
   
    label = @config.complex_label
    group = @config.complex_group
    
    result = true
    if obj.file_name =~ @config.filename_match
      obj.label = eval label
      @config.root_object(eval(group)).add_child(obj)#.save
    else
      obj.message = "File '#{obj.file_name}' mismatched complex object criteria"
      result = false
    end
    
    result
    
  end
  
end
