#Set namespace to migrate


config=/home/ubuntu/.kube/config_icp

namespace=prod-mt


mkdir pvc_files deployment_files pre_deployment



#Get all yaml file of n4j pods and copy data locally

for pod in `kubectl --kubeconfig=$config  --namespace=$namespace get pods -o=name | grep n4j- | sed "s/^.\{4\}//"`
do
  kubectl --kubeconfig=$config get -o=name deployment --namespace=$namespace | grep n4j- | sed "s/^.\{22\}//" >  pvc.txt

  #kubectl cp "${pod}":/data data/$pod/. &&  kubectl get pods --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'
done


typeset pvc=""

#Create PVC.yaml for each n4j pod
cat pvc.txt | \
while read pvc; do
    touch pvc_files/$pvc.yaml
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
      storage: 30Gi
  storageClassName: standard
" >> pvc_files/$pvc.yaml

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
        - name: neo4j-data
          mountPath: /data
      volumes:
      - name: neo4j-data
        persistentVolumeClaim:
          claimName:  $pvc
" >> pre_deployment/$pvc.yaml

done


#Get deployment yaml file of neo4j and find and replace PVC configuration
# make sure you use --export for all get to yaml bits or it will break the sed beloy potentially

for deployment in $(kubectl --kubeconfig=$config get -o=name deployment --namespace=$namespace | grep n4j- | sed "s/^.\{22\}//")
do
    kubectl --kubeconfig=$config get -o=yaml deployment.extensions/$deployment --namespace=$namespace --export > deployment_files/$deployment.yaml

    sed -zi 's!hostPath:\n.*path:.*/localdata/icp/'$namespace'/'$deployment'\n.*name: neo4j-data!name: neo4j-data\n        persistentVolumeClaim:\n          claimName: '$deployment'\n!g' deployment_files/$deployment.yaml

    sed -i '0,/neo4j-configs/s//neo4jconf/' deployment_files/$deployment.yaml

    sed -i 's!    spec:!    spec:\n      initContainers:\n      - command:\n        - /bin/sh\n        - -c\n        - cd /etc/config; for i in $(ls -1); do cat $i > /var/lib/neo4j/conf/$i; done;\n        image: busybox\n        imagePullPolicy: Always\n        name: configmap-copy\n        resources: {}\n        terminationMessagePath: /dev/termination-log\n        terminationMessagePolicy: File\n        volumeMounts:\n        - mountPath: /etc/config\n          name: neo4j-configs\n        - mountPath: /var/lib/neo4j/conf\n          name: neo4jconf\n!' deployment_files/$deployment.yaml

    sed -i 's!      volumes:!      volumes:\n      - emptyDir: {}\n        name: neo4jconf!' deployment_files/$deployment.yaml


    sed -e '/.*kubernetes.io.*hostname.*icpvm.*/d' -i deployment_files/$deployment.yaml
done


for n in $(kubectl --kubeconfig=$config get -o=name  --namespace=$namespace configmap,secret)
do
    mkdir -p $(dirname $n)
    kubectl --kubeconfig=$config --namespace=$namespace get -o=yaml --export $n > $n.yaml
done

            

