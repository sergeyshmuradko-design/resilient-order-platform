#!/usr/bin/env ruby
# Real temporary Git commits + real yq/jq/Helm; fake remote and Kubernetes only.
require 'tmpdir'
require 'fileutils'
require 'json'
require 'yaml'
require 'open3'

yq = ENV.fetch('YQ_BIN')
git = Open3.capture2('bash', '-c', 'command -v git').first.strip
base = YAML.load_file('infra/root/values.yaml').fetch('selection')
Dir.mktmpdir('selection-flow') do |dir|
  FileUtils.mkdir_p("#{dir}/infra/github-actions")
  FileUtils.mkdir_p("#{dir}/infra/platform-system")
  FileUtils.cp_r('infra/root', "#{dir}/infra/root")
  FileUtils.cp('infra/platform-system/values.yaml', "#{dir}/infra/platform-system/values.yaml")
  %w[apply-selection.sh selection-plan.jq].each { |f| FileUtils.cp("infra/github-actions/#{f}", "#{dir}/infra/github-actions/#{f}") }
  FileUtils.mkdir_p("#{dir}/bin")
  File.symlink(yq, "#{dir}/bin/yq")
  File.write("#{dir}/bin/git", <<~'BASH')
    #!/usr/bin/env bash
    if [ "$1" = push ] || [ "$1" = pull ]; then exit 0; fi
    exec "$REAL_GIT" "$@"
  BASH
  File.write("#{dir}/bin/kubectl", <<~'RUBY')
    #!/usr/bin/env ruby
    if ARGV.include?('wait') && ENV['FAIL_WAIT'] == 'true'
      abort 'Simulated Argo timeout'
    end
    if ARGV.include?('api-resources') && ARGV.include?('--api-group=rabbitmq.com')
      puts "users.rabbitmq.com\npermissions.rabbitmq.com\nrabbitmqclusters.rabbitmq.com"
    end
  RUBY
  File.chmod(0o755, "#{dir}/bin/git", "#{dir}/bin/kubectl")
  env = {'PATH'=>"#{dir}/bin:#{ENV.fetch('PATH')}", 'REAL_GIT'=>git, 'TARGET_BRANCH'=>'main',
         'GITHUB_STEP_SUMMARY'=>"#{dir}/summary"}
  Dir.chdir(dir) do
    [['init', '-q'], ['config','user.email','test@example.invalid'], ['config','user.name','Test'], ['add','.'], ['commit','-qm','Baseline']].each do |args|
      out, status = Open3.capture2e(git, *args)
      abort out unless status.success?
    end
    head = -> { Open3.capture2(git, 'rev-parse', 'HEAD').first.strip }
    apply = lambda do |choices, fail_wait=false|
      run_env = env.merge('COMPONENT_INPUTS'=>JSON.generate(base.transform_values { 'keep' }.merge(choices)), 'FAIL_WAIT'=>fail_wait.to_s)
      output, status = Open3.capture2e(run_env, 'bash', 'infra/github-actions/apply-selection.sh')
      raise output unless status.success? != fail_wait
      output
    end
    before = head.call
    apply.call({})
    apply.call({'enable_redis'=>'disable'})
    raise 'No-op created a commit' unless head.call == before
    apply.call({'enable_redis'=>'enable'})
    enabled = head.call
    raise 'Enable did not commit' if enabled == before
    apply.call({'enable_redis'=>'enable'})
    raise 'Repeated enable committed again' unless head.call == enabled
    apply.call({'enable_redis'=>'disable'})
    raise 'Disable failed' if YAML.load_file('infra/root/values.yaml').dig('selection','enable_redis')
    apply.call({'enable_rabbitmq_stack'=>'enable'})
    before_disable = head.call
    apply.call({'enable_rabbitmq_stack'=>'disable'}, true)
    raise 'Final state was not committed' unless YAML.load_file('infra/root/values.yaml').dig('selection','enable_rabbitmq_stack') == false
    commits = Open3.capture2(git, 'rev-list', '--count', "#{before_disable}..HEAD").first.strip
    raise 'Disable must create exactly one commit' unless commits == '1'
    committed = head.call
    apply.call({'enable_rabbitmq_stack'=>'disable'})
    raise 'Retry created another commit' unless head.call == committed
    final = YAML.load_file('infra/root/values.yaml')
    raise 'Unexpected intermediate state' if final.key?('retirement')
    raise 'Summary missing' unless File.read('summary').include?('Before (Git)')
  end
end
puts 'PASS: real Git no-op, enable, one-commit disable and retry after timeout without another commit'
