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

# ARG AWS_ACCESS_KEY_ID
# ARG AWS_SECRET_ACCESS_KEY
# ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
# ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

# RUN export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} && export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

# RUN --mount=type=secret,id=aws,target=/root/.aws/credentials cat /root/.aws/credentials

RUN --mount=type=secret,id=aws,target=/root/.aws/credentials && aws s3 ls

RUN tar -xzvf astemo-tools.tgz \
  && mkdir -p ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}/opt/ \
  && mv ./hitachiastemo-tools ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}/opt/${DST_FOLDER}

RUN find . -name ".git" -o -name ".git*" | xargs -I{} rm -rvf {};\
	mkdir -p ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}/DEBIAN && \
	echo "Package: ${PACKAGE_NAME}-${VERSION} \n\
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

# RUN --mount=type=secret,id=aws,target=/root/.aws/credentials cat /root/.aws/credentials

# ARG AWS_ACCESS_KEY_ID
# ARG AWS_SECRET_ACCESS_KEY
# ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
# ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

# RUN export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} && export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

WORKDIR /root/

# RUN while [ $(aws s3api list-objects-v2 --bucket dev-apt-repository --query "contains(Contents[].Key, 'db/aptly-db.lock')") == true ]; do echo "File .lock exists" ; done

# RUN touch aptly-db.lock

# RUN --mount=type=secret,id=aws,target=/root/.aws/credentials && aws s3 cp aptly-db.lock s3://dev-apt-repository/db/aptly-db.lock \
#   && aws s3 cp s3://dev-apt-repository/db/aptly-db.tar .

# RUN tar -xzvf aptly-db.tar  \
#   && gpg --import --batch public.pgp private.pgp \
#   && rm aptly-db.tar


# COPY --from=build ${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}.deb /


# RUN --mount=type=secret,id=aws,target=/root/.aws/credentials && aptly repo list \
#   && aptly repo add apt-repo /${PACKAGE_NAME}_${VERSION}-${RELEASE_NUM}_${ARCH}.deb \
#   && aptly publish update --batch=true --gpg-key=E4427DA3 --passphrase=mykhailo stable s3:dev-apt-repository:tools

# RUN --mount=type=secret,id=aws,target=/root/.aws/credentials && tar -czvf aptly-db.tar .aptly/db .aptly.conf public.pgp private.pgp\
#   && aws s3 cp aptly-db.tar s3://dev-apt-repository/db/aptly-db.tar \
#   && aws s3 rm s3://dev-apt-repository/db/aptly-db.lock
