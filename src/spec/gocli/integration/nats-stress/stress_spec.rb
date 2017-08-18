require_relative '../../spec_helper'
require 'fileutils'

describe 'local DNS', type: :integration do
  with_reset_sandbox_before_each(dns_enabled: false, local_dns: {'enabled' => true, 'include_index' => false})
  after(:each) do |example|
    if example.exception
        puts "------------  Dumping Agent & Nats Debug logs"
        current_sandbox.dump_debug_logs
        puts "************  Dumping Agent & Nats Debug logs END"
    end
  end

  let(:cloud_config) { Bosh::Spec::Deployments.simple_cloud_config_with_multiple_azs }
  let(:network_name) { 'local-dns' }

  before do
    cloud_config['networks'][0]['name'] = network_name
    cloud_config['compilation']['network'] = network_name
    upload_cloud_config({cloud_config_hash: cloud_config})
    upload_stemcell
    create_and_upload_test_release(force: true)
  end

  let(:ip_regexp) { /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/ }
  let(:instance_group_name) { 'job_to_test_local_dns' }
  let(:canonical_instance_group_name) { 'job-to-test-local-dns' }
  let(:deployment_name) { 'simple.local_dns' }
  let(:canonical_deployment_name) { 'simplelocal-dns' }
  let(:canonical_network_name) { 'local-dns' }

  let(:manifest_deployment) { initial_deployment(10, 5) }

  it 'deploys and downgrades with max_in_flight' do
    manifest_deployment['jobs'][0]['instances'] = 5
    deploy_simple_manifest(manifest_hash: manifest_deployment)
    etc_hosts = parse_agent_etc_hosts(4)
    expect(etc_hosts.size).to eq(5), "expected etc_hosts to have 5 lines, got contents #{etc_hosts} with size #{etc_hosts.size}"
    expect(etc_hosts).to match_array(generate_instance_dns)

    manifest_deployment['jobs'][0]['instances'] = 6
    deploy_simple_manifest(manifest_hash: manifest_deployment)
    etc_hosts = parse_agent_etc_hosts(5)
    expect(etc_hosts.size).to eq(6), "expected etc_hosts to have 6 lines, got contents #{etc_hosts} with size #{etc_hosts.size}"
    expect(etc_hosts).to match_array(generate_instance_dns)
  end

  def initial_manifest(number_of_instances, max_in_flight)
    manifest_deployment = Bosh::Spec::Deployments.test_release_manifest
    manifest_deployment.merge!(
        {
            'update' => {
                'canaries' => 2,
                'canary_watch_time' => 4000,
                'max_in_flight' => max_in_flight,
                'update_watch_time' => 20
            },

            'jobs' => [
                Bosh::Spec::Deployments.simple_job(
                    name: instance_group_name,
                    instances: number_of_instances,
                    azs: ['z1', 'z2']
                )
            ]
        })
    manifest_deployment['name'] = deployment_name
    manifest_deployment['jobs'][0]['networks'][0]['name'] = network_name
    manifest_deployment
  end

  def initial_deployment(number_of_instances, max_in_flight=1)
    manifest_deployment = initial_manifest(number_of_instances, max_in_flight)
    deploy_simple_manifest(manifest_hash: manifest_deployment)

    etc_hosts = parse_agent_etc_hosts(number_of_instances - 1)
    expect(etc_hosts.size).to eq(number_of_instances), "expected etc_hosts to have #{number_of_instances} lines, got contents #{etc_hosts} with size #{etc_hosts.size}"
    manifest_deployment
  end

  def parse_agent_etc_hosts(instance_index)
    instance = director.instance('job_to_test_local_dns', instance_index.to_s, deployment_name: deployment_name)

    instance.read_etc_hosts.lines.map do |line|
      words = line.strip.split(' ')
      {'hostname' => words[1], 'ip' => words[0]}
    end
  end

  def parse_agent_records_json(instance_index)
    instance = director.instance('job_to_test_local_dns', instance_index.to_s, deployment_name: deployment_name)
    instance.dns_records
  end

  def generate_instance_dns
    director.instances(deployment_name: deployment_name).map do |instance|
      host_name = [
          instance.id,
          canonical_instance_group_name,
          canonical_network_name,
          canonical_deployment_name,
          'bosh'
      ].join('.')
      {
          'hostname' => host_name,
          'ip' => instance.ips[0],
      }
    end
  end

  def generate_instance_records
    director.instances(deployment_name: deployment_name).map do |instance|
      [instance.ips[0], "#{instance.id}.#{canonical_instance_group_name}.#{canonical_network_name}.#{canonical_deployment_name}.bosh"]
    end
  end

  def generate_instance_record_infos
    director.instances(deployment_name: deployment_name).map do |instance|
      if instance.availability_zone.empty?
        az = nil
        az_index = nil
      else
        az = instance.availability_zone
        az_index = Regexp.new(/\d+/)
      end
      [
          instance.id,
          Bosh::Director::Canonicalizer.canonicalize(instance.job_name),
          az,
          az_index,
          Bosh::Director::Canonicalizer.canonicalize('local_dns'),
          Bosh::Director::Canonicalizer.canonicalize('simple.local_dns'),
          instance.ips[0],
          'bosh',
          instance.agent_id,
          instance.index.to_i
      ]
    end
  end

  def check_ip(ip, ips)
    case ips
      when String
        return true if ip == ips
      when Array
        return ips.include?(ip)
      else
        return false
    end
  end

  def bosh_run_cck_with_auto
    output = bosh_runner.run("cloud-check --auto", deployment_name: deployment_name)
    if $?.exitstatus != 0
      fail("Cloud check failed, output: #{output}")
    end
    output
  end
end
