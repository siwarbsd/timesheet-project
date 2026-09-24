
FROM eclipse-temurin:11-jre

EXPOSE 8082

ADD target/timesheet-devops-1.0.7.jar timesheet-devops-1.0.7.jar

ENTRYPOINT ["java", "-jar", "/timesheet-devops-1.0.7.jar"]
