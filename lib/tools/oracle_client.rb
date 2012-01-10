class OracleClient

  def initialize(database, user, password)
    @database = database
    @user = user
    @password = password
  end

  def OracleClient.scope_client
    OracleClient.new("SCOPE01", "APLKN_ARCHV_LIAS", "archvsc")
  end

  def call(procedure, parameters = [])
    params = ''
    params = "'" + parameters.join("','") + "'" if parameters and parameters.size > 0
    system "echo \"call #{procedure}(#{params});\" | sqlplus -S #{@user}/#{@password}@#{@database}"
  end

  def run(script, parameters = [])
    params = ''
    params = "\"" + parameters.join("\" \"") + "\"" if parameters and parameters.size > 0
    system "sqlplus -S #{@user}/#{@password}@#{@database} @#{script} #{params}"
  end

  def execute(sql)
    system "echo \"#{sql}\" | sqlplus -S #{@user}/#{@password}@#{@database}"
  end

end