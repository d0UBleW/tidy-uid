servers = [
  {
    hostname: 'alpine-01',
    ip: '192.168.56.201',
    box: 'generic/alpine38',
    ram: 512,
    cpu: 1,
    provision: 'init.yaml'
  },
  {
    hostname: 'alpine-02',
    ip: '192.168.56.202',
    box: 'generic/alpine38',
    ram: 512,
    cpu: 1,
    provision: 'init.yaml'
  },
  {
    hostname: 'alpine-03',
    ip: '192.168.56.203',
    box: 'generic/alpine38',
    ram: 512,
    cpu: 1,
    provision: 'init.yaml'
  },
  {
    hostname: 'alpine-04',
    ip: '192.168.56.204',
    box: 'generic/alpine38',
    ram: 512,
    cpu: 1,
    provision: 'init.yaml'
  }
]

Vagrant.configure('2') do |config|
  servers.each do |machine|
    config.vm.define machine[:hostname] do |node|
      node.vm.box = machine[:box]
      node.vm.hostname = machine[:hostname]
      node.vm.synced_folder '.', '/vargrant-data', disabled: true
      node.vm.network 'private_network', ip: machine[:ip]
      node.vm.provider 'virtualbox' do |vb|
        vb.memory = machine[:ram]
        vb.cpus = machine[:cpu]
        vb.name = machine[:hostname]
        vb.linked_clone = false
        vb.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
      end
      if machine.key?(:provision)
        node.vm.provision 'ansible' do |ansible|
          ansible.verbose = 'v'
          ansible.playbook = machine[:provision]
        end
        # puts "Provision #{machine[:hostname]}"
      end
    end
  end
end
