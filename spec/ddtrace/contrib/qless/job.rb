LogHelpers.without_warnings do
  require 'qless'
end

require 'ddtrace/contrib/qless/qless_job'
require 'qless'
require 'qless/test_helpers/worker_helpers'
require 'qless/worker'
require 'qless/job_reservers/ordered'


### For ForkingWorker
require 'qless/job_reservers/round_robin'
require 'tempfile'


class TempfileWithString < Tempfile
  # To mirror StringIO#string
  def string
    rewind
    read.tap { close }
  end
end

RSpec.shared_context 'Qless job' do
  include Qless::WorkerHelpers

  let(:host) { ENV.fetch('TEST_REDIS_HOST', '127.0.0.1') }
  let(:port) { ENV.fetch('TEST_REDIS_PORT', 6379) }
  let(:client) { Qless::Client.new(host: host, port: port) }
  let(:queue) { client.queues['main'] }
  let(:reserver) { Qless::JobReservers::Ordered.new([queue]) }
  # let(:worker) { Qless::Workers::SerialWorker.new(reserver) }

  let(:log_io) { TempfileWithString.new('qless.log') }
  let(:worker) do
    Qless::Workers::ForkingWorker.new(
        Qless::JobReservers::RoundRobin.new([queue]),
        interval: 1,
        max_startup_interval: 0,
        output: log_io,
        log_level: Logger::DEBUG)
  end

  after { log_io.unlink }

  def perform_job(klass, *args)
    queue.put(klass, args)
    drain_worker_queues(worker)
  end

  def failed_jobs
    client.jobs.failed
  end

  def delete_all_redis_keys
    client.redis.keys.each {|k| client.redis.del k }
  end

  # def after_fork
  #   puts "====== spec.after_fork"
  #   Datadog::Pin.get_from(Qless).tracer.writer = FauxWriter.new
  # end

  # class MyJobClass
  #   # extend ::Qless::Job::SupportsMiddleware
  #   # extend Datadog::Contrib::Qless::QlessJob
  #   def self.perform(job)
  #     # job is an instance of `Qless::Job` and provides access to
  #     # job.data, a means to cancel the job (job.cancel), and more.
  #     puts "=== MyJobClass"
  #   end
  # end

  let(:job_class) do
    stub_const('TestJob', Class.new).tap do |mod|
      mod.send(:define_singleton_method, :perform) do |job|
        # Do nothing by default.
      end
    end
  end
  let(:job_args) { {} }

  # before(:each) do
  #   Qless.after_fork { Datadog::Pin.get_from(Qless).tracer.writer = FauxWriter.new }
  #   Qless.before_first_fork.each(&:call)
  # end
end
