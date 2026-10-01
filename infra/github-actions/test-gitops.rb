#!/usr/bin/env ruby
# Offline contract tests. These validate ownership/waves, not a running Argo controller.
require 'yaml'
require 'json'
require 'open3'

def render(chart, values = {}, namespace = 'default')
  text, error, status = Open3.capture3('helm', 'template', 'test', chart,
    '--namespace', namespace, '-f', '-', stdin_data: JSON.generate(values))
  raise error unless status.success?
  YAML.load_stream(text).compact
end

workflow = YAML.load_file('.github/workflows/codespaces-platform-deploy.yml')
inputs = (workflow['on'] || workflow[true]).fetch('workflow_dispatch').fetch('inputs')
selection = YAML.load_file('infra/root/values.yaml').fetch('selection')
raise 'Input/selection mismatch' unless inputs.keys.sort == selection.keys.sort
raise 'Wrong choices' unless inputs.values.all? { |v| v['default'] == 'keep' && v['options'] == %w[keep enable disable] }

all = render('infra/root', {'selection'=>selection.transform_values { true }})
apps = all.select { |r| r['kind'] == 'Application' }.to_h { |r| [r.dig('metadata','name'), r] }
wave = ->(name) { Integer(apps.fetch("resilient-orders-#{name}").dig('metadata','annotations','argocd.argoproj.io/sync-wave')) }
%w[cert-manager rabbitmq-operator rabbitmq-broker rabbitmq-topology payment-service order-service].each_cons(2) do |a,b|
  raise "Invalid dependency wave: #{a} -> #{b}" unless wave.call(a) < wave.call(b)
end
raise 'Policies must disappear before controller' unless wave.call('kyverno') < wave.call('kyverno-policies')
raise 'Namespaces must survive workload cleanup' unless wave.call('platform-system') < wave.call('services')
raise 'Projects must survive their applications' unless all.select { |r| r['kind'] == 'AppProject' }.all? { |r| Integer(r.dig('metadata','annotations','argocd.argoproj.io/sync-wave')) < apps.values.map { |a| Integer(a.dig('metadata','annotations','argocd.argoproj.io/sync-wave')) }.min }
raise 'Missing foreground finalizer' unless apps.values.all? { |a| a.dig('metadata','finalizers') == ['resources-finalizer.argocd.argoproj.io'] }

# Render every local child with the actual Helm parameters passed by root.
# A Kubernetes identity must have exactly one owning Application.
owners = {}
apps.each_value do |app|
  source = app.dig('spec','source')
  next unless %w[infra/platform-system infra/platform-runtime infra/services].include?(source['path'])
  # Boolean values must stay booleans, as Argo's forceString defaults to false.
  flags = source.dig('helm','parameters').flat_map { |p| ['--set', "#{p['name']}=#{p['value']}"] }
  ns = app.dig('spec','destination','namespace')
  text, error, status = Open3.capture3('helm','template',app.dig('spec','source','helm','releaseName'),source['path'],'-n',ns,*flags)
  raise error unless status.success?
  YAML.load_stream(text).compact.each do |obj|
    cluster_scoped = %w[Namespace ClusterSecretStore ClusterPolicy ClusterRole ClusterRoleBinding CustomResourceDefinition].include?(obj['kind'])
    key = [obj['apiVersion'].split('/').first, obj['kind'], cluster_scoped ? '' : (obj.dig('metadata','namespace') || ns), obj.dig('metadata','name')]
    raise "Duplicate ownership: #{key}: #{owners[key]} / #{app.dig('metadata','name')}" if owners.key?(key)
    owners[key] = app.dig('metadata','name')
  end
end
raise 'No RabbitMQ cluster rendered' unless owners.any? { |k,v| k[1] == 'RabbitmqCluster' && v.end_with?('-rabbitmq-broker') }
raise 'Topology missing' unless owners.any? { |k,v| k[1] == 'Queue' && v.end_with?('-rabbitmq-topology') }
raise 'Policies missing' unless owners.any? { |k,v| k[1] == 'ClusterPolicy' && v.end_with?('-kyverno-policies') }
raise 'Service isolation failed' unless owners.select { |k,_| k[1] == 'Deployment' }.all? { |k,v| v == "resilient-orders-#{k[3]}" }

base = render('infra/root', {'selection'=>selection.transform_values { false }})
removed = apps.keys - base.select { |r| r['kind'] == 'Application' }.map { |r| r.dig('metadata','name') }
%w[postgres redis rabbitmq-broker rabbitmq-topology rabbitmq-operator cert-manager kyverno kyverno-policies payment-service order-service notification-service].each do |name|
  raise "Disable must remove the whole Application: #{name}" unless removed.include?("resilient-orders-#{name}")
end
bootstrap = render('infra/bootstrap')
root = bootstrap.find { |r| r['kind'] == 'Application' }
raise 'Root pruning must wait for foreground deletion' unless root.dig('spec','syncPolicy','syncOptions').include?('PrunePropagationPolicy=foreground')
raise 'PruneLast collapses deletion waves' if root.dig('spec','syncPolicy','syncOptions').include?('PruneLast=true')
raise 'Local child prune waves must remain distinct' if apps.values.select { |a| a.dig('spec','source','path').to_s.start_with?('infra/') }.any? { |a| a.dig('spec','syncPolicy','syncOptions').include?('PruneLast=true') && a.dig('spec','source','path') != 'infra/platform-operators/rabbitmq-operator' }
raise 'Root finalizer missing' unless root.dig('metadata','finalizers') == ['resources-finalizer.argocd.argoproj.io']
bootstrap.select { |r| %w[Secret AppProject].include?(r['kind']) }.each do |r|
  raise 'Bootstrap credentials/project can disappear before finalizers' unless r.dig('metadata','annotations','helm.sh/resource-policy') == 'keep'
end
raise 'Bootstrap must not own selection' if root.dig('spec','source','helm','parameters').any? { |p| p['name'].start_with?('selection.') }
raise 'Custom destroy script still invoked' if File.read('.github/workflows/codespaces-cluster-bootstrap.yml').include?('destroy-gitops') || File.read('Makefile').include?('destroy-gitops')
raise 'Terraform destroy dependency missing' unless File.read('infra/terraform/platform/main.tf').include?('depends_on = [helm_release.argocd]')
puts 'PASS: isolated ownership, complete Application removal, dependency waves, finalizers and Terraform boundary'
