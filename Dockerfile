ARG AIRFLOW_VERSION="2.0.0.dev0"
ARG AIRFLOW_EXTRAS="async,aws,azure,celery,dask,elasticsearch,gcp,kubernetes,mysql,postgres,redis,slack,ssh,statsd,virtualenv"
ARG ADDITIONAL_AIRFLOW_EXTRAS=""
ARG ADDITIONAL_PYTHON_DEPS="gino[starlette] fastapi uvicorn gunicorn alembic psycopg2 pytest requests uvloop "

ARG AIRFLOW_HOME=/opt/airflow
ARG AIRFLOW_UID="50000"
ARG AIRFLOW_GID="50000"

ARG CASS_DRIVER_BUILD_CONCURRENCY="8"

ARG PYTHON_BASE_IMAGE="local/centos7-python38:v2"
ARG PYTHON_MAJOR_MINOR_VERSION="3.8"

ARG PIP_VERSION=20.2.4

##############################################################################################
# This is the build image where we build all dependencies
##############################################################################################
FROM ${PYTHON_BASE_IMAGE} as airflow-build-image

USER root

ARG PYTHON_BASE_IMAGE
ENV PYTHON_BASE_IMAGE=${PYTHON_BASE_IMAGE}

ARG PYTHON_MAJOR_MINOR_VERSION
ENV PYTHON_MAJOR_MINOR_VERSION=${PYTHON_MAJOR_MINOR_VERSION}

ARG PIP_VERSION
ENV PIP_VERSION=${PIP_VERSION}

#RUN yum update -y && yum install -y epel-release \
#        && yum install -y curl tee

RUN yum install -y curl tee 

RUN yum install -y gcc-c++ make gcc openssl-devel bzip2-devel libffi-devel \
        && curl -sL https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo \
	&& yum remove -y nodejs npm \
	&& curl -sL https://rpm.nodesource.com/setup_10.x | bash - \
	&& yum install -y nodejs \
	&& yum install -y yarn 
	 
RUN yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm \
        && yum install -y postgresql10-devel


ARG INSTALL_MYSQL_CLIENT="true"
ENV INSTALL_MYSQL_CLIENT=${INSTALL_MYSQL_CLIENT}
COPY scripts/docker scripts/docker
COPY docker-context-files /docker-context-files

RUN  yum localinstall -y  https://dev.mysql.com/get/mysql80-community-release-el7-1.noarch.rpm && yum install -y mysql-community-devel

ARG DEV_APT_DEPS="\
     ca-certificates.noarch \
     gnupg2.x86_64 \
     openssh.x86_64 \
     libsqlite3x-devel.x86_64 \
     sudo"


ENV DEV_APT_DEPS=${DEV_APT_DEPS}

ARG ADDITIONAL_DEV_APT_DEPS="gino[starlette] fastapi uvicorn gunicorn alembic psycopg2 pytest requests uvloop "
ENV ADDITIONAL_DEV_APT_DEPS=${ADDITIONAL_DEV_APT_DEPS}

ARG ADDITIONAL_DEV_APT_COMMAND="echo"
ENV ADDITIONAL_DEV_APT_COMMAND=${ADDITIONAL_DEV_APT_COMMAND}

ARG ADDITIONAL_DEV_ENV_VARS=""

RUN yum install -y ${DEV_APT_DEPS}

ARG AIRFLOW_REPO=apache/airflow
ENV AIRFLOW_REPO=${AIRFLOW_REPO}

ARG AIRFLOW_BRANCH=master
ENV AIRFLOW_BRANCH=${AIRFLOW_BRANCH}

ARG AIRFLOW_EXTRAS
ARG ADDITIONAL_AIRFLOW_EXTRAS=""
ENV AIRFLOW_EXTRAS=${AIRFLOW_EXTRAS}${ADDITIONAL_AIRFLOW_EXTRAS:+,}${ADDITIONAL_AIRFLOW_EXTRAS}

ARG AIRFLOW_CONSTRAINTS_REFERENCE="constraints-master"
ARG AIRFLOW_CONSTRAINTS_LOCATION="https://raw.githubusercontent.com/apache/airflow/${AIRFLOW_CONSTRAINTS_REFERENCE}/constraints-${PYTHON_MAJOR_MINOR_VERSION}.txt"
ENV AIRFLOW_CONSTRAINTS_LOCATION=${AIRFLOW_CONSTRAINTS_LOCATION}

ENV PATH=${PATH}:/root/.local/bin
RUN mkdir -p /root/.local/bin

ARG AIRFLOW_PRE_CACHED_PIP_PACKAGES="true"
ENV AIRFLOW_PRE_CACHED_PIP_PACKAGES=${AIRFLOW_PRE_CACHED_PIP_PACKAGES}

RUN if [[ -f /docker-context-files/.pypirc ]]; then \
        cp /docker-context-files/.pypirc /root/.pypirc; \
    fi

RUN pip install --upgrade "pip==${PIP_VERSION}"

# In case of Production build image segment we want to pre-install master version of airflow
# dependencies from GitHub so that we do not have to always reinstall it from the scratch.
RUN if [[ ${AIRFLOW_PRE_CACHED_PIP_PACKAGES} == "true" ]]; then \
       if [[ ${INSTALL_MYSQL_CLIENT} != "true" ]]; then \
          AIRFLOW_EXTRAS=${AIRFLOW_EXTRAS/mysql,}; \
       fi; \
       pip install --user \
          "https://github.com/${AIRFLOW_REPO}/archive/${AIRFLOW_BRANCH}.tar.gz#egg=apache-airflow[${AIRFLOW_EXTRAS}]" \
          --constraint "${AIRFLOW_CONSTRAINTS_LOCATION}" \
          && pip uninstall --yes apache-airflow; \
    fi

ARG AIRFLOW_SOURCES_FROM="."
ENV AIRFLOW_SOURCES_FROM=${AIRFLOW_SOURCES_FROM}

ARG AIRFLOW_SOURCES_TO="/opt/airflow"
ENV AIRFLOW_SOURCES_TO=${AIRFLOW_SOURCES_TO}

COPY ${AIRFLOW_SOURCES_FROM} ${AIRFLOW_SOURCES_TO}

ARG CASS_DRIVER_BUILD_CONCURRENCY
ENV CASS_DRIVER_BUILD_CONCURRENCY=${CASS_DRIVER_BUILD_CONCURRENCY}

ARG AIRFLOW_VERSION
ENV AIRFLOW_VERSION=${AIRFLOW_VERSION}

ARG ADDITIONAL_PYTHON_DEPS=""
ENV ADDITIONAL_PYTHON_DEPS=${ADDITIONAL_PYTHON_DEPS}

ARG AIRFLOW_INSTALL_SOURCES="."
ENV AIRFLOW_INSTALL_SOURCES=${AIRFLOW_INSTALL_SOURCES}

ARG AIRFLOW_INSTALL_VERSION=""
ENV AIRFLOW_INSTALL_VERSION=${AIRFLOW_INSTALL_VERSION}

ARG AIRFLOW_LOCAL_PIP_WHEELS=""
ENV AIRFLOW_LOCAL_PIP_WHEELS=${AIRFLOW_LOCAL_PIP_WHEELS}

ARG INSTALL_AIRFLOW_VIA_PIP="true"
ENV INSTALL_AIRFLOW_VIA_PIP=${INSTALL_AIRFLOW_VIA_PIP}

ARG SLUGIFY_USES_TEXT_UNIDECODE=""
ENV SLUGIFY_USES_TEXT_UNIDECODE=${SLUGIFY_USES_TEXT_UNIDECODE}

ARG INSTALL_PROVIDERS_FROM_SOURCES="true"
ENV INSTALL_PROVIDERS_FROM_SOURCES=${INSTALL_PROVIDERS_FROM_SOURCES}

WORKDIR /opt/airflow

RUN if [[ ${INSTALL_MYSQL_CLIENT} != "true" ]]; then \
        AIRFLOW_EXTRAS=${AIRFLOW_EXTRAS/mysql,}; \
    fi; \
    if [[ ${INSTALL_AIRFLOW_VIA_PIP} == "true" ]]; then \
        pip install --user "${AIRFLOW_INSTALL_SOURCES}[${AIRFLOW_EXTRAS}]${AIRFLOW_INSTALL_VERSION}" \
            --constraint "${AIRFLOW_CONSTRAINTS_LOCATION}"; \
    fi; \
    if [[ -n "${ADDITIONAL_PYTHON_DEPS}" ]]; then \
        pip install --user ${ADDITIONAL_PYTHON_DEPS} --constraint "${AIRFLOW_CONSTRAINTS_LOCATION}"; \
    fi; \
    if [[ ${AIRFLOW_LOCAL_PIP_WHEELS} == "true" ]]; then \
        if ls /docker-context-files/*.whl 1> /dev/null 2>&1; then \
            pip install --user  --no-deps /docker-context-files/*.whl; \
        fi ; \
    fi; \
    find /root/.local/ -name '*.pyc' -print0 | xargs -0 rm -r || true ; \
    find /root/.local/ -type d -name '__pycache__' -print0 | xargs -0 rm -r || true
RUN AIRFLOW_SITE_PACKAGE="/root/.local/lib/python${PYTHON_MAJOR_MINOR_VERSION}/site-packages/airflow"; \
    if [[ -f "${AIRFLOW_SITE_PACKAGE}/www_rbac/package.json" ]]; then \
        WWW_DIR="${AIRFLOW_SITE_PACKAGE}/www_rbac"; \
    elif [[ -f "${AIRFLOW_SITE_PACKAGE}/www/package.json" ]]; then \
        WWW_DIR="${AIRFLOW_SITE_PACKAGE}/www"; \
    fi; \
    if [[ ${WWW_DIR:=} != "" ]]; then \
        yarn --cwd "${WWW_DIR}" install --frozen-lockfile --no-cache; \
        yarn --cwd "${WWW_DIR}" run prod; \
        rm -rf "${WWW_DIR}/node_modules"; \
        rm -vf "${WWW_DIR}"/{package.json,yarn.lock,.eslintignore,.eslintrc,.stylelintignore,.stylelintrc,compile_assets.sh,webpack.config.js} ;\
    fi

# make sure that all directories and files in .local are also group accessible
RUN find /root/.local -executable -print0 | xargs --null chmod g+x && \
    find /root/.local -print0 | xargs --null chmod g+rw

LABEL org.apache.airflow.distro="centos7"
LABEL org.apache.airflow.distro.version="buster"
LABEL org.apache.airflow.module="airflow"
LABEL org.apache.airflow.component="airflow"
LABEL org.apache.airflow.image="airflow-build-image"

ARG BUILD_ID
ENV BUILD_ID=${BUILD_ID}
ARG COMMIT_SHA
ENV COMMIT_SHA=${COMMIT_SHA}

LABEL org.apache.airflow.buildImage.buildId=${BUILD_ID}
LABEL org.apache.airflow.buildImage.commitSha=${COMMIT_SHA}


##############################################################################################
# This is the actual Airflow image - much smaller than the build one. We copy
# installed Airflow and all it's dependencies from the build image to make it smaller.
##############################################################################################

FROM ${PYTHON_BASE_IMAGE} as main
ARG AIRFLOW_UID
ARG AIRFLOW_GID

LABEL org.apache.airflow.distro="centos7"
LABEL org.apache.airflow.distro.version="buster"
LABEL org.apache.airflow.module="airflow"
LABEL org.apache.airflow.component="airflow"
LABEL org.apache.airflow.image="airflow"
LABEL org.apache.airflow.uid="${AIRFLOW_UID}"
LABEL org.apache.airflow.gid="${AIRFLOW_GID}"

ARG PYTHON_BASE_IMAGE
ENV PYTHON_BASE_IMAGE=${PYTHON_BASE_IMAGE}


ARG AIRFLOW_VERSION
ENV AIRFLOW_VERSION=${AIRFLOW_VERSION}

ARG PIP_VERSION
ENV PIP_VERSION=${PIP_VERSION}

USER root


RUN yum update -y && yum install -y epel-release \
        && yum install -y curl tee


RUN curl -sL https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo \
        && yum remove -y nodejs npm \
        && curl -sL https://rpm.nodesource.com/setup_10.x | bash - \
        && yum install -y nodejs \
        && yum install -y yarn

RUN yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm \
        && yum install -y postgresql10-libs



RUN yum install -y wget
RUN wget -O /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.4/dumb-init_1.2.4_x86_64 \
        && chmod +x /usr/bin/dumb-init

RUN  yum localinstall -y  https://dev.mysql.com/get/mysql80-community-release-el7-1.noarch.rpm && yum install -y mysql-community-client



ARG RUNTIME_APT_DEPS="\
     ca-certificates.noarch \
     gnupg2.x86_64 \
     openssh-clients.x86_64 \
     libsqlite3x-devel.x86_64 \
     sudo \
     iputils.x86_64"

ENV RUNTIME_APT_DEPS=${RUNTIME_APT_DEPS}

ARG ADDITIONAL_RUNTIME_APT_DEPS=""
ENV ADDITIONAL_RUNTIME_APT_DEPS=${ADDITIONAL_RUNTIME_APT_DEPS}

ARG RUNTIME_APT_COMMAND="echo"
ENV RUNTIME_APT_COMMAND=${RUNTIME_APT_COMMAND}

ARG ADDITIONAL_RUNTIME_APT_COMMAND=""
ENV ADDITIONAL_RUNTIME_APT_COMMAND=${ADDITIONAL_RUNTIME_APT_COMMAND}

ARG ADDITIONAL_RUNTIME_ENV_VARS=""

RUN yum install -y ${RUNTIME_APT_DEPS}


ARG INSTALL_MYSQL_CLIENT="true"
ENV INSTALL_MYSQL_CLIENT=${INSTALL_MYSQL_CLIENT}


ENV AIRFLOW_UID=${AIRFLOW_UID}
ENV AIRFLOW_GID=${AIRFLOW_GID}

ENV AIRFLOW__CORE__LOAD_EXAMPLES="false"

ARG AIRFLOW_USER_HOME_DIR=/home/airflow
ENV AIRFLOW_USER_HOME_DIR=${AIRFLOW_USER_HOME_DIR}

RUN groupadd --gid "${AIRFLOW_GID}" "airflow" && \
    useradd  "airflow" --uid "${AIRFLOW_UID}" \
        --gid "${AIRFLOW_GID}" \
        --home "${AIRFLOW_USER_HOME_DIR}" \
        -p airflow
RUN usermod -aG wheel airflow

ARG AIRFLOW_HOME
ENV AIRFLOW_HOME=${AIRFLOW_HOME}

# Make Airflow files belong to the root group and are accessible. This is to accomodate the guidelines from
# OpenShift https://docs.openshift.com/enterprise/3.0/creating_images/guidelines.html
RUN mkdir -pv "${AIRFLOW_HOME}"; \
    mkdir -pv "${AIRFLOW_HOME}/dags"; \
    mkdir -pv "${AIRFLOW_HOME}/logs"; \
    chown -R "airflow:root" "${AIRFLOW_USER_HOME_DIR}" "${AIRFLOW_HOME}"; \
    find "${AIRFLOW_HOME}" -executable -print0 | xargs --null chmod g+x && \
        find "${AIRFLOW_HOME}" -print0 | xargs --null chmod g+rw

COPY --chown=airflow:root --from=airflow-build-image /root/.local "${AIRFLOW_USER_HOME_DIR}/.local"

COPY --chown=airflow:root scripts/in_container/prod/entrypoint_prod.sh /entrypoint
COPY --chown=airflow:root scripts/in_container/prod/clean-logs.sh /clean-logs
RUN chmod a+x /entrypoint /clean-logs

RUN pip install --upgrade "pip==${PIP_VERSION}"

# Make /etc/passwd root-group-writeable so that user can be dynamically added by OpenShift
# See https://github.com/apache/airflow/issues/9248
RUN chmod g=u /etc/passwd

ENV PATH="${AIRFLOW_USER_HOME_DIR}/.local/bin:${PATH}"
ENV GUNICORN_CMD_ARGS="--worker-tmp-dir /dev/shm"

RUN curl -LO https://github.com/cdr/code-server/releases/download/3.2.0/code-server-3.2.0-linux-x86_64.tar.gz \
	&& tar -xzvf code-server-3.2.0-linux-x86_64.tar.gz \
	&& cp -r code-server-3.2.0-linux-x86_64 /usr/lib/code-server \
	&& ln -s /usr/lib/code-server/code-server /usr/bin/code-server \
	&& mkdir /var/lib/code-server





WORKDIR ${AIRFLOW_HOME}

EXPOSE 8080


USER ${AIRFLOW_UID}

ENV PATH=${AIRFLOW_HOME}/.local/bin:${PATH}
ENV LD_LIBRARY_PATH=${AIRFLOW_HOME}/.local/lib:${LD_LIBRARY_PATH}

ARG BUILD_ID
ENV BUILD_ID=${BUILD_ID}
ARG COMMIT_SHA
ENV COMMIT_SHA=${COMMIT_SHA}

LABEL org.apache.airflow.distro="centos7"
LABEL org.apache.airflow.distro.version="buster"
LABEL org.apache.airflow.module="airflow"
LABEL org.apache.airflow.component="airflow"
LABEL org.apache.airflow.image="airflow"
LABEL org.apache.airflow.uid="${AIRFLOW_UID}"
LABEL org.apache.airflow.gid="${AIRFLOW_GID}"
LABEL org.apache.airflow.mainImage.buildId=${BUILD_ID}
LABEL org.apache.airflow.mainImage.commitSha=${COMMIT_SHA}

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/entrypoint"]
CMD ["--help"]

     
