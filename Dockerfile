FROM eclipse-temurin:11-jre
COPY target/timesheet-devops-1.0.jar /app/timesheet.jar
WORKDIR /app
CMD ["java", "-jar", "timesheet.jar"]

