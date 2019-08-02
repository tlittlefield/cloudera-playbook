#!/bin/bash

#
# Setup the .ansible.cfg file
#

# make sure we aren't running in /etc
if [[ $PWD == '/etc' ]]
then
    echo "Error, cannot run from /etc directory, exiting."
    exit 1
fi

# Check to see if host_key_checking is set to False
#grep -q host_key_checking ~/.ansible.cfg
#if [[ $? -ne 0 ]]
#then
    #printf "[defaults]\nhost_key_checking = False\n" >> ~/.ansible.cfg
#fi
#
# Check to see if host_key_checking is set to False
#grep -q scp_if_ssh ~/.ansible.cfg
#if [[ $? -ne 0 ]]
#then
    #printf "[ssh_connection]\nscp_if_ssh = True\n" >> ~/.ansible.cfg
#fi

printf "[defaults]\nhost_key_checking = False\n" >  ~/.ansible.cfg
printf "[ssh_connection]\nscp_if_ssh = True\n"   >> ~/.ansible.cfg


#
# Take the contents of the /etc/hosts file we are given and write
# out the ansible hosts file
#
EdgeNodes=(`grep -i -- Edge-VM /etc/hosts | awk '{print $2}' | sort`)
NameNodes=(`grep -i -- NN-VM   /etc/hosts | awk '{print $2}' | sort`)
DataNodes=(`grep -i -- DN-VM   /etc/hosts | awk '{print $2}' | sort`)
#EdgeNodes=(`grep -i -- Edge-VM ./hosts | awk '{print $2}' | sort`)
#NameNodes=(`grep -i -- NN-VM   ./hosts | awk '{print $2}' | sort`)
#DataNodes=(`grep -i -- DN-VM   ./hosts | awk '{print $2}' | sort`)

echo "Edge"
printf '%s\n' ${EdgeNodes[@]}
echo "Name"
printf '%s\n' ${NameNodes[@]}
echo "Data"
printf '%s\n' ${DataNodes[@]}


# Now create the ansible hosts file
printf '[scm_server]\n%s        license_file=/root/cloudera_license.txt\n\n' ${NameNodes[0]} > ansible_hosts

# db_server goes on 2nd NameNode
if [[ ${#NameNodes[@]} -eq 3 ]]
then
    printf '[db_server]\n%s\n\n' ${NameNodes[1]} >> ansible_hosts
else
    printf '[db_server]\n%s\n\n' ${NameNodes[0]} >> ansible_hosts
fi

# we aren't doing a kerberos server initially, commented out
printf '[krb5_server]\n%s       default_realm=default\n\n' ${EdgeNodes[0]} >> ansible_hosts

printf '[utility_servers:children]\nscm_server\ndb_server\nkrb5_server\n\n' >> ansible_hosts

printf '[gateway_servers]\n%s        host_template=HostTemplate-Gateway role_ref_names=HDFS-HTTPFS-1\n\n' ${EdgeNodes[0]} >> ansible_hosts

printf '[master_servers]\n' >> ansible_hosts
if [[ ${#NameNodes[@]} -eq 3 ]]
then
    printf '%s  host_template=HostTemplate-Master1\n' ${NameNodes[0]} >> ansible_hosts
    printf '%s  host_template=HostTemplate-Master2\n' ${NameNodes[1]} >> ansible_hosts
    printf '%s  host_template=HostTemplate-Master3\n\n' ${NameNodes[2]} >> ansible_hosts
else
    # need to see what cloudera says if you only have 1 name node
    printf '%s  host_template=HostTemplate-Master1\n\n' ${NameNodes[0]} >> ansible_hosts
fi

printf '[worker_servers]\n' >> ansible_hosts
printf '%s\n' ${DataNodes[@]} >> ansible_hosts
printf '\n' >> ansible_hosts

cat << EOF >> ansible_hosts
[worker_servers:vars]
host_template=HostTemplate-Workers

[cdh_servers:children]
utility_servers
gateway_servers
master_servers
worker_servers

EOF

# removed since the user didn't exist on the cluster nodes
# was part of the sample config from cloudera's git repo
#[all:vars]
#ansible_user=ec2-user

