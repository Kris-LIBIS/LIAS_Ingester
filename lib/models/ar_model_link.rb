# coding: utf-8

require 'dm-core'

class ArModelLink
  include DataMapper::Resource

  property    :accessright_model_id,    Integer, key: true
  property    :accessright_id,          Integer
  property    :usage_type,              String, required: true, key: true

  belongs_to  :accessright_model
  belongs_to  :accessright
end