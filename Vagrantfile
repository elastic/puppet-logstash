# This Vagrant file is provided as a convenience for development and
# exploratory testing of puppet-logstash. It's not used by the formal
# testing framwork, it's just for hacking.
#
# See `CONTRIBUTING.md` for details on formal testing.
puppet_code_root = '/etc/puppetlabs/code/environments/production'
module_root = "#{puppet_code_root}/modules/logstash"
manifest_dir = "#{puppet_code_root}/manifests"

Vagrant.configure(2) do |config|
  config.vm.define 'explore', autostart: false do |node|
      # node.vm.box = 'puppetlabs/debian-8.2-64-puppet'
    node.vm.box = 'bento/centos-7.8'
    node.vm.provider 'virtualbox' do |vm|
      vm.memory = 4 * 1024
    end

    # Make the Logstash module available.
    %w(manifests templates files).each do |dir|
      node.vm.synced_folder(dir, "#{module_root}/#{dir}")
    end

    # Map in a Puppet manifest that can be used for experiments.
    node.vm.synced_folder('Vagrantfile.d/manifests', "#{puppet_code_root}/manifests")

    # Prepare a puppetserver install so we can test the module in a realistic
    # way. 'puppet apply' is cool, but in reality, most people need this to work
    # in a master/agent configuration.
    node.vm.provision('shell', path: 'Vagrantfile.d/server.sh')
  end

  config.vm.define 'test', autostart: false do |node|
    node.vm.box = 'bento/centos-7.8'
    node.vm.provider 'virtualbox' do |vm|
      vm.memory = 4 *
      vm.cpus = 2
    end

    node.vm.synced_folder ".", "/vagrant",
    type: "rsync",
    rsync__args: ["--verbose", "--archive", "--delete", "-z", "-l"],
    rsync__exclude: [
      "Gemfile.lock",
    ]

    node.vm.provision "shell", privileged: false, inline: <<-SHELL
      # git
      rpm -q --quiet git || sudo yum -y install git

      # rbenv
      if [[ ! -d ~/.rbenv ]] ; then
        git clone https://github.com/rbenv/rbenv.git ~/.rbenv
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$(rbenv init -)"' >> ~/.bash_profile
        echo 'eval "$(rbenv init -)"' >> ~/.bashrc
        source ~/.bash_profile
        mkdir -p "$(rbenv root)"/plugins
        git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
        sudo yum install -y gcc bzip2 openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel gdbm-devel ncurses-devel
        # install the same ruby version as pdk
        # See pdk install later in this file
        rbenv install 2.5.8
        rbenv global 2.5.8
      fi

      # beaker native extentions need this
      rpm -q --quiet gcc-c++ || sudo yum -y install gcc-c++

      # bundler
      # version has to be the same as bundled with pdk
        # See pdk install later in this file
        gem list | grep -q bundler || gem install bundler -v 1.17.3

      # docker
      if ! rpm -q --quiet docker-ce ; then
        sudo yum install -y yum-utils device-mapper-persistent-data lvm2
        sudo yum-config-manager --add-repo  https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker $USER
      fi

      # pdk
      if ! rpm -q --quiet pdk ; then
        sudo rpm -U https://yum.puppet.com/puppet6-release-el-7.noarch.rpm
        sudo yum install -y pdk-1.18.1.0
      fi
    SHELL
  end
end
