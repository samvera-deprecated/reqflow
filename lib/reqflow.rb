require "reqflow/version"
require "reqflow/callbacks"
require "reqflow/instance"

module Reqflow
  class FatalError < Exception; end
  class UnknownAction < Exception; end
end
