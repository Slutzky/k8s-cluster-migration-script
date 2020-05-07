
config=/home/ubuntu/.kube/config_gke
path=/home/ubuntu

namespace=prod-mt

kubectl --kubeconfig=$config create namespace $namespace


kubectl --kubeconfig=$config create clusterrolebinding dev-cluster-admin --clusterrole cluster-admin --serviceaccount dev:default


pvc=`ls /home/ubuntu/pvc_files/`
for eachfile in $pvc
do
   kubectl --kubeconfig=$config apply -f /home/ubuntu/pvc_files/$eachfile --namespace=$namespace
done

configmap=`ls /home/ubuntu/configmap/`
for eachfile in $configmap
do
   kubectl --kubeconfig=$config apply -f /home/ubuntu/configmap/$eachfile --namespace=$namespace
done

secret=`ls /home/ubuntu/secret/`
for eachfile in $secret
do
   kubectl --kubeconfig=$config apply -f /home/ubuntu/secret/$eachfile --namespace=$namespace
done


#Preparation step 


deployment_files=`ls /home/ubuntu/pre_deployment/`
data=`ls /localdata/icp/prod-mt/`

for data_file in $data
  do
   for yaml_file in $deployment_files;
    do
    if [ $(echo $yaml_file | cut -f1 -d "."  )  == $( echo $data_file ) ];
     then
      kubectl --kubeconfig=$config apply -f /home/ubuntu/pre_deployment/$yaml_file --namespace=$namespace
    fi;
   done
done


sleep 120


#Copy data to temporary pod - pvc 

data=`ls /localdata/icp/prod-mt/`
pod=$(kubectl --kubeconfig=$config get -o=name deployment --namespace=$namespace | grep n4j- | sed "s/^.\{22\}//")
for eachfile in $data
  do
   for deployment in $(kubectl --kubeconfig=$config get deployment --namespace=$namespace -o json| jq -r '.items[].metadata.name'); 
    do 
    if [ $(echo $deployment )  == $( echo $eachfile ) ];
     then 
      pod=$(kubectl --kubeconfig=$config get pod --namespace=prod-mt -l app=$deployment -o custom-columns=:metadata.name)
      echo $eachfile $pod
      kubectl --kubeconfig=$config --namespace=prod-mt cp /localdata/icp/prod-mt/$eachfile/graph.db $pod:/data/.;
    fi;
   done
done


data=`ls /localdata/icp/prod-mt/`
pod=$(kubectl --kubeconfig=$config get -o=name deployment --namespace=$namespace | grep n4j- | sed "s/^.\{22\}//")

for eachfile in $data
  do
   for deployment in $(kubectl --kubeconfig=$config get deployment --namespace=$namespace -o json| jq -r '.items[].metadata.name');
    do
    if [ $(echo $deployment )  == $( echo $eachfile ) ];
     then
      #pod=$(kubectl --kubeconfig=$config get pod --namespace=prod-mt -l app=$deployment -o custom-columns=:metadata.name)
      kubectl --kubeconfig=$config delete  deployment $deployment --namespace=$namespace; 
    fi;
   done
done



#Delete deployment 
sleep 120


deployment_files=`ls /home/ubuntu/deployment_files/`
data=`ls /localdata/icp/prod-mt/`

for data_file in $data
  do
   for yaml_file in $deployment_files;
    do
    if [ $(echo $yaml_file | cut -f1 -d "."  )  == $( echo $data_file ) ];
     then
      #echo $each_file $eachfile
      kubectl --kubeconfig=$config apply -f /home/ubuntu/deployment_files/$yaml_file --namespace=$namespace;    
    fi;
   done
done
