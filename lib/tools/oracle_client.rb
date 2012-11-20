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
    system "echo \"call #{procedure}(#{params});\" | sqlplus -S #@user/#@password@#@database"
  end

  def run(script, parameters = [])
    params = ''
    params = "\"" + parameters.join("\" \"") + "\"" if parameters and parameters.size > 0
    process_result `sqlplus -S #@user/#@password@#@database @#{script} #{params}`
  end

  def execute(sql)
    process_result `echo \"#{sql}\" | sqlplus -S #@user/#@password@#@database`
  end

  private

  def process_result(log)
    log.gsub!(/\n\n/,"\n")
    rows_created = 0
    log.match(/^(\d+) rows? created.$/) { |m| rows_created += m[1] }
    rows_deleted = 0
    log.match(/^(\d+) rows? deleted.$/) { |m| rows_deleted += m[1] }
    rows_updated = 0
    log.match(/^(\d+) rows? updated.$/) { |m| rows_updated += m[1] }
    errors = Hash.new(0)
    error_count = 0
    log.match(/\nERROR .*\n([^\n]*)\n/) { |m| errors[m[1]] += 1; error_count += 1 }
    {created: rows_created, updated: rows_updated, deleted: rows_deleted, errors: error_count, error_detail: errors}
  end

end