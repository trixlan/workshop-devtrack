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

# Ejecuta el projecto de inventory-service en la misma maquina
#mvn quarkus:dev -f inventory-service

# Se agrega la extension de jdbc
mvn -q quarkus:add-extension -Dextensions="jdbc-postgresql" -f inventory-service

echo '###################### Aplicacion de Inventory ######################'

# Se instala la base de datos de inventory
oc process openshift//postgresql-ephemeral \
    -p NAMESPACE=openshift \
    -p DATABASE_SERVICE_NAME=inventory-database \
    -p POSTGRESQL_USER=inventory \
    -p POSTGRESQL_PASSWORD=mysecretpassword \
    -p POSTGRESQL_DATABASE=inventory \
    -p POSTGRESQL_VERSION=10 \
    | oc create -f -

# Despliega la aplicacion en OpenShift
mvn clean compile package -DskipTests -f inventory-service

# Se confirma el despligue 
oc rollout status -w dc/inventory

# Se agregan los labels 
oc label dc/inventory app.kubernetes.io/part-of=inventory --overwrite && \
oc label dc/inventory-database app.kubernetes.io/part-of=inventory app.openshift.io/runtime=postgresql --overwrite && \
oc annotate dc/inventory app.openshift.io/connects-to=inventory-database --overwrite && \
oc annotate dc/inventory app.openshift.io/vcs-ref=ocp-4.5 --overwrite

# Desplegamos la app de catalog-service
mvn clean package spring-boot:repackage -DskipTests -f catalog-service

# Se instala la base de datos de catalogo
oc process openshift//postgresql-ephemeral \
    -p NAMESPACE=openshift \
    -p DATABASE_SERVICE_NAME=catalog-database \
    -p POSTGRESQL_USER=catalog \
    -p POSTGRESQL_PASSWORD=mysecretpassword \
    -p POSTGRESQL_DATABASE=catalog \
    -p POSTGRESQL_VERSION=10 \
    | oc create -f -

# Se compila la app de catalogo
echo '###################### Aplicacion de Catalogos ######################'
oc new-build registry.access.redhat.com/ubi8/openjdk-11 --binary --name=catalog -l app=catalog
oc start-build catalog --from-file=catalog-service/target/catalog-1.0.0-SNAPSHOT.jar --follow

# Se crea la nueva aplicacion
oc new-app catalog --as-deployment-config -e JAVA_OPTS_APPEND='-Dspring.profiles.active=openshift' && oc expose service catalog

# Se agregan las etiquetas
oc label dc/catalog app.kubernetes.io/part-of=catalog app.openshift.io/runtime=spring --overwrite && \
oc label dc/catalog-database app.kubernetes.io/part-of=catalog app.openshift.io/runtime=postgresql --overwrite && \
oc annotate dc/catalog app.openshift.io/connects-to=inventory,catalog-database --overwrite && \
oc annotate dc/catalog app.openshift.io/vcs-uri=https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2m4-labs.git --overwrite && \
oc annotate dc/catalog app.openshift.io/vcs-ref=ocp-4.5 --overwrite

echo '###################### Aplicacion de Cart ######################'

# Crear la base de datos 
oc new-app --as-deployment-config infinispan/server:12.0.0.Final-1 --name=datagrid-service -e USER=user -e PASS=pass

# Se agrega la extension de OpenShift
mvn -q quarkus:add-extension -Dextensions="openshift" -f cart-service

# Se despliega la aplicacion
mvn clean package -DskipTests -f cart-service

# Se verifica que se este desplegando la app
oc rollout status -w dc/cart

# Se agregan la etiquetas
oc label dc/cart app.kubernetes.io/part-of=cart app.openshift.io/runtime=quarkus --overwrite && \
oc label dc/datagrid-service app.kubernetes.io/part-of=cart app.openshift.io/runtime=datagrid --overwrite && \
oc annotate dc/cart app.openshift.io/connects-to=catalog,datagrid-service --overwrite && \
oc annotate dc/cart app.openshift.io/vcs-ref=ocp-4.5 --overwrite

echo '###################### Order Service ######################'

# Se agregan 
mvn -q quarkus:add-extension -Dextensions="resteasy-jsonb,mongodb-client" -f order-service

# Creamos la base de datos Mongo
oc new-app --as-deployment-config -n $1-cloudnativeapps --docker-image mongo:4.0 --name=order-database

# Creamos la aplicacion Order Service
mvn clean package -DskipTests -f order-service

# Validamos que este desplegada 
oc rollout status -w dc/order

# Agregamos las etiquetas
oc label dc/order app.kubernetes.io/part-of=order --overwrite && \
oc label dc/order-database app.kubernetes.io/part-of=order app.openshift.io/runtime=mongodb --overwrite && \
oc annotate dc/order app.openshift.io/connects-to=order-database --overwrite && \
oc annotate dc/order app.openshift.io/vcs-ref=ocp-4.5 --overwrite

# Se verifica la respuesta 
curl -s http://order-$1-cloudnativeapps.apps.cluster-1176.1176.sandbox9.opentlc.com/api/orders | jq

cd coolstore-ui && npm install --save-dev nodeshift

npm run nodeshift && oc expose svc/coolstore-ui && \
oc label dc/coolstore-ui app.kubernetes.io/part-of=coolstore --overwrite && \
oc annotate dc/coolstore-ui app.openshift.io/connects-to=order-cart,catalog,inventory,order --overwrite && \
oc annotate dc/coolstore-ui app.openshift.io/vcs-uri=https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2m4-labs.git --overwrite && \
oc annotate dc/coolstore-ui app.openshift.io/vcs-ref=ocp-4.5 --overwrite
