# Flutter Web demo image for laptop presentations.
#
# Build:
#   docker build --build-arg ELDERLY_CARE_CLOUD_URL=http://127.0.0.1:8000 -t elder-health-monitor:web .
#
# Run:
#   docker run --rm -p 8080:80 elder-health-monitor:web

FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG ELDERLY_CARE_CLOUD_URL=http://127.0.0.1:8000
ARG ENABLE_API_LOGS=false

RUN flutter config --enable-web \
    && flutter build web --release \
      --dart-define=ELDERLY_CARE_CLOUD_URL=${ELDERLY_CARE_CLOUD_URL} \
      --dart-define=ENABLE_API_LOGS=${ENABLE_API_LOGS}

FROM nginx:1.27-alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

