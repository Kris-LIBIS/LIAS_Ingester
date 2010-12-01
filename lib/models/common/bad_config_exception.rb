class BadConfigException < StandardError
  attr :error, :fix
  def initialize(error, fix)
    @error = error
    @fix = fix
    message = error
    if @fix
      message += " - #{fix}"
    end
    @@logger.error(message)
    super
  end
end
