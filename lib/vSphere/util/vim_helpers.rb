require 'rbvmomi'

module VagrantPlugins
  module VSphere
    module Util
      module VimHelpers
        def get_datacenter(connection, machine)
          connection.serviceInstance.find_datacenter(machine.provider_config.data_center_name) or fail Errors::VSphereError, :missing_datacenter
        end

        def get_vm_by_uuid(connection, machine)
          get_datacenter(connection, machine).vmFolder.findByUuid machine.id
        end

        def get_resource_pool(connection, machine)
          cr = get_datacenter(connection, machine).find_compute_resource(machine.provider_config.compute_resource_name) or fail Errors::VSphereError, :missing_compute_resource
          rp = cr.resourcePool
          if !(machine.provider_config.resource_pool_name.nil?)
            rp = cr.resourcePool.find(machine.provider_config.resource_pool_name) or  fail Errors::VSphereError, :missing_resource_pool
          end
          rp
        end

        def get_customization_spec_info_by_name(connection, machine)
          name = machine.provider_config.customization_spec_name
          return if name.nil? || name.empty?

          manager = connection.serviceContent.customizationSpecManager or fail Errors::VSphereError, :null_configuration_spec_manager if manager.nil?
          spec = manager.GetCustomizationSpec(:name => name) or fail Errors::VSphereError, :missing_configuration_spec if spec.nil?
        end

        def get_datastore(connection, machine)
          ds_name = machine.provider_config.data_store_name
          return if ds_name.nil? || ds_name.empty?

          get_datacenter(connection, machine).find_datastore name or fail Errors::VSphereError, :missing_datastore
        end

        # Inspired by https://communities.vmware.com/message/2388323
        def get_drs_datastore(connection, machine, template, clone_spec)
          dsc_name = machine.provider_config.data_store_cluster_name
          return if dsc_name.nil? || dsc_name.empty?

          dsclusters = get_datacenter(connection, machine).datastoreFolder.childEntity
          dscluster = dsclusters.find { |f| f.name == dsc_name and f.instance_of?(RbVmomi::VIM::StoragePod) } or abort "no such datastorecluster #{dsc_name}"
          return if dscluster.nil?

          storageMgr = connection.serviceContent.storageResourceManager
          podSpec = RbVmomi::VIM.StorageDrsPodSelectionSpec(:storagePod => dscluster)

          folder = machine.provider_config.vm_base_path.nil? ? template.parent : get_datacenter(connection, machine).vmFolder.traverse(machine.provider_config.vm_base_path, RbVmomi::VIM::Folder, true)
          storageSpec = RbVmomi::VIM.StoragePlacementSpec(:type => 'clone', :cloneName => "test-vm", :folder => folder, :podSelectionSpec => podSpec, :vm => template, :cloneSpec => clone_spec)

          result = storageMgr.RecommendDatastores(:storageSpec => storageSpec)
          result.recommendations[0][:action][0][:destination]
        end

        def get_network_by_name(dc, name)
          dc.network.find { |f| f.name == name } or fail Errors::VSphereError, :missing_vlan
        end
      end
    end
  end
end
