from ubuntu:14.10

run apt-get update
run apt-get install -y python-pip python-dev git curl
run easy_install -U pip
run curl -sL https://deb.nodesource.com/setup | sudo bash -
run apt-get install -y nodejs build-essential

add . buildbot
workdir buildbot
run pip install -e pkg
run pip install -e master
run pip install -e slave
run make frontend

run buildbot create-master master
run cp -a master/master.cfg.sample master/master.cfg
run buildslave create-slave slave localhost:9989 example-slave pass

# Setup running docker container buildbot process
# Make host port 8020 match container port 8020
expose 8020
cmd buildbot start --nodaemon master

# build: docker build -t buildbot .
# run: docker run -d -p 80:8020 buildbot