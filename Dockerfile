FROM huanyp/ncatbot:latest

ENV PYTHONUTF8=1 \
    PYTHONUNBUFFERED=1

WORKDIR /root/ncatbot

COPY requirements.deploy.txt /tmp/requirements.deploy.txt
RUN /root/ncatbot/.venv/bin/pip install --no-cache-dir -r /tmp/requirements.deploy.txt

COPY plugins/btd6bot_plugin /root/ncatbot/plugins/btd6bot_plugin

CMD ["/root/ncatbot/.venv/bin/ncatbot", "run", "--no-hot-reload", "--non-interactive"]
