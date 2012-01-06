# coding: utf-8

class ScopeSearch < GenericSearch
  def initialize
  end

  def query(term, index = nil, base = nil, options = {})
    system "sqlplus APLKN_ARCHV_LIAS/archvsc@SCOPE01 @'#{@metadata_sql_file}'"
  end

end