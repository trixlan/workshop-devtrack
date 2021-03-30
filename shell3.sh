echo Comenzamos con la ejecución del workshop
date 

# Moverse a la carpeta root para comenzar a trabajar
cd $CHE_PROJECTS_ROOT

# Clonar el repositorio
git clone https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2m4-labs.git

# Moverse a la dirección correcta del git y traerla la versión que funciona para ocp-4.5
cd $CHE_PROJECTS_ROOT/cloud-native-workshop-v2m4-labs && git checkout ocp-4.5


# Logearse a Openshift con el user correcto
oc login -u $CHE_WORKSPACE_NAMESPACE -p r3dh4t1! https://$KUBERNETES_PORT_443_TCP_ADDR:$KUBERNETES_PORT_443_TCP_PORT --insecure-skip-tls-verify 

# Moverse al proyecto correcto en OpenShift
oc project $CHE_WORKSPACE_NAMESPACE-cloudnativeapps

echo Comenzamos con la creación de Inventario
date 

# Esta sección no se ejecuta, ya que es solo para demostrar dentro de CHE
# mvn quarkus:dev -f $CHE_PROJECTS_ROOT/cloud-native-workshop-v2m4-labs/inventory-service

# Se agregan la extensión de quarkus para jdbc-postgresql
mvn -q quarkus:add-extension -Dextensions="jdbc-postgresql" -f $CHE_PROJECTS_ROOT/cloud-native-workshop-v2m4-labs/inventory-service

# Crear la base de datos de postgre
oc process openshift//postgresql-ephemeral \
    -p NAMESPACE=openshift \
    -p DATABASE_SERVICE_NAME=inventory-database \
    -p POSTGRESQL_USER=inventory \
    -p POSTGRESQL_PASSWORD=mysecretpassword \
    -p POSTGRESQL_DATABASE=inventory \
    -p POSTGRESQL_VERSION=10 \
    | oc create -f -

# Crear la aplicación inventory-service
mvn clean compile package -DskipTests -f $CHE_PROJECTS_ROOT/cloud-native-workshop-v2m4-labs/inventory-service

# Hacer rollout a la última versión
oc rollout status -w dc/inventory

# Hacer el agrupamiento de los componentes con los labels y anotates
oc label dc/inventory app.kubernetes.io/part-of=inventory --overwrite && \
oc label dc/inventory-database app.kubernetes.io/part-of=inventory app.openshift.io/runtime=postgresql --overwrite && \
oc annotate dc/inventory app.openshift.io/connects-to=inventory-database --overwrite && \
oc annotate dc/inventory app.openshift.io/vcs-ref=ocp-4.5 --overwrite

echo Comenzamos con la creación de Catálogo
date 

# Generar el paquete de Catálogo con SpringBoot
mvn clean package spring-boot:repackage -DskipTests -f $CHE_PROJECTS_ROOT/cloud-native-workshop-v2m4-labs/catalog-service

# Crear la base de datos de postgre
oc process openshift//postgresql-ephemeral \
    -p NAMESPACE=openshift \
    -p DATABASE_SERVICE_NAME=catalog-database \
    -p POSTGRESQL_USER=catalog \
    -p POSTGRESQL_PASSWORD=mysecretpassword \
    -p POSTGRESQL_DATABASE=catalog \
    -p POSTGRESQL_VERSION=10 \
    | oc create -f -

# Crear el build desde un binario
oc new-build registry.access.redhat.com/ubi8/openjdk-11 --binary --name=catalog -l app=catalog

# Ejecutar el Build desde el generado
oc start-build catalog --from-file=$CHE_PROJECTS_ROOT/cloud-native-workshop-v2m4-labs/catalog-service/target/catalog-1.0.0-SNAPSHOT.jar --follow

# Crear la aplicación desde el build
oc new-app catalog --as-deployment-config -e JAVA_OPTS_APPEND='-Dspring.profiles.active=openshift' && oc expose service catalog

# Hacer el agrupamiento de los componentes con los labels y anotates
oc label dc/catalog app.kubernetes.io/part-of=catalog app.openshift.io/runtime=spring --overwrite && \
oc label dc/catalog-database app.kubernetes.io/part-of=catalog app.openshift.io/runtime=postgresql --overwrite && \
oc annotate dc/catalog app.openshift.io/connects-to=inventory,catalog-database --overwrite && \
oc annotate dc/catalog app.openshift.io/vcs-uri=https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2m4-labs.git --overwrite && \
oc annotate dc/catalog app.openshift.io/vcs-ref=ocp-4.5 --overwrite

echo Comenzamos con la creación de la base de datos cache
date 

# Crear la base de datos 
oc new-app --as-deployment-config infinispan/server:12.0.0.Final-1 --name=datagrid-service -e USER=user -e PASS=pass

# Crear clase CartContectInitilizer.java
rm ./cart-service/src/main/java/com/redhat/cloudnative/model/CartContectInitilizer.java && \
cat <<EOF >>./cart-service/src/main/java/com/redhat/cloudnative/model/CartContectInitilizer.java
package com.redhat.cloudnative.model;

import org.infinispan.protostream.SerializationContextInitializer;
import org.infinispan.protostream.annotations.AutoProtoSchemaBuilder;

@AutoProtoSchemaBuilder (includeClasses = {ShoppingCart.class, ShoppingCartItem.class, Promotion.class, Product.class }, schemaPackageName = "coolstore")
interface CartContextInitializer extends SerializationContextInitializer {

}
EOF

# Cambiar el TODO en el archivo para el Inject
sed -i 's/TODO Inject RemoteCache/TODO Realizado Inject RemoteCache \n\t@Inject\n\t@Remote(CacheService.CART_CACHE)\n\tRemoteCache<String, ShoppingCart> carts;/g' ./cart-service/src/main/java/com/redhat/cloudnative/service/ShoppingCartServiceImpl.java

# Cambiar el TODO en el archivo para el Cart
sed -i 's/TODO ADD getCart method/TODO Realizado ADD getCart method\n\tpublic ShoppingCart getCart(@PathParam("cartId") String cartId) {\n\t\treturn shoppingCartService.getShoppingCart(cartId);\n\t}/g' ./cart-service/src/main/java/com/redhat/cloudnative/CartResource.java

# Agregar las extensión de OpenShift
mvn -q quarkus:add-extension -Dextensions="openshift" -f $CHE_PROJECTS_ROOT/cloud-native-workshop-v2m4-labs/cart-service

# Cambiar el TODO en el archivo los properties
sed -i 's/TODO: Add for OpenShift extension/TODO: Realizado Add for OpenShift extension\nquarkus.kubernetes-client.trust-certs=true\nquarkus.container-image.build=true\nquarkus.kubernetes.deploy=true\nquarkus.kubernetes.deployment-target=openshift\nquarkus.openshift.expose=true\nquarkus.openshift.labels.app.openshift.io\/runtime=quarkus/g' ./cart-service/src/main/resources/application.properties

# Deploy de la aplicación
mvn clean package -DskipTests -f $CHE_PROJECTS_ROOT/cloud-native-workshop-v2m4-labs/cart-service

# Rollout del cart service
oc rollout status -w dc/cart

# Hacer el agrupamiento de los componentes con los labels y anotates
oc label dc/cart app.kubernetes.io/part-of=cart app.openshift.io/runtime=quarkus --overwrite && \
oc label dc/datagrid-service app.kubernetes.io/part-of=cart app.openshift.io/runtime=datagrid --overwrite && \
oc annotate dc/cart app.openshift.io/connects-to=catalog,datagrid-service --overwrite && \
oc annotate dc/cart app.openshift.io/vcs-ref=ocp-4.5 --overwrite


echo Comenzamos con la creación del order services
date 

# Se agrega la extensión 
mvn -q quarkus:add-extension -Dextensions="resteasy-jsonb,mongodb-client" -f $CHE_PROJECTS_ROOT/cloud-native-workshop-v2m4-labs/order-service

# Agregar el código en OrderService
rm ./order-service/src/main/java/com/redhat/cloudnative/OrderService.java && \
cat <<EOF >>./order-service/src/main/java/com/redhat/cloudnative/OrderService.java
package com.redhat.cloudnative;

import java.util.ArrayList;
import java.util.List;

import javax.enterprise.context.ApplicationScoped;
import javax.inject.Inject;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoCursor;
import org.bson.Document;

@ApplicationScoped
public class OrderService {

    // TODO: Inject MongoClient here
    @Inject MongoClient mongoClient;

    public List<Order> list(){

        List<Order> list = new ArrayList<>();

        // TODO: Add a while loop to make an order lists using MongoCursor here
        MongoCursor<Document> cursor = getCollection().find().iterator();

        try {
            while (cursor.hasNext()) {
                Document document = cursor.next();
                Order order = new Order();
                order.setOrderId(document.getString("orderId"));
                order.setName(document.getString("name"));
                order.setTotal(document.getString("total"));
                order.setCcNumber(document.getString("ccNumber"));
                order.setCcExp(document.getString("ccExp"));
                order.setBillingAddress(document.getString("billingAddress"));
                order.setStatus(document.getString("status"));
                list.add(order);
            }
        } finally {
            cursor.close();
        }

        return list;
    }

    public void add(Order order){

        // TODO: Add to create a Document based order here
        Document document = new Document()
                .append("orderId", order.getOrderId())
                .append("name", order.getName())
                .append("total", order.getTotal())
                .append("ccNumber", order.getCcNumber())
                .append("ccExp", order.getCcExp())
                .append("billingAddress", order.getBillingAddress())
                .append("status", order.getStatus());
        getCollection().insertOne(document);

    }

    public void updateStatus(String orderId, String status){
        Document searchQuery = new Document("orderId", orderId);
        Document newValue = new Document("status", status);
        Document updateOperationDoc = new Document("$set", newValue);
        getCollection().updateOne(searchQuery, updateOperationDoc);
    }

    private MongoCollection<Document> getCollection(){
        return mongoClient.getDatabase("order").getCollection("order");
    }
}
EOF

# Agregar el código en OrderResource
rm ./order-service/src/main/java/com/redhat/cloudnative/OrderResource.java && \
cat <<EOF >>./order-service/src/main/java/com/redhat/cloudnative/OrderResource.java
package com.redhat.cloudnative;

import java.util.List;

import javax.inject.Inject;
import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.PathParam;

// TODO: Add JAX-RS annotations here
@Path("/api/orders")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class OrderResource {

    // TODO: Inject OrderService here
    @Inject OrderService orderService;

    // TODO: Add list(), add(), updateStatus() methods here
    @GET
    public List<Order> list() {
        return orderService.list();
    }

    @POST
    public List<Order> add(Order order) {
        orderService.add(order);
        return list();
    }

    @GET
    @Path("/{orderId}/{status}")
    public List<Order> updateStatus(@PathParam("orderId") String orderId, @PathParam("status") String status) {
        orderService.updateStatus(orderId, status);
        return list();
    }
    
}
EOF

# Cambiar el TODO en el archivo los properties
sed -i 's/TODO: Add for MongoDB configuration/TODO: Realizado Add for MongoDB configuration\nquarkus.mongodb.connection-string = mongodb:\/\/order-database:27017/g' ./order-service/src/main/resources/application.properties

# Agregar el código en OrderResource
rm ./order-service/src/main/java/com/redhat/cloudnative/codec/OrderCodec.java && \
cat <<EOF >>./order-service/src/main/java/com/redhat/cloudnative/codec/OrderCodec.java
package com.redhat.cloudnative.codec;

import com.mongodb.MongoClientSettings;
import com.redhat.cloudnative.Order;
import org.bson.*;
import org.bson.codecs.Codec;
import org.bson.codecs.CollectibleCodec;
import org.bson.codecs.DecoderContext;
import org.bson.codecs.EncoderContext;

import java.util.UUID;

public class OrderCodec implements CollectibleCodec<Order> {

    private final Codec<Document> documentCodec;

    public OrderCodec() {
        this.documentCodec = MongoClientSettings.getDefaultCodecRegistry().get(Document.class);
    }
   
    // TODO: Add Encode & Decode contexts here
    @Override
    public void encode(BsonWriter writer, Order Order, EncoderContext encoderContext) {
        Document doc = new Document();
        doc.put("orderId", Order.getOrderId());
        doc.put("name", Order.getName());
        doc.put("total", Order.getTotal());
        doc.put("ccNumber", Order.getCcNumber());
        doc.put("ccExp", Order.getCcExp());
        doc.put("billingAddress", Order.getBillingAddress());
        doc.put("status", Order.getStatus());
        documentCodec.encode(writer, doc, encoderContext);
    }

    @Override
    public Class<Order> getEncoderClass() {
        return Order.class;
    }

    @Override
    public Order generateIdIfAbsentFromDocument(Order document) {
        if (!documentHasId(document)) {
            document.setOrderId(UUID.randomUUID().toString());
        }
        return document;
    }

    @Override
    public boolean documentHasId(Order document) {
        return document.getOrderId() != null;
    }

    @Override
    public BsonValue getDocumentId(Order document) {
        return new BsonString(document.getOrderId());
    }

    @Override
    public Order decode(BsonReader reader, DecoderContext decoderContext) {
        Document document = documentCodec.decode(reader, decoderContext);
        Order order = new Order();
        if (document.getString("orderId") != null) {
            order.setOrderId(document.getString("orderId"));
        }
        order.setName(document.getString("name"));
        order.setTotal(document.getString("total"));
        order.setCcNumber(document.getString("ccNumber"));
        order.setCcExp(document.getString("ccExp"));
        order.setBillingAddress(document.getString("billingAddress"));
        order.setStatus(document.getString("status"));
        return order;
    }    
    
}
EOF

# Agregar el código en OrderResource
rm ./order-service/src/main/java/com/redhat/cloudnative/codec/OrderCodecProvider.java && \
cat <<EOF >>./order-service/src/main/java/com/redhat/cloudnative/codec/OrderCodecProvider.java
package com.redhat.cloudnative.codec;

import com.redhat.cloudnative.Order;
import org.bson.codecs.Codec;
import org.bson.codecs.configuration.CodecProvider;
import org.bson.codecs.configuration.CodecRegistry;

public class OrderCodecProvider implements CodecProvider {

    // TODO: Add Codec get method here
    @Override
    public <T> Codec<T> get(Class<T> clazz, CodecRegistry registry) {
        if (clazz == Order.class) {
            return (Codec<T>) new OrderCodec();
        }
        return null;
    }

}
EOF

# Agregar el código en OrderResource
rm ./order-service/src/main/java/com/redhat/cloudnative/CodecOrderService.java && \
cat <<EOF >>./order-service/src/main/java/com/redhat/cloudnative/CodecOrderService.java
package com.redhat.cloudnative;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoCursor;

import javax.enterprise.context.ApplicationScoped;
import javax.inject.Inject;
import java.util.ArrayList;
import java.util.List;

@ApplicationScoped
public class CodecOrderService {

    @Inject MongoClient mongoClient;

    public List<Order> list(){
        List<Order> list = new ArrayList<>();
        MongoCursor<Order> cursor = getCollection().find().iterator();

        try {
            while (cursor.hasNext()) {
                list.add(cursor.next());
            }
        } finally {
            cursor.close();
        }
        return list;
    }

    public void add(Order order){
        getCollection().insertOne(order);
    }

    // TODO: Add MongoCollection method here
    private MongoCollection<Order> getCollection(){
        return mongoClient.getDatabase("order").getCollection("order", Order.class);
    }
    
}
EOF

# Hacer el deploy de la base de datos MongoDB
oc new-app --as-deployment-config -n user40-cloudnativeapps --docker-image mongo:4.0 --name=order-database

# Hacer el paquete de Order
mvn clean package -DskipTests -f $CHE_PROJECTS_ROOT/cloud-native-workshop-v2m4-labs/order-service

# Hacer el rollout con la última versión del aplicativo
oc rollout status -w dc/order

# Hacer el agrupamiento de los componentes con los labels y anotates
oc label dc/order app.kubernetes.io/part-of=order --overwrite && \
oc label dc/order-database app.kubernetes.io/part-of=order app.openshift.io/runtime=mongodb --overwrite && \
oc annotate dc/order app.openshift.io/connects-to=order-database --overwrite && \
oc annotate dc/order app.openshift.io/vcs-ref=ocp-4.5 --overwrite

# Prueba de funcionamiento con datos vacios
curl -s http://order-user40-cloudnativeapps.apps.cluster-1176.1176.sandbox9.opentlc.com/api/orders | jq


echo Comenzamos con la creación del order services
date 

# Se agrega la extensión 
cd $CHE_PROJECTS_ROOT/cloud-native-workshop-v2m4-labs/coolstore-ui && npm install --save-dev nodeshift

# Desplegar la aplicación de NodeJs
npm run nodeshift && oc expose svc/coolstore-ui && \
oc label dc/coolstore-ui app.kubernetes.io/part-of=coolstore --overwrite && \
oc annotate dc/coolstore-ui app.openshift.io/connects-to=order-cart,catalog,inventory,order --overwrite && \
oc annotate dc/coolstore-ui app.openshift.io/vcs-uri=https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2m4-labs.git --overwrite && \
oc annotate dc/coolstore-ui app.openshift.io/vcs-ref=ocp-4.5 --overwrite

echo Fin Hasta el ejercicio 3
date 