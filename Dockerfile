
FROM eclipse-temurin:11-jre

EXPOSE 8082

ADD target/timesheet-devops-1.0.11.jar timesheet-devops-1.0.11.jar

ENTRYPOINT ["java", "-jar", "/timesheet-devops-1.0.11.jar"]
