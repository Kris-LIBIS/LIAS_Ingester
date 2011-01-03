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
   
##    group = '\'' + @config.complex_group.gsub(/(\$\d+)/, '\' + \1 + \'') + '\''
##    label = '\'' + @config.complex_label.gsub(/(\$\d+)/, '\' + \1 + \'') + '\''
    label = @config.complex_label
    group = @config.complex_group

    result = true
    if obj.file_name =~ @config.filename_match
#      begin
#        $stdout = File.new('/dev/null','w')
#        obj.label = eval('p "#{label}"')
#        @config.root_object(eval('p "#{group}"')).add_child(obj).save
#      ensure
#        $stdout = STDOUT
#      end
      obj.label = eval label
      @config.root_object(eval(group)).add_child(obj)#.save
    else
      obj.message = "File '#{obj.file_name}' mismatched complex object criteria"
      result = false
    end

 #   obj.save
    result

  end

end
