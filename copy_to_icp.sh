
config=/home/ubuntu/.kube/config_gke
path=/home/ubuntu

namespace=prod-mt

#kubectl --kubeconfig=$config create namespace $namespace
#
#
#kubectl --kubeconfig=$config apply -f /home/ubuntu/pvc_files/icp-pgsql.yaml --namespace=$namespace
#
#kubectl --kubeconfig=$config apply -f /home/ubuntu/configmap/pgsql.yaml --namespace=$namespace
#
#kubectl --kubeconfig=$config apply -f /home/ubuntu/secret/pgsql-pass.yaml --namespace=$namespace
#
#
##Preparation step 
#
#
#kubectl --kubeconfig=$config apply -f /home/ubuntu/pre_deployment/icp-pgsql.yaml --namespace=$namespace
#
#sleep 120
#

#Copy data to temporary pod - pvc 

data=`ls /localdata/icp/prod-mt/`
pod=$(kubectl --kubeconfig=$config get -o=name deployment --namespace=$namespace | grep pg | sed "s/^.\{26\}//")
for eachfile in $data
  do
   for deployment in $(kubectl --kubeconfig=/home/ubuntu/.kube/config_gke get -o=name deployment --namespace=prod-mt | grep pg | sed "s/^.\{26\}//")
    do 
    if [ $(echo $deployment )  == $( echo $eachfile ) ];
     then 
      pod=$(kubectl --kubeconfig=$config get pod --namespace=$namespace -l app=icp-pgsql -o custom-columns=:metadata.name)
      echo $eachfile $pod
      kubectl --kubeconfig=$config --namespace=prod-mt cp /localdata/icp/prod-mt/$eachfile/. $pod:/var/lib/postgresql/data/.;
#      kubectl --kubeconfig=$config --namespace=prod-mt exec $pod "mv /var/lib/postgresql/data/data ../."
    fi;
   done
done


data=`ls /localdata/icp/prod-mt/`
pod=$(kubectl --kubeconfig=$config get -o=name deployment --namespace=$namespace | grep pg | sed "s/^.\{26\}//")
for eachfile in $data
  do
   for deployment in $(kubectl --kubeconfig=/home/ubuntu/.kube/config_gke get -o=name deployment --namespace=prod-mt | grep pg | sed "s/^.\{26\}//")
    do
    if [ $(echo $deployment )  == $( echo $eachfile ) ];
     then
      #pod=$(kubectl --kubeconfig=$config get pod --namespace=prod-mt -l app=$deployment -o custom-columns=:metadata.name)
      kubectl --kubeconfig=$config delete  deployment $deployment --namespace=$namespace; 
    fi;
   done
done



Delete deployment 
sleep 120


deployment_files=`ls /home/ubuntu/deployment_files_pgpsql/`
data=`ls /localdata/icp/prod-mt/`

for data_file in $data
  do
   for yaml_file in $deployment_files;
    do
    if [ $(echo $yaml_file | cut -f1 -d "."  )  == $( echo $data_file ) ];
     then
      #echo $each_file $eachfile
      kubectl --kubeconfig=$config apply -f /home/ubuntu/deployment_files_pgpsql/$yaml_file --namespace=$namespace;    
    fi;
   done
done
