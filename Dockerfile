FROM alpine:latest

RUN mkdir -p /usr/share/nginx/html
ADD . /usr/share/nginx/html

VOLUME ["/usr/share/nginx/html"]
