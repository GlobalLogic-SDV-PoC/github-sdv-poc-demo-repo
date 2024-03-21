FROM alpine:3.18

RUN apk add --update --no-cache python3 && \
    python3 -m ensurepip && \
    rm -r /usr/lib/python*/ensurepip && \
    pip3 install --upgrade pip && \
    pip3 install ansible-core boto3 && \
    rm -r /root/.cache && \
    ansible-galaxy collection install amazon.aws

WORKDIR /app

COPY . .

ENTRYPOINT [ "ansible-playbook" ]
CMD [ "playbook.yml", "--extra-vars", ""subnet_id=${subnet_id} project_name=${project_name} state=${state}"" ]