
FROM eclipse-temurin:11-jre

EXPOSE 8082

ADD target/timesheet-devops-1.0.2.jar timesheet-devops-1.0.2.jar

ENTRYPOINT ["java", "-jar", "/timesheet-devops-1.0.2.jar"]
