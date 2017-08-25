require_relative '../../spec_helper'

describe 'nats server', type: :integration do
  let(:vm_type) do
    {
      'name' => 'smurf-vm-type',
      'cloud_properties' => {'legacy_agent_path' => get_legacy_agent_path('before-info-endpoint-20170719')}
    }
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash.delete('resource_pools')

    cloud_config_hash['vm_types'] = [vm_type]
    cloud_config_hash
  end

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash.delete('resource_pools')
    manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]
    manifest_hash['jobs'] = [simple_job]
    manifest_hash
  end

  let(:simple_job) do
    {
      'name' => 'our_instance_group',
      'templates' => [
        {
          'name' => 'job_1_with_many_properties',
          'properties' => job_properties,
        }],
      'vm_type' => 'smurf-vm-type',
      'stemcell' => 'default',
      'instances' => 1,
      'networks' => [{'name' => 'a'}]
    }
  end

  let(:job_properties) do
    {
      'gargamel' => {
        'color' => 'GARGAMEL_COLOR_IS_NOT_BLUE'
      },
      'smurfs' => {
        'happiness_level' => 2000
      }
    }
  end

  context 'is allowing legacy clients' do
    with_reset_sandbox_before_each(nats_allow_legacy_clients: true)

    context 'and connecting agent is legacy' do
      it 'should deploy successfully' do
        puts deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: false)
      end
    end

    context 'and connecting agent is updated' do
      it 'should deploy successfully' do
        deploy_from_scratch
      end
    end
  end

  context 'is mutual TLS only' do
    with_reset_sandbox_before_each
    context 'and connecting agent is legacy' do
      it 'should fail the deployment' do
        output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true)
        expect(output).to match(/Timed out pinging to \b.+\b after \b.+\b seconds/)
      end
    end

    context 'and connecting agent is updated' do
      it 'should deploy successfully' do
        deploy_from_scratch
      end
    end
  end
end
