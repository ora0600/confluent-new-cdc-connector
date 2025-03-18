FROM confluentinc/cp-kafka-connect:latest

# Set working directory
WORKDIR /usr/local

# Install required packages
#RUN apt-get update && apt-get install -y unzip libaio1 wget && \
#    rm -rf /var/lib/apt/lists/*

# Install required packages using microdnf
USER root
RUN microdnf install -y unzip libaio wget && \
    microdnf clean all

# Download and install the Oracle Instant Client
RUN wget --no-check-certificate https://download.oracle.com/otn_software/linux/instantclient/1926000/instantclient-basic-linux.arm64-19.26.0.0.0dbru.zip && \
    unzip instantclient-basic-linux.arm64-19.26.0.0.0dbru.zip -d /usr/local/ && \
    rm -f instantclient-basic-linux.arm64-19.26.0.0.0dbru.zip

# Set the library path
ENV LD_LIBRARY_PATH=/usr/local/instantclient_19_26/:$LD_LIBRARY_PATH

# Verify installation
RUN echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH" && ls -l /usr/local/instantclient_19_26

