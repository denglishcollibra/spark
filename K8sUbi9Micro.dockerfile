#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
FROM registry.access.redhat.com/ubi9 AS ubi-micro-build

RUN dnf install -y sed grep pcre libsigsegv && dnf clean all

FROM docker-delivery.repository.collibra.io/arch/ubi9-micro-java:17-jre-latest-multi

COPY --from=ubi-micro-build /usr/bin/sed /usr/bin/grep /usr/bin/
COPY --from=ubi-micro-build /usr/lib64/libpcre.so.1 /usr/lib64/libsigsegv.so.2 /usr/lib64/

ARG SPARK_UID=185

ENV SPARK_HOME=/opt/spark \
    TINI_VERSION=v0.19.0 \
    USER="spark" \
    UID="${SPARK_UID}"

ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini

COPY bin ${SPARK_HOME}/bin/
COPY sbin ${SPARK_HOME}/sbin/
COPY jars ${SPARK_HOME}/jars/
COPY kubernetes/dockerfiles/spark/decom.sh /opt/
COPY entrypoint.sh /opt/

RUN chmod +x /usr/bin/tini && \
    set -ex && \
    mkdir -p ${SPARK_HOME} && \
    mkdir ${SPARK_HOME}/python && \
    mkdir -p ${SPARK_HOME}/examples && \
    mkdir -p ${SPARK_HOME}/work-dir && \
    chmod g+w ${SPARK_HOME}/work-dir && \
    touch ${SPARK_HOME}/RELEASE && \
    ln -s /lib /lib64 && \
    touch ${SPARK_HOME}/RELEASE && \
    mkdir -p /etc/pam.d && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    chmod ug+rw /etc/passwd && \
    echo "${USER}:*:${UID}:${UID}:::" >> /etc/passwd && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    chown -R ${UID}:${UID} ${SPARK_HOME} && \
    cat /etc/passwd && \
    chown -R ${USER}:${UID} /opt && \
    chmod +x /opt/entrypoint.sh

USER ${USER}

WORKDIR ${SPARK_HOME}/work-dir

ENTRYPOINT [ "/opt/entrypoint.sh" ]
