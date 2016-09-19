# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'rubygems'
require 'bundler/setup'
require 'json'

require 'salt'

def execute_command(data)
  return false if data[:execution_type] != 'salt'

  begin
    api = Salt::SaltMaster.new(
      endpoint: data[:service_endpoint],
      port: '8000',
      user: data[:service_options][:user],
      pass: data[:service_options][:password]
    )

    params = { arg: data[:execution_payload] }
    fun = data[:execution_function]
    params[:fun] = fun ? fun : 'cmd.run_all'
    split_target = data[:execution_target].split(':')
    target_type = split_target.first

    case target_type
    when 'grain'
      params[:expr_form] = 'grain'
      params[:tgt] = options[:grain]
    when 'grains'
      params[:expr_form] = 'compound'
      params[:tgt] = split_target.split(',').map { |g| "G@#{g}" }.join('and')
    when 'list'
      params[:expr_form] = 'list'
      params[:tgt] = split_target.last
    end

    job_id = execute(api, params)
    job = api.job job_id

    msg = '{"error": "no minions matched"}'

    data[:execution_results] = msg unless job.minions

    loop do
      sleep 2
      job = api.job job_id

      if job.minions.sort == job.reports.collect(&:node).sort
        results = { reports: [] }

        job.reports.each do |report|
          hash = {}
          hash[:instance] = report.node
          hash[:return_code] = report.retcode
          # hash[:stdout] = report.stdout
          hash[:stderr] = report.stderr
          results[:reports] << hash
        end

        data[:execution_results] = results
        data[:execution_matched_instances] = job.minions

        if job.reports.collect(&:retcode).sort.uniq.count > 1
          data[:type] = 'execution.create.salt.error'
          data[:execution_status] = 'failed'
        else
          data[:type] = 'execution.create.salt.done'
          data[:execution_status] = 'success'
        end

        break

      end
    end
    data[:type] = data[:type] + '.done'
    return data
  rescue => e
    puts e
    data[:type] = data[:type] + '.error'
    return data
  end
end

def execute(api, params)
  i = 0
  loop do
    job_id = api.execute params[:fun], params[:arg], params[:tgt], params[:expr_form]
    return job_id unless job_id.nil?
    i += 1
    return nil if i > 10
    sleep 3
  end
end

unless defined? @@test
  sleep 5
  @data = { id: SecureRandom.uuid, type: ARGV[0] }
  @data.merge! JSON.parse(ARGV[1], symbolize_names: true)
  original_stdout = $stdout
  $stdout = StringIO.new
  begin
    @data = execute_command(@data)

    if @data[:type].include? 'error'
      @data['error'] = { code: 0, message: $stdout.string.to_s }
    end
    exit if @data == false
  ensure
    $stdout = original_stdout
  end

  puts @data.to_json
end
