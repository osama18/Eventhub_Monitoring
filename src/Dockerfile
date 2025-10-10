# Multi-stage build: Build stage
FROM maven:3.8.6-openjdk-11 AS build

WORKDIR /app

# Copy pom.xml and source code
COPY pom.xml .
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Runtime stage
FROM openjdk:11-jre-slim

WORKDIR /app

# Copy the JAR file from build stage
COPY --from=build /app/target/eventhub-custom-metrics-emitter-1.0.0.jar app.jar

# Expose port (optional, for health checks)
EXPOSE 8080

# Set the entrypoint
ENTRYPOINT ["java", "-jar", "app.jar"]