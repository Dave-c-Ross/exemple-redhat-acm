# Import any UPI Kubernetes clusters into Red Hat Advanced Cluster Management for Kubernetes

This script is a demonstration of how to industrialize the import of a Kubernetes cluster, like Red Hat Openshift, into Red Hat Advanced Cluster Management for Kubernetes (ACM) directly from your IaaS pipeline.

A fast and easy way to create your Openshift cluster would be to use the `Create Cluster` feature of ACM which will communicate directly to your cloud provider hypervisor or your on-premise VMs or bare metal infrastructure fleet. In other use cases, you will need to create your own cluster and import the newly created or upcoming cluster into ACM, for instance, if you need to import a Microshift or Red Hat Device for Edge in the near future.


```
ACM Import Cluster

A utility script designed to help you create and import any kind of Kubernetes cluster into your 
'Red Hat Advanced Cluster Management for Kubernetes' infrastructure without any interaction with 
the ACM console itself. This can be handy when you need to insert this type of action in your CI/CD 
pipeline for example.

Syntax: acm_import_cluster.sh <command> -c <cluster_name> [ -s | -f <manifests_file_path> | -o <output_script_path> ]


commands:
  created                                Create a new cluster from ACM, you will need to provide some
                                         resources file using -f or they will automatically be source
                                         from ./managed_clusters/ folder, with file having the same
                                         name as your cluster declared in -c.

  import                                 Create the needed resources in ACM to import an existing cluster,
                                         and receive the import command you will need to perform on that
                                         remote cluster while ACM is pending. You will need to provide resources
                                         file using -f or they will be automatically source from
                                         ./managed_clusters/ folder, with file having the same name as your
                                         cluster declared in -c.

  template                               Generate an import template of ManagedCluster and KlusterletAddonConfig
                                         resources. Template will be output in ./managed_clusters/
                                         if no output file is specified with -o nor -s is used

  help                                   Display this help summary


options:
  -c <cluster_name>                      The name you want to give to your cluster.
  -s                          [Optional] If set, the generated objects will output in the stdout.
  -f <manifests_file_path>    [Optional] The manifest file you need to provide to generate the import. If
                                         not set, the script will try to get the file of your cluster
                                         name in the ./clusters repository.
  -o <output_script_path>     [Optional] The file you want the import script to be written to. If not set,
                                         the script will generate a script file named from your clustername
                                         in ./scripts repository.



```
More to come ...