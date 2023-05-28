module VCenterDriver

    # Functionality to import vCenter VMs into OpenNebula
    class VmmImporter < VCenterDriver::VcImporter

        def initialize(one_client, vi_client)
            super(one_client, vi_client)
            @one_class = OpenNebula::VirtualMachine
            @defaults = {}
        end

        def list(key, list)
            @list = { key => list }
        end

        def request_vnc(vc_vm)
            one_vm = vc_vm.one_item
            vnc_port = one_vm['TEMPLATE/GRAPHICS/PORT']
            elapsed_seconds = 0

            # Let's update the info to gather VNC port
            until vnc_port || elapsed_seconds > 30
                sleep(1)
                one_vm.info
                vnc_port = one_vm['TEMPLATE/GRAPHICS/PORT']
                elapsed_seconds += 1
            end

            return unless vnc_port

            extraconfig   = []
            extraconfig  += vc_vm.extraconfig_vnc
            spec_hash     = { :extraConfig => extraconfig }
            spec = RbVmomi::VIM.VirtualMachineConfigSpec(spec_hash)
            vc_vm.item.ReconfigVM_Task(:spec => spec).wait_for_completion
        end

        def build
            xml = OpenNebula::VirtualMachine.build_xml
            OpenNebula::VirtualMachine.new(xml, @one_client)
        end

        def import(selected)
            import_tmplt = selected['IMPORT_TEMPLATE']
            import_tmplt = Base64.decode64(import_tmplt) if import_tmplt
            vm_ref     = selected['DEPLOY_ID'] || selected[:wild]['DEPLOY_ID']
            vm         = selected[:one_item]   || build
            template   = selected[:template]   || import_tmplt
            template = "DEPLOY_ID = #{vm_ref}\n" + template

            # Index where start GRAPHICS block
            graphics_index = template.index('GRAPHICS = [')
            unless graphics_index.nil?
                # Index where finish GRAPHICS block
                end_of_graphics = template[graphics_index..-1].index(']') + 1

                # GRAPHICS block
                graphics_sub_string =
                    template[graphics_index, end_of_graphics]

                # GRAPHICS block with PORT removed
                # OpenNebula will asing a new not used PORT
                graphics_sub_string =
                    graphics_sub_string.gsub(/PORT(.*?),[\r\n]/, '')

                # Index where graphics block finish
                before_graphics = template[0, graphics_index]

                # Block after graphics block
                after_graphics =
                    template[graphics_index..-1][end_of_graphics..-1]

                # Template with out PORT inside GRAPHICS
                template =
                    before_graphics +
                    graphics_sub_string +
                    after_graphics
            end

            host_id    = selected[:host] || @list.keys[0]

            vc_uuid    = @vi_client.vim.serviceContent.about.instanceUuid
            vc_name    = @vi_client.vim.host
            dpool, ipool, npool, hpool = create_pools

            vc_vm = VCenterDriver::VirtualMachine.new_without_id(@vi_client,
                                                                 vm_ref)

            # clear OpenNebula attributes
            vc_vm.clear_tags

            # Importing Wild VMs with snapshots is not supported
            # https://github.com/OpenNebula/one/issues/1268
            if vc_vm.snapshots? && vc_vm.disk_keys.empty?
                raise 'Disk metadata not present and snapshots exist, '\
                      'cannot import this VM'
            end

            vname = vc_vm['name']

            type = { :object => 'VM', :id => vname }
            error, template_disks = vc_vm.import_vcenter_disks(vc_uuid, dpool,
                                                               ipool, type)
            raise error unless error.empty?

            template << template_disks

            opts = {
                :vi_client      => @vi_client,
                :vc_uuid        => vc_uuid,
                :npool          => npool,
                :hpool          => hpool,
                :vcenter        => vc_name,
                :template_moref => vm_ref,
                :vm_object      => vc_vm,
                :ipv4           => selected[:ipv4],
                :ipv6           => selected[:ipv6]
            }

            # Create images or get nics information for template
            error, template_nics, ar_ids =
                vc_vm.import_vcenter_nics(opts)
            opts = { :uuid => vc_uuid, :npool => npool, :error => error }
            Raction.delete_ars(ar_ids, opts) unless error.empty?

            template << template_nics
            template << "VCENTER_ESX_HOST = #{vc_vm['runtime.host.name']}\n"

            # Get DS_ID for the deployment, the wild VM needs a System DS
            dc_ref = vc_vm.datacenter.item._ref
            ds_ref = template.match(/^VCENTER_DS_REF *= *"(.*)" *$/)[1]

            ds_one = dpool.select do |e|
                e['TEMPLATE/TYPE'] == 'SYSTEM_DS' &&
                    e['TEMPLATE/VCENTER_DS_REF']      == ds_ref &&
                    e['TEMPLATE/VCENTER_DC_REF']      == dc_ref &&
                    e['TEMPLATE/VCENTER_INSTANCE_ID'] == vc_uuid
            end.first
            opts[:error] = "ds with ref #{ds_ref} is not imported, aborting"
            Raction.delete_ars(ar_ids, opts) unless ds_one

            rc = vm.allocate(template)
            if OpenNebula.is_error?(rc)
                Raction.delete_ars(ar_ids, opts.merge(:error => rc.message))
            end

            rc = vm.deploy(host_id, false, ds_one.id)
            if OpenNebula.is_error?(rc)
                Raction.delete_ars(ar_ids, opts.merge(:error => rc.message))
            end

            # Set reference to template disks and nics in VM template
            vc_vm.one_item = vm

            request_vnc(vc_vm)

            # Sync disks with extraConfig
            vc_vm.reference_all_disks

            vm.id
        end

    end

end
