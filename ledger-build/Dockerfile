FROM eclipse-temurin:17.0.6_10-jre-alpine
RUN addgroup --system wezvatech  && adduser -S -s /usr/sbin/nologin -G wezvatech wezvatech && mkdir -p /opt/wezva
WORKDIR /opt/wezva
COPY target/wezvatech-springboot-mysql-9739110917.jar app.jar
COPY startup.sh startup.sh
RUN chown -R wezvatech:wezvatech /opt/wezva
USER wezvatech
EXPOSE 8080
ENTRYPOINT ["./startup.sh"]
