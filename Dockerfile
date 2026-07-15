FROM alpine:3.22.1@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1 AS ssh-proxy

RUN apk add --no-cache openssh-client privoxy

COPY scripts/ssh-proxy-entrypoint.sh /usr/local/bin/ssh-proxy-entrypoint
COPY scripts/privoxy.conf /etc/privoxy/config

RUN chmod 0755 /usr/local/bin/ssh-proxy-entrypoint

EXPOSE 1080 8118

ENTRYPOINT ["/usr/local/bin/ssh-proxy-entrypoint"]


FROM huanyp/ncatbot:5.5.6@sha256:a38204181be0fdbc00df51985dfa1293f150ba3e7e209f61d2c2d5fba0454197 AS ncatbot

ENV PYTHONUTF8=1 \
    PYTHONUNBUFFERED=1

WORKDIR /root/ncatbot

COPY requirements.deploy.txt /tmp/requirements.deploy.txt
RUN /root/ncatbot/.venv/bin/pip install --no-cache-dir -r /tmp/requirements.deploy.txt

COPY plugins/btd6bot_plugin /root/ncatbot/plugins/btd6bot_plugin

CMD ["/root/ncatbot/.venv/bin/ncatbot", "run", "--no-hot-reload", "--non-interactive"]
