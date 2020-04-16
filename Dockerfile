FROM maven:3.6.3-jdk-8 as build

WORKDIR /home/application

COPY . .

RUN mvn clean package

# Final Stage
FROM tomcat:jdk8-openjdk

COPY --from=build /home/application/target/clickCount.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080
