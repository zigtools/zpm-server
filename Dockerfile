FROM ubuntu:latest

EXPOSE 8080/tcp
WORKDIR /app

RUN apt-get update && apt-get -y install cron git curl xz-utils

RUN git clone https://github.com/ziglibs/repository /repository

# pull every 15 minutes
RUN echo '*/15 * * * * cd /repository && git pull >> /var/log/cron.log 2>&1'  > /etc/cron.d/update-repository

# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/update-repository

# Apply cron job
RUN crontab /etc/cron.d/update-repository

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Install the latest zig master
RUN mkdir /zig 
RUN curl -o /zig/master.tar.xz "https://ziglang.org/builds/zig-linux-$(uname --machine)-0.6.0+006b780d4.tar.xz"
RUN cd /zig && tar -xf /zig/master.tar.xz
RUN mv /zig/*/* /zig

# Install the application
COPY . /app
RUN /zig/zig build -Dpackages-dir=/repository/packages -Drelease-safe 

# Run the command on container startup
# CMD cron && tail -f /var/log/cron.log
CMD cron && /app/zig-cache/bin/zpm-server
