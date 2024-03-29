# syntax=docker/dockerfile:1

## Default global variables
ARG PACKAGE_NAME
ARG VERSION
ARG RELEASE_NUM=1
ARG ARCH=all

## Stage 0: Golden image
FROM debian:latest as golden

RUN apt update && apt install -y dpkg-dev curl gpg unzip && rm -rf /var/lib/apt/lists/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
  && unzip awscliv2.zip \
  && ./aws/install -i /usr/local/aws-cli -b /usr/local/bin

## Stage 1: Do packing
FROM golden as build

ARG PACKAGE_NAME
ARG VERSION
ARG RELEASE_NUM
ARG ARCH
ARG DESCRIPTION
ARG HOMEPAGE
ARG DEPS=libc6
ARG MAINTAINER_NAME=root
ARG MAINTAINER_EMAIL=root@localhost
ARG SRC_FOLDER=src
ARG DST_FOLDER=src
ARG APT_REPO_S3
ARG AWS_REGION

RUN --mount=type=secret,id=AWS_ACCESS_KEY_ID \ 
 --mount=type=secret,id=AWS_SECRET_ACCESS_KEY \ 
  aws configure set aws_access_key_id $(cat /run/secrets/AWS_ACCESS_KEY_ID) \
  && aws configure set aws_secret_access_key $(cat /run/secrets/AWS_SECRET_ACCESS_KEY) \
  && aws configure set region ${AWS_REGION} \
  && aws s3 cp s3://${APT_REPO_S3}/astemo-tools.tgz .

RUN tar -xzvf astemo-tools.tgz \
  && mkdir -p ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}/opt/ \
  && mv ./hitachiastemo-tools ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}/opt/${DST_FOLDER}

RUN find . -name ".git" -o -name ".git*" | xargs -I{} rm -rvf {};\
	mkdir -p ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}/DEBIAN && \
	echo "Package: ${PACKAGE_NAME} \n\
Provides: ${PACKAGE_NAME} (= ${VERSION}) \n\
Version: ${VERSION} \n\
Maintainer: ${MAINTAINER_NAME} <${MAINTAINER_EMAIL}> \n\
Depends: ${DEPS} \n\
Section: utils \n\
Priority: optional \n\
Architecture: ${ARCH} \n\
Homepage: ${HOMEPAGE} \n\
Installed-Size: $(( $(du -sb ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH} | awk '{print $1}') / 1024 )) \n\
Description: ${DESCRIPTION}" \
	> ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}/DEBIAN/control

### Build the package // main process (CPU consuming. BZ2 compression is slow)
RUN dpkg --build ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}
# ### Show the package information // testing if built correctly
# RUN dpkg-deb --info ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}.deb
# ### Show the package contents // testing if readable (can be large file)
# RUN dpkg-deb --contents ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}.deb


## Make a package container
FROM debian as pre_pkg

RUN apt update && apt install -y gpg curl unzip less

RUN curl -sL https://www.aptly.info/pubkey.txt | gpg --dearmor | tee /etc/apt/trusted.gpg.d/aptly.gpg >/dev/null \
  && echo "deb http://repo.aptly.info/ squeeze main" >> /etc/apt/sources.list

RUN apt-get -q update \
  && apt-get -y install aptly=1.5.0 bzip2 xz-utils gnupg gpgv libc6 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
  && unzip awscliv2.zip \
  && ./aws/install -i /usr/local/aws-cli -b /usr/local/bin

## Make a package container
FROM pre_pkg as pkg

## each ARG is MUST be defined as ENV for the container. Otherwice cannot be used in the CMD
ARG PACKAGE_NAME
ENV PACKAGE_NAME=$PACKAGE_NAME
ARG VERSION
ENV VERSION=$VERSION
ARG RELEASE_NUM
ENV RELEASE_NUM=$RELEASE_NUM
ARG ARCH
ENV ARCH=$ARCH
ARG DST_FOLDER
ARG APT_REPO_S3
ARG AWS_REGION

WORKDIR /root/

RUN --mount=type=secret,id=AWS_ACCESS_KEY_ID \ 
 --mount=type=secret,id=AWS_SECRET_ACCESS_KEY \ 
  aws configure set aws_access_key_id $(cat /run/secrets/AWS_ACCESS_KEY_ID) \
  && aws configure set aws_secret_access_key $(cat /run/secrets/AWS_SECRET_ACCESS_KEY) \
  && aws configure set region ${AWS_REGION} \
  && while [ $(aws s3api list-objects-v2 --bucket ${APT_REPO_S3} --query "contains(Contents[].Key, 'db/aptly-db.lock')") == true ]; do echo "File .lock exists" ; done

RUN touch aptly-db.lock

RUN --mount=type=secret,id=AWS_ACCESS_KEY_ID \ 
 --mount=type=secret,id=AWS_SECRET_ACCESS_KEY \ 
  aws configure set aws_access_key_id $(cat /run/secrets/AWS_ACCESS_KEY_ID) \
  && aws configure set aws_secret_access_key $(cat /run/secrets/AWS_SECRET_ACCESS_KEY) \
  && aws configure set region ${AWS_REGION} \
  && aws s3 cp aptly-db.lock s3://${APT_REPO_S3}/db/aptly-db.lock \
  && if [ $(aws s3api list-objects-v2 --bucket ${APT_REPO_S3} --query "contains(Contents[].Key, '/db/aptly-db.tar')") ]; \
  then aws s3 cp s3://${APT_REPO_S3}/db/aptly-db.tar . \
  && tar -xzvf aptly-db.tar  \
  && gpg --import --batch public.pgp private.pgp \
  && rm aptly-db.tar; fi

COPY --from=build ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}.deb /



RUN --mount=type=secret,id=AWS_ACCESS_KEY_ID \ 
 --mount=type=secret,id=AWS_SECRET_ACCESS_KEY \ 
  aws configure set aws_access_key_id $(cat /run/secrets/AWS_ACCESS_KEY_ID) \
  && aws configure set aws_secret_access_key $(cat /run/secrets/AWS_SECRET_ACCESS_KEY) \
  && aws configure set region ${AWS_REGION} \
  && if [ $(aws s3api list-objects-v2 --bucket ${APT_REPO_S3} --query "contains(Contents[].Key, '/db/aptly-db.tar')") ]; \
  then aws s3 cp s3://${APT_REPO_S3}/db/aptly-db.tar . \
  && aptly repo add apt-repo /${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}.deb \
  && aptly publish update --batch=true --gpg-key=E4427DA3 --passphrase=mykhailo stable s3:${APT_REPO_S3}:${DST_FOLDER}; \
  else aptly repo create apt-repo \
  && aptly repo add apt-repo /${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}.deb \
  && aptly publish repo --batch=true --gpg-key=E4427DA3 --passphrase=mykhailo --component=main --distribution=stable s3:${APT_REPO_S3}:${DST_FOLDER}; fi

RUN --mount=type=secret,id=AWS_ACCESS_KEY_ID \ 
 --mount=type=secret,id=AWS_SECRET_ACCESS_KEY \ 
  aws configure set aws_access_key_id $(cat /run/secrets/AWS_ACCESS_KEY_ID) \
  && aws configure set aws_secret_access_key $(cat /run/secrets/AWS_SECRET_ACCESS_KEY) \
  && aws configure set region ${AWS_REGION} \
  && tar -czvf aptly-db.tar .aptly/db .aptly.conf public.pgp private.pgp\
  && aws s3 cp aptly-db.tar s3://${APT_REPO_S3}/db/aptly-db.tar \
  && aws s3 rm s3://${APT_REPO_S3}/db/aptly-db.lock
