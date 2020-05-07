#Set namespace to migrate


config=/home/ubuntu/.kube/config_icp

namespace=prod-mt


mkdir pvc_files_icp deployment_files_icp pre_deployment_icp



#Get all yaml file of n4j pods and copy data locally

for pod in `kubectl --kubeconfig=$config  --namespace=$namespace get pods -o=name | grep icp | sed "s/^.\{4\}//"`
do
  kubectl --kubeconfig=$config get -o=name deployment --namespace=$namespace | grep icp | sed "s/^.\{22\}//" >  pvc_icp.txt

  #kubectl cp "${pod}":/data data/$pod/. &&  kubectl get pods --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'
done



#Create PVC.yaml for each n4j pod
cat pvc_icp.txt | \
while read pvc; do
    touch pvc_files_icp/$pvc.yaml
    echo "
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
  name: "$pvc"
  namespace: "$namespace"
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: standard
" >> pvc_files_icp/$pvc.yaml

    echo "
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $pvc
  labels:
    app: $pvc
spec:
  selector:
    matchLabels:
      app: $pvc
  template:
    metadata:
      labels:
        app: $pvc
    spec:
      containers:
      - name: ubuntu
        image: ubuntu:14.04
        args: [bash, -c, 'for ((i = 0; ; i++)); do echo "$i: $(date)"; sleep 100; done']
        volumeMounts:
        - name: pgsql-persistent-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: pgsql-persistent-storage
        persistentVolumeClaim:
          claimName:  $pvc
" >> pre_deployment_icp/$pvc.yaml

done


#Get deployment yaml file of neo4j and find and replace PVC configuration
# make sure you use --export for all get to yaml bits or it will break the sed beloy potentially

for deployment in $(kubectl --kubeconfig=$config get -o=name deployment --namespace=$namespace | grep icp | sed "s/^.\{22\}//")
do
    kubectl --kubeconfig=$config get -o=yaml deployment.extensions/$deployment --namespace=$namespace --export > deployment_files_icp/$deployment.yaml

#    sed -zi 's!hostPath:\n.*path:.*/localdata/icp/'$namespace'/'$deployment'\n.*name: neo4j-data!name: neo4j-data\n        persistentVolumeClaim:\n          claimName: '$deployment'\n!g' deployment_files/$deployment.yaml

done


#for n in $(kubectl --kubeconfig=$config get -o=name  --namespace=$namespace configmap,secret)
#do
#    mkdir -p $(dirname $n)
#    kubectl --kubeconfig=$config --namespace=$namespace get -o=yaml --export $n > $n.yaml
#done

            

