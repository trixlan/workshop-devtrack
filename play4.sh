#! /bin/bash
# Script para avanzar en el workshop de Dev Track
# Fecha actual
date

# Usuario con el que se ejecutaran los commandos
echo $1

# login a OpenShift
oc login -u $1 -p r3dh4t1! https://api.cluster-1176.1176.sandbox9.opentlc.com:6443 --insecure-skip-tls-verify

# Cambio al proyecto correcto
oc project $1-cloudnativeapps

# Se instala kafka
oc apply -f kafka.yaml -n $1-cloudnativeapps

# Se crean los kafka topics
oc apply -f orders.yaml -n $1-cloudnativeapps
oc apply -f payments.yaml -n $1-cloudnativeapps

echo '######## Payment Service ########'

# Se agrega la extension de Kafka
mvn -q quarkus:add-extension -Dextensions="messaging-kafka" -f payment-service

# Desplegamos la aplicacion
mvn clean package -DskipTests -f payment-service

oc rollout status -w dc/payment

# Se agrega la etiqueta
oc label dc/payment app.kubernetes.io/part-of=payment --overwrite && \
oc annotate dc/payment app.openshift.io/connects-to=my-cluster --overwrite && \
oc annotate dc/payment app.openshift.io/vcs-ref=ocp-4.5 --overwrite

export URL=http://$(oc get route -n PLEASE ENTER USERID AT TOP OF PAGE-cloudnativeapps payment -o jsonpath="{.spec.host}")

curl -i -H 'Content-Type: application/json' -X POST -d'{"orderId": "12321","total": "232.23", "creditCard": {"number": "4232454678667866","expiration": "04/22","nameOnCard": "Jane G Doe"}, "billingAddress": "123 Anystreet, Pueblo, CO 32213", "name": "Jane Doe"}' $URL

# mvn -q quarkus:add-extension -Dextensions="messaging-kafka" -f cart-service

# mvn clean package -DskipTests -DskipTests -f cart-service && \
# oc label dc/cart app.kubernetes.io/part-of=cart --overwrite &&  \
# oc annotate dc/cart app.openshift.io/connects-to=my-cluster,datagrid-service --overwrite

mvn -q quarkus:add-extension -Dextensions="messaging-kafka" -f order-service

mvn clean package -DskipTests -f order-service && \
oc label dc/order app.kubernetes.io/part-of=order --overwrite &&  \
oc annotate dc/order app.openshift.io/connects-to=my-cluster,order-database --overwrite