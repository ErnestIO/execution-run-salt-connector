FROM ruby:2.3.1-alpine

RUN apk add --update git curl g++ musl-dev make && rm -rf /var/cache/apk/*

RUN mkdir -p /opt/ernest-libraries/ && cd /opt/ernest-libraries && git clone https://github.com/r3labs/salt

ADD . /opt/ernest/execution-run-salt-connector
WORKDIR /opt/ernest/execution-run-salt-connector

RUN curl https://s3-eu-west-1.amazonaws.com/ernest-tools/bash-nats -o /bin/bash-nats && chmod +x /bin/bash-nats
RUN ruby -S bundle install

ENTRYPOINT ./run.sh
