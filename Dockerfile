FROM jenkins/jenkins:lts
WORKDIR /tmp

# Environment variables used throughout this Dockerfile
#
# $JENKINS_HOME     will be the final destination that Jenkins will use as its
#                   data directory. This cannot be populated before Marathon
#                   has a chance to create the host-container volume mapping.
#
ENV HOST localhost
ENV JENKINS_AGENT_ROLE *
ENV JENKINS_AGENT_USER root
ENV JENKINS_CONTEXT /
ENV JENKINS_FOLDER /usr/share/jenkins
ENV JENKINS_FRAMEWORK_NAME jenkins
ENV JENKINS_MESOS_MASTER localhost
ENV SSH_KNOWN_HOSTS github.com
# NGINX port default
ENV PORT0 80
# Jenkins port default
ENV PORT1 8080

# Build Args
ARG LIBMESOS_DOWNLOAD_URL=https://downloads.mesosphere.com/libmesos-bundle/libmesos-bundle-1.8.7-1.0.2-2.tar.gz
ARG LIBMESOS_DOWNLOAD_SHA256=9757b2e86c975488f68ce325fdf08578669e3c0f1fcccf24545d3bd1bd423a25
ARG BLUEOCEAN_VERSION=1.4.2
ARG JENKINS_STAGING=/usr/share/jenkins/ref/

# Default policy according to https://wiki.jenkins.io/display/JENKINS/Configuring+Content+Security+Policy
ENV JENKINS_CSP_OPTS="sandbox; default-src 'none'; img-src 'self'; style-src 'self';"

USER root

# install dependencies
RUN apt-get update && apt-get install -y nginx python zip jq
# libmesos bundle
RUN curl -fsSL "$LIBMESOS_DOWNLOAD_URL" -o libmesos-bundle.tar.gz  \
  && echo "$LIBMESOS_DOWNLOAD_SHA256 libmesos-bundle.tar.gz" | sha256sum -c - \
  && tar -C / -xzf libmesos-bundle.tar.gz  \
  && rm libmesos-bundle.tar.gz
# update to newer git version
RUN echo "deb http://ftp.debian.org/debian testing main" >> /etc/apt/sources.list \
  && apt-get update && apt-get -t testing install -y git

# Override the default property for DNS lookup caching
RUN echo 'networkaddress.cache.ttl=60' >> ${JAVA_HOME}/jre/lib/security/java.security

# bootstrap scripts and needed dir setup
COPY scripts/bootstrap.py /usr/local/jenkins/bin/bootstrap.py
COPY scripts/export-libssl.sh /usr/local/jenkins/bin/export-libssl.sh
COPY scripts/dcos-account.sh /usr/local/jenkins/bin/dcos-account.sh
COPY scripts/dcos-pem.sh /usr/local/jenkins/bin/dcos-pem.sh
RUN mkdir -p "$JENKINS_HOME" "${JENKINS_FOLDER}/war"

 # nginx setup
RUN mkdir -p /var/log/nginx/jenkins
COPY conf/nginx/nginx.conf /etc/nginx/nginx.conf

# jenkins setup
COPY conf/jenkins/config.xml "${JENKINS_STAGING}/config.xml"
COPY conf/jenkins/jenkins.model.JenkinsLocationConfiguration.xml "${JENKINS_STAGING}/jenkins.model.JenkinsLocationConfiguration.xml"
COPY conf/jenkins/nodeMonitors.xml "${JENKINS_STAGING}/nodeMonitors.xml"

# add plugins
RUN /usr/local/bin/install-plugins.sh       \
  ansicolor:0.5.2                \
  artifactory:2.15.0             \
  blueocean-bitbucket-pipeline:${BLUEOCEAN_VERSION} \
  blueocean-commons:${BLUEOCEAN_VERSION}       \
  blueocean-config:${BLUEOCEAN_VERSION}        \
  blueocean-dashboard:${BLUEOCEAN_VERSION}     \
  blueocean-events:${BLUEOCEAN_VERSION}        \
  blueocean-git-pipeline:${BLUEOCEAN_VERSION}  \
  blueocean-github-pipeline:${BLUEOCEAN_VERSION} \
  blueocean-i18n:${BLUEOCEAN_VERSION}          \
  blueocean-jwt:${BLUEOCEAN_VERSION}           \
  blueocean-jira:${BLUEOCEAN_VERSION}          \
  blueocean-personalization:${BLUEOCEAN_VERSION} \
  blueocean-pipeline-api-impl:${BLUEOCEAN_VERSION} \
  blueocean-pipeline-editor:${BLUEOCEAN_VERSION} \
  blueocean-pipeline-scm-api:${BLUEOCEAN_VERSION} \
  blueocean-rest-impl:${BLUEOCEAN_VERSION} \
  blueocean-rest:${BLUEOCEAN_VERSION} \
  blueocean-web:${BLUEOCEAN_VERSION} \
  blueocean:${BLUEOCEAN_VERSION} \
  bouncycastle-api:2.16.2 \
  build-name-setter:1.6.9        \
  build-timeout:1.19             \
  cloudbees-folder:6.4         \
  conditional-buildstep:1.3.6    \
  copyartifact:1.39              \
  embeddable-build-status:1.9    \
  gerrit-trigger:2.27.5          \
  git:3.8.0                      \
  git-client:2.7.1               \
  git-server:1.7                 \
  github:1.29.0                  \
  github-api:1.90                \
  github-branch-source:2.3.3     \
  github-organization-folder:1.6 \
  gitlab:1.5.3                   \
  greenballs:1.15                \
  jackson2-api:2.8.11.1          \
  jobConfigHistory:2.18          \
  ldap:1.20                      \
  mailer:1.20                    \
  mask-passwords:2.11.0          \
  marathon:1.6.0                 \
  matrix-auth:2.2                \
  matrix-project:1.12            \
  mesos:0.15.1                   \
  metrics:3.1.2.11               \
  monitoring:1.71.0              \
  node-iterator-api:1.5.0        \
  p4:1.8.7                       \
  pam-auth:1.3                   \
  parameterized-trigger:2.35.2   \
  pipeline-build-step:2.7        \
  pipeline-github-lib:1.0        \
  pipeline-input-step:2.8        \
  pipeline-milestone-step:1.3.1  \
  pipeline-model-api:1.2.7       \
  pipeline-model-definition:1.2.7 \
  pipeline-model-extensions:1.2.7 \
  pipeline-rest-api:2.9          \
  pipeline-stage-step:2.3        \
  pipeline-stage-view:2.9        \
  plain-credentials:1.4          \
  rebuild:1.27                   \
  role-strategy:2.7.0           \
  run-condition:1.0              \
  saferestart:0.3                \
  scm-api:2.2.6                  \
  splunk-devops:1.6.4            \
  splunk-devops-extend:1.6.4     \
  ssh-agent:1.15                 \
  ssh-slaves:1.26                \
  timestamper:1.8.9              \
  variant:1.1                    \
  windows-slaves:1.3.1           \
  workflow-aggregator:2.5        \
  workflow-api:2.26              \
  workflow-basic-steps:2.6       \
  workflow-cps:2.45              \
  workflow-cps-global-lib:2.9    \
  workflow-durable-task-step:2.19 \
  workflow-job:2.17              \
  workflow-multibranch:2.17      \
  workflow-scm-step:2.6          \
  workflow-step-api:2.14         \
  workflow-support:2.18

# disable first-run wizard
RUN echo 2.0 > /usr/share/jenkins/ref/jenkins.install.UpgradeWizard.state

CMD export LD_LIBRARY_PATH=/libmesos-bundle/lib:/libmesos-bundle/lib/mesos:$LD_LIBRARY_PATH \
  && export MESOS_NATIVE_JAVA_LIBRARY=$(ls /libmesos-bundle/lib/libmesos-*.so)   \
  && . /usr/local/jenkins/bin/export-libssl.sh       \
  && /usr/local/jenkins/bin/bootstrap.py && nginx    \
  && . /usr/local/jenkins/bin/dcos-account.sh        \
  && java ${JVM_OPTS}                                \
     -Dhudson.model.DirectoryBrowserSupport.CSP="${JENKINS_CSP_OPTS}" \
     -Dhudson.udp=-1                                 \
     -Djava.awt.headless=true                        \
     -Dhudson.DNSMultiCast.disabled=true             \
     -Djenkins.install.runSetupWizard=false          \
     -jar ${JENKINS_FOLDER}/jenkins.war              \
     ${JENKINS_OPTS}                                 \
     --httpPort=${PORT1}                             \
     --webroot=${JENKINS_FOLDER}/war                 \
     --ajp13Port=-1                                  \
     --httpListenAddress=127.0.0.1                   \
     --ajp13ListenAddress=127.0.0.1                  \
     --prefix=${JENKINS_CONTEXT}
