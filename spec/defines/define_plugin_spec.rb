require 'spec_helper'

describe 'logstash::plugin' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      let(:pre_condition) do
        [
          'include elastic_stack::repo',
          'include logstash',
        ]
      end

      let(:title) { 'logstash-input-mysql' }

      it { is_expected.to compile }

      it {
        is_expected.to contain_exec("install-#{title}").with(user: 'logstash')
      }
    end
  end
end
