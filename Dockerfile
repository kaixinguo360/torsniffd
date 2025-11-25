FROM python:3.11-alpine

ENV WORK_DIR=/opt/torsniff

COPY ./bin/ "$WORK_DIR/bin/"
COPY ./conf/ "$WORK_DIR/conf/"

RUN pip install -r "$WORK_DIR/bin/requirements.txt" \
    && apk add --no-cache coreutils

ENV PATH="$WORK_DIR/sbin:$PATH"

EXPOSE 6881

CMD "$WORK_DIR/bin/run.sh"

