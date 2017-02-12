#!/bin/bash
#
#       Description:    Script to install WeltN24 AWS challenge in high
#			availability in AWS evnironment.
#       Date:           2017/02/12
#       Versiion:       1.0
#       Author:         Jorge Gonzalez
#
# ------------------------------------------------------------------------------


USER=`whoami`

if [[ "${USER}" != "root" ]]; then
	echo "ERROR: script must be run by root"
	exit 1
else
	# update package list and packages
	apt-get update && apt-get upgrade -y

	# docker installation, following information from docker
	apt-get install curl linux-image-extra-$(uname -r) linux-image-extra-virtual -y
	apt-get install apt-transport-https software-properties-common ca-certificates -y
	curl -fsSL https://yum.dockerproject.org/gpg | sudo apt-key add -
	apt-get install software-properties-common -y
	add-apt-repository "deb https://apt.dockerproject.org/repo/ ubuntu-$(lsb_release -cs) main"
	apt-get update && apt-get -y install docker-engine

	# Create the Docker file container for weltN24 AWS exercise
	mkdir -p docker/weltn24
	cd docker/weltn24
	echo -e "FROM golang:1.6\n" > Dockerfile
	echo -e "# Install WeltN24 exercise app" >> Dockerfile
	echo -e "RUN go get github.com/WeltN24/exercise-aws-01\n" >> Dockerfile
	echo -e "# Expose the application on port 9090" >> Dockerfile
	echo -e "EXPOSE 9090\n" >> Dockerfile
	echo -e "# Set the entry point of the container to the command that runs the application" >> Dockerfile
	echo -e "CMD [\"exercise-aws-01\"]" >> Dockerfile

	# Create the Docker image
	docker build -t weltn24 .

	# Start three instances of the container in ports 9091, 9092, 9093, redirecting the logs to the syslog
	docker run -d --restart=always --log-driver=syslog --log-opt tag=weltn24-instance_001 --name weltn24-instance_001 -p 9091:9090 weltn24
	docker run -d --restart=always --log-driver=syslog --log-opt tag=weltn24-instance_002 --name weltn24-instance_002 -p 9092:9090 weltn24
	docker run -d --restart=always --log-driver=syslog --log-opt tag=weltn24-instance_003 --name weltn24-instance_003 -p 9093:9090 weltn24

	# Go back to $HOME
	cd --

	# Configure syslog to log 'weltn24-instance' entries to another file
	echo -e "if \$programname == 'weltn24-instance_001' OR \$programname == 'weltn24-instance_002' OR \$programname == 'weltn24-instance_003' then {" > /etc/rsyslog.d/10-weltn24.conf
	echo -e "\t/usr/share/nginx/weltn24/index.html" >> /etc/rsyslog.d/10-weltn24.conf
	echo -e "\t~" >> /etc/rsyslog.d/10-weltn24.conf
	echo -e "}" >> /etc/rsyslog.d/10-weltn24.conf

	# Create infrastructure for the new logging file, which will be under ngnix shared docs directory,
	# and will be the index of the site
	mkdir -p /usr/share/nginx/weltn24/
	touch /usr/share/nginx/weltn24/index.html
	chmod 606 /usr/share/nginx/weltn24/index.html

	# Restart rsyslog to start logging
	service rsyslog restart

	# Install nginx as load balancer and frontend for the aggregated logs
	apt-get install nginx -y

	# New nginx conf file with http upstream for servers 9091, 9092, 9093
	# Appending the following to /etc/nginx/nginx.conf
	# /etc/nginx/nginx.conf
	#	upstream localhost {
	#		server localhost:9091;
	#		server localhost:9092;
	#		server localhost:9093;
	#	}
	sed 's/include \/etc\/nginx\/sites\-enabled\/\*;/include \/etc\/nginx\/sites\-enabled\/\*;\n\n\tupstream localhost {\n\t\tserver localhost:9091;\n\t\tserver localhost:9092;\n\t\tserver localhost:9093;\n\t}/' /etc/nginx/nginx.conf -i

	# Delete default nginx files
	rm /etc/nginx/sites-enabled/default

	# Create new config file for load balacner
	echo -e "server {" > /etc/nginx/sites-available/weltn24-lb.conf
	echo -e "\tlisten 80;\n" >> /etc/nginx/sites-available/weltn24-lb.conf
	echo -e "\tlocation / {" >> /etc/nginx/sites-available/weltn24-lb.conf
	echo -e "\t\tproxy_pass http://localhost;" >> /etc/nginx/sites-available/weltn24-lb.conf
	echo -e "\t}" >> /etc/nginx/sites-available/weltn24-lb.conf
	echo -e "}" >> /etc/nginx/sites-available/weltn24-lb.conf

	# Link new load balancer site in nginx
	ln -s /etc/nginx/sites-available/weltn24-lb.conf /etc/nginx/sites-enabled/

	# Create new config file for web log aggregator frontend
	echo -e "server {\n" > /etc/nginx/sites-available/weltn24-log.conf
	echo -e "\tlisten 50050;\n" >> /etc/nginx/sites-available/weltn24-log.conf
	echo -e "\troot /usr/share/nginx/weltn24;" >> /etc/nginx/sites-available/weltn24-log.conf
	echo -e "\tindex index.html index.htm;" >> /etc/nginx/sites-available/weltn24-log.conf
	echo -e "}" >> /etc/nginx/sites-available/weltn24-log.conf

	# Link new web log aggregator frontend site in nginx
	ln -s /etc/nginx/sites-available/weltn24-log.conf /etc/nginx/sites-enabled/

	# Restart nginx
	service nginx restart
fi
