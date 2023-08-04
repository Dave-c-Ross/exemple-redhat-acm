#!/bin/sh

MANIFEST_FILE_FOLDER="./managed_clusters/"
SCRIPT_FILE_FOLDER="./import_scripts/"

DRYRUN=true

COMMAND=$1
ARGS="${@:2}"

Help()
{
   # Display Help
   echo
   echo "ACM Import Cluster"
   echo
   echo "A utility script designed to help you create and import any kind of Kubernetes cluster into your 'Red Hat Advanced Cluster Management for Kubernetes' infrastructure without any interaction with the ACM console itself. This can be handy when you need to insert this type of action in your CI/CD pipeline for example." | fold -w 100 -s
   echo
   echo "Syntax: acm_import_cluster.sh <command> -c <cluster_name> [ -s | -f <manifests_file_path> | -o <output_script_path> ]"
   echo
   echo
   echo "commands:"
   echo "  created                                Create a new cluster from ACM, you will need to provide some"
   echo "                                         resources file using -f or they will automatically be source"
   echo "                                         from ${MANIFEST_FILE_FOLDER} folder, with file having the same"
   echo "                                         name as your cluster declared in -c."
   echo
   echo "  import                                 Create the needed resources in ACM to import an existing cluster,"
   echo "                                         and receive the import command you will need to perform on that"
   echo "                                         remote cluster while ACM is pending. You will need to provide resources"
   echo "                                         file using -f or they will be automatically source from"
   echo "                                         ${MANIFEST_FILE_FOLDER} folder, with file having the same name as your"
   echo "                                         cluster declared in -c."
   echo
   echo "  template                               Generate an import template of ManagedCluster and KlusterletAddonConfig"
   echo "                                         resources. Template will be output in ${MANIFEST_FILE_FOLDER}"
   echo "                                         if no output file is specified with -o nor -s is used"
   echo
   echo "  help                                   Display this help summary"
   echo
   echo
   echo "options:"
   echo "  -c <cluster_name>                      The name you want to give to your cluster."
   echo "  -s                          [Optional] If set, the generated objects will output in the stdout."
   echo "  -f <manifests_file_path>    [Optional] The manifest file you need to provide to generate the import. If"
   echo "                                         not set, the script will try to get the file of your cluster"
   echo "                                         name in the ./clusters repository."
   echo "  -o <output_script_path>     [Optional] The file you want the import script to be written to. If not set,"
   echo "                                         the script will generate a script file named from your clustername"
   echo "                                         in ./scripts repository."
   echo "  -h <kubeconfig_file_path>   [Optional] The cluster hub kubeconfig file to be used when importing the remote cluster"
   echo "  -k <kubeconfig_file_path>   [Optional] The remote cluster kubeconfig file to be used when importing the remote cluster"
   echo
}

# Display an error message in stderr for script to exit.
Error() #ErrorTitle #ErrorDescription #ErrorNumber
{
	ERRN=$3
	if [ -z $ERRN ]; then ERRN=-1; fi
	>&2 echo "\nError [${ERRN}] ${1}"
	if ! [ -z "$2" ]; then echo "  ${2}"; fi
	echo "\n* You may use 'acm_import_cluster.sh help' to see the help summary.\n"
	exit $ERRN
}

# Display log line in stdout only if -s is not specified
Log() #LogType #LogMessage
{
	if [ -z $SCREEN_OUTPUT ] || ! [ $SCREEN_OUTPUT = true ]; then >&2 printf '%-30s [%-10s] %s\n' "$(date)" "$1" "$2"; fi
}

SetOptions() #options $args
{
  
  while getopts "$1": opt ${2}; do
    case $opt in
      c) CLUSTER_NAME="$OPTARG"
         ;;
      f) MANAGED_CLUSTER_FILE="$OPTARG"
      ;;
      o) SCRIPT_IMPORT_FILE="$OPTARG"
      ;;
      s) SCRIPT_IMPORT_FILE="/dev/stdout"
      ;;
      k) KUBE_CONFIG="$OPTARG"
      ;;
      h) HUB_KUBE_CONFIG="$OPTARG"
      ;;
      \?) 
        Error "Invalid option -${OPTARG}."
        ;;
      :)
        Error "Option -$OPTARG requires an argument."
        ;;
    esac

    # Avoid receiving an option as value of an option
    case $OPTARG in
      -*) Error "Option $opt needs a valid argument"
      ;;
    esac

  done

  ValidateOptions ${1}
}

ValidateClusterName() #ClusterName
{
  valid='^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'
  if [[ ! "$1" =~ $valid ]]; then 
    Error "Invalide clustername" "The provided clustername does not fit kubernetes resource name restriction. Make sure it can be validated with this regex: '${valid}'"
  fi
}

ValidateOptions() #options
{
  T=$1

  for (( i = 0; i < ${#T} ; i++ )); do

    case ${T:$i:1} in
      
      c)
        ### Validate cluster name is present
        if [ -z $CLUSTER_NAME ]; then
          Error "Missing cluster name" "You must provide a cluster name using -c option." 2
        else
          Log "Info" "Generate resource for cluster ${CLUSTER_NAME}"
        fi
        ValidateClusterName $CLUSTER_NAME      
        ;;
      
      f)
        ### Validate if input has been provided
        if [ -z $MANAGED_CLUSTER_FILE ]; then 

          MANAGED_CLUSTER_FILE="${MANIFEST_FILE_FOLDER}${CLUSTER_NAME}.yaml"

          Log "Info" "No ManagedCluster manifest file has been provided using -f, let's try loading default file '${MANAGED_CLUSTER_FILE}'"
        else
          Log "Info" "User provided ManagedCluster manifest file '${MANAGED_CLUSTER_FILE}'"
        fi

        ### Validate MANAGED_CLUSTER_FILE exists
        if ! [ -f $MANAGED_CLUSTER_FILE ]; then
          Error "Managed cluster definition file (${MANAGED_CLUSTER_FILE}) is missing or does not exist." "If you provide a file path in the -f option, make sure that file exists. If you did not use -f option, make sure you have created an Openshift ACM manifest file named as your cluster name provided in -c which include ManagedCluster and KlusterletAddonConfig definitions" 2
        else
          Log "Info" "ManagedCluster manifest file '${MANAGED_CLUSTER_FILE}' exists and will be push into the current cluster"
        fi
        ;;

      o)
        ### Validate output file has been provided
        if [ -z $SCRIPT_IMPORT_FILE ]; then 

          SCRIPT_IMPORT_FILE="${SCRIPT_FILE_FOLDER}${CLUSTER_NAME}.sh"; 

          Log "Info" "No output file has been specified to create the import script using -o, let's try using default file '${SCRIPT_IMPORT_FILE}'"
        elif [ $SCRIPT_IMPORT_FILE = "/dev/stdout" ]; then
          
          Log "Info" "Option -s has been specified, the script will be output in the stdout stream. Note that all verbose and error are redirected in stderr stream, hence no noise will be added to the script if you want to inject it into a file"
        else
          Log "Info" "User provided an output file: ${SCRIPT_IMPORT_FILE}"
        fi

        ### Validate SCRIPT_IMPORT_FILE path exists
        if ! [ -e $(dirname $SCRIPT_IMPORT_FILE) ]; then
          Error "Output script path is missing or does not exist." "If you provide a file path in the -o option, make sure the path of this future file exist. The file must be generated in an existing directory. If you did not use -o option, make sure the default output directory ${SCRIPT_FILE_FOLDER} exist. The ouput script will be created in it." 2
        else
          Log "Info" "Output script directory '${SCRIPT_IMPORT_FILE}' exists"
        fi
        ;;

      k)
        if [ -z $KUBE_CONFIG ]; then
          KUBE_CONFIG=""
          Log "Info" "No KubeConfig file has been provided, when importing the remote cluster, the current context will be used"
        else
          Log "Info" "TODO: We should validate KubeFile exist ...."
          # echo $KUBE_CONFIG
          KUBE_CONFIG="--kubeconfig '${KUBE_CONFIG}'"
          # echo $KUBE_CONFIG
        fi
        ;;
      h)
        if [ -z $HUB_KUBE_CONFIG ]; then
          HUB_KUBE_CONFIG=""
          Log "Info" "No KubeConfig file has been provided for hub cluster, when importing the remote cluster, the current context will be used"
        else
          Log "Info" "TODO: We should validate Cluster Hub KubeFile exist ...."
          # echo $HUB_KUBE_CONFIG
          HUB_KUBE_CONFIG="--kubeconfig '${HUB_KUBE_CONFIG}'"
          # echo $HUB_KUBE_CONFIG
        fi
        ;;
        

      :|s) #SKIP
        ;;

      *)
        Error "INTERNAL ERROR" "${T:$i:1} is not registered has an option to validate. Please contact support." 999
        ;;
        

    esac

  done
}

ShowKuberneteContext() #kubeconfig file (with --kubeconfig)
{
  Log "Info" "oc config current-context $1"
  CURCONTX=$(oc config current-context $1)
  ERRNO=$(echo $?)
  if [ $ERRNO -ne 0 ]; then
    Log "Warning" "ERR ERR ERR"
  else
    Log "Info" "Current context is ${CURCONTX}"
  fi
}

ValidateIsClusterRunningACM()
{
  ShowKuberneteContext ${HUB_KUBE_CONFIG}
  ERRNO=$(oc get subs -n open-cluster-management advanced-cluster-management ${HUB_KUBE_CONFIG} > /dev/null 2>&1; echo $?)
  if [ $ERRNO -ne 0 ]; then
    Error "Cluster is not running Red Hat Advanced Cluster Management for Kubernetes" "Make sure the cluster your kubeconfig is pointing to is your cluster hub running ACM." 6
  fi
}

ReadCommand() #command
{

  case $1 in

    import) # Import a cluster into ACM
      SetOptions ":c:fso:k:h:" "${ARGS}"
      ValidateIsClusterRunningACM
      ImportCluster
      exit 0
      ;;
    create) # Create new cluster in ACM
      # SetOptions ":c:fso:" "${ARGS}"
      # ValidateIsClusterRunningACM
      #CreateCluster
      Error "Functionality not implemented yet" "Sorry for that" 1
      exit 0
      ;;
    template) # Generate a template file for import or creation
      SetOptions ":c:so:" "${ARGS}"
      export CLUSTER_NAME

      if [ $SCRIPT_IMPORT_FILE = "/dev/stdout" ]; then
        OP=$SCRIPT_IMPORT_FILE
      else
        OP=${MANIFEST_FILE_FOLDER}${CLUSTER_NAME}.yaml
      fi

      envsubst '$CLUSTER_NAME:$LABELS' < template.taml > $OP
      
      exit 0
      ;;
    help)
      Help
      exit 0
    ;;
    *)
      Error "Unrecognized action" "Sorry the command ${1} does not appear to be something I can handle." 5
    ;;

  esac
}

ImportCluster() 
{
  ###
  ### Create CLUSTER_NAME namespace to ship ManagedCluster and KlusterletAddonConfig in it, and retrive secrets from it
  ###
  Log "Info" "Create ${CLUSTER_NAME} namespace ..."
  ERRNO=$(oc create namespace ${CLUSTER_NAME} ${HUB_KUBE_CONFIG} > /dev/null 2>&1; echo $?)
  if [ $ERRNO -ne 0 ]; then
    Log "Warning" "An error occured while creating the namespace in your current cluster. It usually means the namespace already exists."
  fi

  ###
  ### Create ManagedCluster and KlusterletAddonConfig resources so ACM will wait for this cluster to reach out
  ###
  Log "Info" "Create ${CLUSTER_NAME} ManagedCluster and KlusterletAddonConfig resources using ${MANAGED_CLUSTER_FILE} ..."
  ERRNO=$(oc create -n ${CLUSTER_NAME} -f ${MANAGED_CLUSTER_FILE} ${HUB_KUBE_CONFIG} > /dev/null 2>&1; echo $?)
  if [ $ERRNO -ne 0 ]; then
    Log "Warning" "An error occured while creating the resources in your current cluster. It usually means the resources already exists. Let's try fething the data anyways."
    Log "Info" "Damping time 5 seconds for the ACM to generate the necessary data..."
    sleep 5
  else
    Log "Info" "The cluster ${CLUSTER_NAME} should now be in 'Pending...' state in your ACM console."
    Log "Info" "Damping time 5 seconds for the ACM to generate the necessary data..."
    sleep 5
  fi

  ###
  ### Get part of what is needed in the import script, the CRDS file, to be inject in the remote cluster
  ###
  Log "Info" "Extract CRDS data ..."
  CRDS=$(oc get secret -n ${CLUSTER_NAME} ${CLUSTER_NAME}-import -o json ${HUB_KUBE_CONFIG} 2>&1)
  ERRNO=$(echo $?)
  if [ $ERRNO -ne 0 ]; then
    Log "Error" "An error occured while fetching CRDS data. Make sure the cluster you running the script againts is your HUB cluster, and not the cluster you want to import. If your current cluster is the HUB cluster, something else is preventing this script to perform OC command. They error was: [${CRDS}]"

    Error "Error fetching data on your cluster..." "An error occured while fetching CRDS data. Make sure the cluster you running the script againts is your HUB cluster, and not the cluster you want to import. If your current cluster is the HUB cluster, something else is preventing this script to perform OC command. They error was: [${CRDS}]" 3
  fi
  CRDS=$(echo $CRDS | jq -r '.data."crds.yaml"')

  ###
  ### Get part of what is needed in the import script, the IMPORT file, to be inject in the remote cluster
  ###
  Log "Info" "Extract IMPORT data ..."
  IMPORT=$(oc get secret -n ${CLUSTER_NAME} ${CLUSTER_NAME}-import -o json ${HUB_KUBE_CONFIG} 2>&1)
  ERRNO=$(echo $?)
  if [ $ERRNO -ne 0 ]; then
    Log "Error" "An error occured while fetching IMPORT data. Make sure the cluster you running the script againts is your HUB cluster, and not the cluster you want to import. If your current cluster is the HUB cluster, something else is preventing this script to perform OC command. They error was: [${IMPORT}]"

    Error "Error fetching data on your cluster..." "An error occured while fetching IMPORT data. Make sure the cluster you running the script againts is your HUB cluster, and not the cluster you want to import. If your current cluster is the HUB cluster, something else is preventing this script to perform OC command. They error was: [${IMPORT}]" 3
  fi
  IMPORT=$(echo $IMPORT | jq -r '.data."import.yaml"')


  ###
  ### Add the warning message if CRDS already exist and wrapup by writting the import script.
  ###
  Log "Info" "Generating import script into ${SCRIPT_IMPORT_FILE} ..."
  printf "#!/bin/sh\necho \"${CRDS}\" | base64 -d | kubectl create $KUBE_CONFIG -f - || test \$? -eq 0 && sleep 2 && echo \"${IMPORT}\" | base64 -d | kubectl apply $KUBE_CONFIG -f - || echo \"VGhlIGNsdXN0ZXIgY2Fubm90IGJlIGltcG9ydGVkIGJlY2F1c2UgaXRzIEtsdXN0ZXJsZXQgQ1JEIGFscmVhZHkgZXhpc3RzLgpFaXRoZXIgdGhlIGNsdXN0ZXIgd2FzIGFscmVhZHkgaW1wb3J0ZWQsIG9yIGl0IHdhcyBub3QgZGV0YWNoZWQgY29tcGxldGVseSBkdXJpbmcgYSBwcmV2aW91cyBkZXRhY2ggcHJvY2Vzcy4KRGV0YWNoIHRoZSBleGlzdGluZyBjbHVzdGVyIGJlZm9yZSB0cnlpbmcgdGhlIGltcG9ydCBhZ2Fpbi4=\" | base64 -d" > $SCRIPT_IMPORT_FILE

  if [ $SCRIPT_IMPORT_FILE = "/dev/stdout" ]; then
    Log "Info" "Printing the import script in stdout ..."
  else
    Log "Info" "The import script is ready and has been created in ${SCRIPT_IMPORT_FILE}."
    Log "Info" "Changing mode file on ${SCRIPT_IMPORT_FILE} to 755"
    chmod 755 ${SCRIPT_IMPORT_FILE}
  fi

  Log "Info" "You may now change OC cli context to point on your remote cluster, and run the import script."
}

main()
{
  ReadCommand $COMMAND
}

main

exit 0
