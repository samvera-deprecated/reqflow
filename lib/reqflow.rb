require "reqflow/version"
require "reqflow/instance"
require "reqflow/worker"

module Reqflow
  class RetriableError < Exception; end
  class FatalError < Exception; end
end
