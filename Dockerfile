#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

#
# Dockerfile for guacamole-server
#

# Use slim Debian as base for the build
FROM debian:stable-slim AS builder

# Guacamole base (installation) directory
#
# Due to limitations of the Docker image build process, this value is
# duplicated in an ENV in the second stage of the build.
#
ENV GUAC_BASE_DIR /usr/local/guacamole

# Guacamole build directory
ENV GUAC_BUILD_DIR /tmp/guacd-docker-build

# Bring build environment up to date and install build dependencies
RUN apt-get update && apt-get install -y \
      autoconf \
      automake \
      freerdp2-dev \
      gcc \
      libcairo2-dev \
      libjpeg62-turbo-dev \
      libossp-uuid-dev \
      libpango1.0-dev \
      libpulse-dev \
      libssh2-1-dev \
      libssl-dev \
      libtelnet-dev \
      libtool \
      libvncserver-dev \
      libwebsockets-dev \
      libwebp-dev \
      make

# Add configuration scripts
COPY src/guacd-docker/bin ${GUAC_BASE_DIR}/bin/

# Copy source to container for sake of build
COPY . ${GUAC_BUILD_DIR}

# Build guacamole-server from local source
RUN ${GUAC_BASE_DIR}/bin/build-guacd.sh ${GUAC_BUILD_DIR} ${GUAC_BASE_DIR}

# Record the packages of all runtime library dependencies
RUN ${GUAC_BASE_DIR}/bin/list-dependencies.sh \
      ${GUAC_BASE_DIR}/sbin/guacd \
      ${GUAC_BASE_DIR}/lib/libguac-client-*.so \
      ${GUAC_BASE_DIR}/lib/freerdp2/libguac*.so \
    > ${GUAC_BASE_DIR}/DEPENDENCIES

# Use same slim Debian as the base for the runtime image
FROM debian:stable-slim

# Runtime environment
ENV GUAC_BASE_DIR /usr/local/guacamole
ENV LC_ALL C.UTF-8
ENV LD_LIBRARY_PATH ${GUAC_BASE_DIR}/lib
ENV GUACD_LOG_LEVEL info

# Copy build artifacts into this stage
COPY --from=builder ${GUAC_BASE_DIR} ${GUAC_BASE_DIR}

# Bring runtime environment up to date and install runtime dependencies
RUN apt-get update && apt-get install -y \
      ca-certificates \
      ghostscript \
      fonts-liberation \
      fonts-dejavu \
      xfonts-terminus \
    && apt-get install -y $(cat "${GUAC_BASE_DIR}"/DEPENDENCIES) && \
    rm -rf /var/lib/apt/lists/* && \
# Link FreeRDP plugins into proper path
    ${GUAC_BASE_DIR}/bin/link-freerdp-plugins.sh ${GUAC_BASE_DIR}/lib/freerdp2/libguac*.so

# Expose the default listener port
EXPOSE 4822

# Start guacd, listening on port 0.0.0.0:4822
CMD ${GUAC_BASE_DIR}/sbin/guacd -b 0.0.0.0 -L $GUACD_LOG_LEVEL -f
