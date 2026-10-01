#!/usr/bin/env ruby
# Pure choice resolution: one target, no intermediate states.
require 'json'
require 'yaml'
require 'open3'
BASE = YAML.load_file('infra/root/values.yaml').fetch('selection').transform_values { false }

def plan(current, choices = {})
  input = {current: {selection: current}, choices: BASE.transform_values { 'keep' }.merge(choices)}
  out, error, status = Open3.capture3('jq', '-f', 'infra/github-actions/selection-plan.jq', stdin_data: JSON.generate(input))
  raise error unless status.success?
  JSON.parse(out)
end

raise 'keep should not commit' if plan(BASE)['changed']
raise 'disable false should not commit' if plan(BASE, {'enable_redis'=>'disable'})['changed']
redis = BASE.merge('enable_redis'=>true)
raise 'enable true should not commit' if plan(redis, {'enable_redis'=>'enable'})['changed']
raise 'disable should change target' if plan(redis, {'enable_redis'=>'disable'}).dig('target', 'enable_redis')
raise 'enable should change target' unless plan(BASE, {'enable_redis'=>'enable'}).dig('target', 'enable_redis')
all = BASE.transform_values { true }
result = plan(all, BASE.transform_values { 'disable' })
raise 'Disable all must be one final target' unless result['target'] == BASE && !result.key?('stages')

[{'enable_postgres'=>'disable'}, {'enable_rabbitmq_stack'=>'disable'}, {'enable_payment_service'=>'disable'}].each do |choice|
  begin
    plan(all, choice)
    raise 'Missing dependency was accepted'
  rescue RuntimeError => e
    raise unless e.message.include?('order-service requires')
  end
end
begin
  plan(BASE, {'enable_redis'=>'unexpected'})
  raise 'Invalid choice accepted'
rescue RuntimeError => e
  raise unless e.message.include?('Invalid choice')
end
puts 'PASS: keep/no-op, enable/disable, one final target and dependency validation'
