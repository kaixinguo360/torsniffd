FROM python:3-alpine

ENV WORK_DIR=/opt/torsniff

COPY ./ "$WORK_DIR/"

RUN pip install -r "$WORK_DIR/bin/requirements.txt"

ENV PATH="$WORK_DIR/sbin:$PATH"

EXPOSE 6881

CMD "$WORK_DIR/bin/run.sh"

