FROM docker.io/library/ubuntu:xenial

COPY init-node.sh /usr/local/bin/init-node
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN apt-get update && \
    apt-get install -y software-properties-common apt-transport-https curl && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CE7709D068DB5E88 && \
    add-apt-repository "deb https://repo.sovrin.org/deb xenial stable" && \
    apt-get update && \
    apt-get install -y sovrin && \
    sed -i -re "s/(NETWORK_NAME = ')\\w+/\\1net3/" /etc/indy/indy_config.py && \
    sed -i -re "s/(enableStdOutLogging = )\\w+/\\1True/" /etc/indy/indy_config.py && \
    mkdir -p /var/lib/indy/net3 && \
    curl -o /var/lib/indy/net3/domain_transactions_genesis https://raw.githubusercontent.com/sovrin-foundation/sovrin/master/sovrin/domain_transactions_builder_genesis && \
    curl -o /var/lib/indy/net3/pool_transactions_genesis https://raw.githubusercontent.com/sovrin-foundation/sovrin/master/sovrin/pool_transactions_builder_genesis && \
    chmod +x /usr/local/bin/init-node && \
    chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9701 9702

VOLUME /var/lib/indy

CMD ["entrypoint.sh"]
