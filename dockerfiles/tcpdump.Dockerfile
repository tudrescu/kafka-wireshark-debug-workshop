FROM ubuntu:18.04

RUN apt-get update && apt-get install -y tcpdump 

CMD tcpdump -i eth0 